function fail(message) {
    print "Error: " message > "/dev/stderr"
    exit_status = 1
    exit 1
}

function trim(value) {
    sub(/^[[:space:]]+/, "", value)
    sub(/[[:space:]]+$/, "", value)
    return value
}

function trim_left_horizontal(value) {
    sub(/^[ \t]+/, "", value)
    return value
}

function trim_right_horizontal(value) {
    sub(/[ \t]+$/, "", value)
    return value
}

function json_escape(value,    result, i, char) {
    result = ""
    for (i = 1; i <= length(value); i++) {
        char = substr(value, i, 1)
        if (char == "\\") {
            result = result "\\\\"
        } else if (char == "\"") {
            result = result "\\\""
        } else if (char == "\n") {
            result = result "\\n"
        } else if (char == "\r") {
            result = result "\\r"
        } else if (char == "\t") {
            result = result "\\t"
        } else if (char == sprintf("%c", 8)) {
            result = result "\\b"
        } else if (char == sprintf("%c", 12)) {
            result = result "\\f"
        } else {
            result = result char
        }
    }
    return result
}

function json_quote(value) {
    return "\"" json_escape(value) "\""
}

function unicode_utf8(codepoint,    first, second, third, fourth) {
    if (codepoint <= 127) {
        return sprintf("%c", codepoint)
    }
    if (codepoint <= 2047) {
        first = 192 + int(codepoint / 64)
        second = 128 + (codepoint % 64)
        return sprintf("%c%c", first, second)
    }
    if (codepoint <= 65535) {
        first = 224 + int(codepoint / 4096)
        second = 128 + int((codepoint % 4096) / 64)
        third = 128 + (codepoint % 64)
        return sprintf("%c%c%c", first, second, third)
    }
    first = 240 + int(codepoint / 262144)
    second = 128 + int((codepoint % 262144) / 4096)
    third = 128 + int((codepoint % 4096) / 64)
    fourth = 128 + (codepoint % 64)
    return sprintf("%c%c%c%c", first, second, third, fourth)
}

function decode_double_quoted(value,    result, i, char, next_char, digits, count, codepoint) {
    result = ""
    for (i = 1; i <= length(value); i++) {
        char = substr(value, i, 1)
        if (char != "\\" || i == length(value)) {
            result = result char
            continue
        }

        next_char = substr(value, ++i, 1)
        if (next_char == "n") {
            result = result "\n"
        } else if (next_char == "r") {
            result = result "\r"
        } else if (next_char == "t") {
            result = result "\t"
        } else if (next_char == "b") {
            result = result sprintf("%c", 8)
        } else if (next_char == "0") {
            result = result sprintf("%c", 0)
        } else if (next_char == "a") {
            result = result sprintf("%c", 7)
        } else if (next_char == "v") {
            result = result sprintf("%c", 11)
        } else if (next_char == "f") {
            result = result sprintf("%c", 12)
        } else if (next_char == "e") {
            result = result sprintf("%c", 27)
        } else if (next_char == " " || next_char == "\t") {
            result = result next_char
        } else if (next_char == "_" || next_char == "N" || next_char == "L" || next_char == "P") {
            if (next_char == "_") {
                codepoint = 160
            } else if (next_char == "N") {
                codepoint = 133
            } else if (next_char == "L") {
                codepoint = 8232
            } else {
                codepoint = 8233
            }
            result = result unicode_utf8(codepoint)
        } else if (next_char == "/" || next_char == "\\" || next_char == "\"") {
            result = result next_char
        } else if (next_char == "x") {
            digits = substr(value, i + 1, 2)
            if (length(digits) != 2 || digits !~ /^[0-9a-fA-F]+$/) {
                fail("invalid hexadecimal escape on line " NR)
            }
            result = result unicode_utf8(base_integer(digits, 16) + 0)
            i += 2
        } else if (next_char == "u" || next_char == "U") {
            count = next_char == "u" ? 4 : 8
            digits = substr(value, i + 1, count)
            if (length(digits) != count || digits !~ /^[0-9a-fA-F]+$/) {
                fail("invalid Unicode escape on line " NR)
            }
            codepoint = base_integer(digits, 16) + 0
            if (codepoint > 1114111 || (codepoint >= 55296 && codepoint <= 57343)) {
                fail("invalid Unicode code point on line " NR)
            }
            result = result unicode_utf8(codepoint)
            i += count
        } else {
            fail("invalid escape sequence on line " NR)
        }
    }
    return result
}

function fold_quoted_scalar(value, double_quoted,    count, i, line, result, content, breaks, escaped_break) {
    count = split(value, quoted_line, /\n/)
    result = ""
    breaks = 0
    escaped_break = 0

    for (i = 1; i <= count; i++) {
        line = quoted_line[i]
        if (i == 1) {
            content = trim_right_horizontal(line)
        } else if (i == count) {
            content = trim_left_horizontal(line)
        } else {
            content = trim_right_horizontal(trim_left_horizontal(line))
        }

        if (escaped_break) {
            result = result content
            escaped_break = 0
            breaks = 0
        } else if (content != "") {
            if (breaks == 1) {
                result = result " "
            } else {
                while (breaks > 1) {
                    result = result "\n"
                    breaks--
                }
            }
            result = result content
            breaks = 0
        }

        if (double_quoted && substr(result, length(result), 1) == "\\") {
            result = substr(result, 1, length(result) - 1)
            escaped_break = 1
        } else if (i < count) {
            breaks++
        }
        delete quoted_line[i]
    }

    if (breaks == 1) {
        result = result " "
    } else {
        while (breaks > 1) {
            result = result "\n"
            breaks--
        }
    }
    return result
}

function scalar_value(value,    quote, inner) {
    value = trim(value)
    quote = sprintf("%c", 39)

    if (length(value) >= 2 && substr(value, 1, 1) == "\"" && substr(value, length(value), 1) == "\"") {
        inner = substr(value, 2, length(value) - 2)
        if (index(inner, "\n")) {
            inner = fold_quoted_scalar(inner, 1)
        }
        return decode_double_quoted(inner)
    }

    if (length(value) >= 2 && substr(value, 1, 1) == quote && substr(value, length(value), 1) == quote) {
        value = substr(value, 2, length(value) - 2)
        if (index(value, "\n")) {
            value = fold_quoted_scalar(value, 0)
        }
        gsub(quote quote, quote, value)
    }
    return value
}

function scalar_type(raw, tag, value,    lowered, normalized_tag) {
    normalized_tag = tag
    sub(/^tag:yaml.org,2002:/, "", normalized_tag)

    if (normalized_tag == "str") {
        return "string"
    }
    if (normalized_tag == "null" || normalized_tag == "bool" || normalized_tag == "int" || normalized_tag == "float" || normalized_tag == "timestamp") {
        return normalized_tag
    }
    if (tag != "") {
        return "tagged"
    }

    raw = trim(raw)
    if ((substr(raw, 1, 1) == "\"" && substr(raw, length(raw), 1) == "\"") ||
        (substr(raw, 1, 1) == sprintf("%c", 39) && substr(raw, length(raw), 1) == sprintf("%c", 39))) {
        return "string"
    }

    lowered = tolower(value)
    if (value == "~" || lowered == "null" || value == "") {
        return "null"
    }
    if (lowered == "true" || lowered == "false") {
        return "bool"
    }
    if (value ~ /^[-+]?(0|[1-9][0-9_]*)$/ || value ~ /^[-+]?0b[01_]+$/ || value ~ /^[-+]?0o[0-7_]+$/ || value ~ /^[-+]?0x[0-9a-fA-F_]+$/) {
        return "int"
    }
    if (value ~ /^[-+]?[0-9][0-9_]*\.[0-9_]*([eE][-+]?[0-9]+)?$/ ||
        value ~ /^[-+]?\.[0-9_]+([eE][-+]?[0-9]+)?$/ ||
        value ~ /^[-+]?[0-9][0-9_]*[eE][-+]?[0-9]+$/ || lowered ~ /^[-+]?\.(inf|nan)$/) {
        return "float"
    }
    if (value ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]([Tt]|[[:space:]]|$)/) {
        return "timestamp"
    }
    return "string"
}

function strip_inline_comment(value,    i, char, previous, quote, escaped, braces, brackets) {
    quote = ""
    escaped = 0
    braces = 0
    brackets = 0

    for (i = 1; i <= length(value); i++) {
        char = substr(value, i, 1)
        previous = (i > 1 ? substr(value, i - 1, 1) : "")

        if (escaped) {
            escaped = 0
            continue
        }
        if (quote == "\"" && char == "\\") {
            escaped = 1
            continue
        }
        if (quote != "") {
            if (char == quote) {
                quote = ""
            }
            continue
        }
        if (char == "\"" || char == sprintf("%c", 39)) {
            quote = char
        } else if (char == "{") {
            braces++
        } else if (char == "}" && braces > 0) {
            braces--
        } else if (char == "[") {
            brackets++
        } else if (char == "]" && brackets > 0) {
            brackets--
        } else if (char == "#" && braces == 0 && brackets == 0 && (i == 1 || previous ~ /[[:space:]]/)) {
            return trim(substr(value, 1, i - 1))
        }
    }
    return trim(value)
}

function strip_flow_line_comment(value,    i, char, previous, quote, escaped) {
    quote = ""
    escaped = 0
    for (i = 1; i <= length(value); i++) {
        char = substr(value, i, 1)
        previous = i > 1 ? substr(value, i - 1, 1) : ""
        if (escaped) {
            escaped = 0
            continue
        }
        if (quote == "\"" && char == "\\") {
            escaped = 1
            continue
        }
        if (quote != "") {
            if (char == quote) {
                quote = ""
            }
            continue
        }
        if (char == "\"" || char == sprintf("%c", 39)) {
            quote = char
        } else if (char == "#" && (i == 1 || previous ~ /[[:space:]]/)) {
            return trim(substr(value, 1, i - 1))
        }
    }
    return trim(value)
}

function find_top_level_colon(value, require_space,    i, char, next_char, previous, quote, escaped, braces, brackets) {
    quote = ""
    escaped = 0
    braces = 0
    brackets = 0

    for (i = 1; i <= length(value); i++) {
        char = substr(value, i, 1)
        previous = i > 1 ? substr(value, i - 1, 1) : ""
        if (escaped) {
            escaped = 0
            continue
        }
        if (quote == "\"" && char == "\\") {
            escaped = 1
            continue
        }
        if (quote != "") {
            if (char == quote) {
                quote = ""
            }
            continue
        }
        if ((char == "\"" || char == sprintf("%c", 39)) &&
            (i == 1 || previous ~ /[[:space:]\[{},]/)) {
            quote = char
        } else if (char == "{") {
            braces++
        } else if (char == "}" && braces > 0) {
            braces--
        } else if (char == "[") {
            brackets++
        } else if (char == "]" && brackets > 0) {
            brackets--
        } else if (char == ":" && braces == 0 && brackets == 0) {
            next_char = substr(value, i + 1, 1)
            if (!require_space || next_char == "" || next_char ~ /[[:space:]]/) {
                return i
            }
        }
    }
    return 0
}

function find_mapping_separator(value, require_space,    offset, remainder, space, separator) {
    offset = 1
    remainder = value
    while (substr(remainder, 1, 1) == "&" || substr(remainder, 1, 1) == "!") {
        space = match(remainder, /[[:space:]]/)
        if (!space) {
            return 0
        }
        offset += space
        remainder = substr(remainder, space + 1)
        while (substr(remainder, 1, 1) ~ /[[:space:]]/) {
            remainder = substr(remainder, 2)
            offset++
        }
    }
    separator = find_top_level_colon(remainder, require_space)
    return separator ? offset + separator - 1 : 0
}

function split_flow(value, output,    count, start, i, char, quote, escaped, braces, brackets) {
    count = 0
    start = 1
    quote = ""
    escaped = 0
    braces = 0
    brackets = 0

    if (trim(value) == "") {
        return 0
    }

    for (i = 1; i <= length(value); i++) {
        char = substr(value, i, 1)
        if (escaped) {
            escaped = 0
            continue
        }
        if (quote == "\"" && char == "\\") {
            escaped = 1
            continue
        }
        if (quote != "") {
            if (char == quote) {
                quote = ""
            }
            continue
        }
        if (char == "\"" || char == sprintf("%c", 39)) {
            quote = char
        } else if (char == "{") {
            braces++
        } else if (char == "}") {
            braces--
        } else if (char == "[") {
            brackets++
        } else if (char == "]") {
            brackets--
        } else if (char == "," && braces == 0 && brackets == 0) {
            output[++count] = trim(substr(value, start, i - start))
            start = i + 1
        }
    }
    output[++count] = trim(substr(value, start))
    return count
}

function expand_tag(token,    inner, rest, position, handle, suffix, key) {
    if (token == "") {
        return ""
    }
    if (substr(token, 1, 2) == "!<" && substr(token, length(token), 1) == ">") {
        return substr(token, 3, length(token) - 3)
    }
    if (index(token, "[") || index(token, "]") || index(token, "{") ||
        index(token, "}") || index(token, ",")) {
        fail("invalid tag " token " on line " NR)
    }
    if (substr(token, 1, 2) == "!!") {
        key = document_index SUBSEP "!!"
        if (key in tag_prefix) {
            return tag_prefix[key] substr(token, 3)
        }
        return "tag:yaml.org,2002:" substr(token, 3)
    }
    if (substr(token, 1, 1) != "!") {
        fail("invalid tag " token " on line " NR)
    }

    rest = substr(token, 2)
    position = index(rest, "!")
    if (position) {
        handle = "!" substr(rest, 1, position)
        suffix = substr(rest, position + 1)
        key = document_index SUBSEP handle
        if (!(key in tag_prefix)) {
            fail("undefined tag handle " handle " on line " NR)
        }
        return tag_prefix[key] suffix
    }
    key = document_index SUBSEP "!"
    if (key in tag_prefix) {
        return tag_prefix[key] substr(token, 2)
    }
    return token
}

function valid_anchor_name(name,    i, char) {
    if (name == "" || name ~ /[[:space:]]/) {
        return 0
    }
    for (i = 1; i <= length(name); i++) {
        char = substr(name, i, 1)
        if (index("[]{},", char)) {
            return 0
        }
    }
    return 1
}

function parse_properties(value, source_line,    separator, token) {
    parsed_anchor = ""
    parsed_tag = ""
    value = trim(value)

    while (substr(value, 1, 1) == "&" || substr(value, 1, 1) == "!") {
        separator = match(value, /[[:space:]]/)
        if (separator) {
            token = substr(value, 1, separator - 1)
            value = trim(substr(value, separator + 1))
        } else {
            token = value
            value = ""
        }

        if (substr(token, 1, 1) == "&") {
            if (parsed_anchor != "") {
                fail("multiple anchors on one node on line " source_line)
            }
            parsed_anchor = substr(token, 2)
            if (!valid_anchor_name(parsed_anchor)) {
                fail("invalid anchor name on line " source_line)
            }
        } else {
            if (parsed_tag != "") {
                fail("multiple tags on one node on line " source_line)
            }
            parsed_tag = expand_tag(token)
        }
    }
    return value
}

function new_node(kind, source_line, value, value_type, tag,    node) {
    node = ++node_count
    node_kind[node] = kind
    node_line[node] = source_line
    node_value[node] = value
    node_type[node] = value_type
    node_tag[node] = tag
    node_document[node] = document_index
    return node
}

function bind_anchor(name, node, source_line,    key, anchor_index) {
    if (name == "") {
        return
    }
    key = document_index SUBSEP name
    anchor_target[key] = node
    node_anchor[node] = name
    anchor_index = ++document_anchor_count[document_index]
    document_anchor_name[document_index, anchor_index] = name
    document_anchor_node[document_index, anchor_index] = node
}

function ensure_container(node, kind, source_line) {
    if (node_kind[node] == "pending") {
        node_kind[node] = kind
        node_type[node] = ""
        return node
    }
    if (node_kind[node] != kind) {
        fail("cannot add " kind " content to " node_kind[node] " node on line " source_line)
    }
    return node
}

function ensure_root(kind, source_line,    root) {
    if (!(document_index in document_root)) {
        root = new_node(kind, source_line, "", "", "")
        document_root[document_index] = root
        document_has_content[document_index] = 1
        return root
    }
    root = (document_index in document_root) ? document_root[document_index] : 0
    return ensure_container(root, kind, source_line)
}

function create_empty_document(source_line,    root) {
    if (document_index in document_root) {
        return document_root[document_index]
    }
    root = new_node("scalar", source_line, "", "null", "")
    document_root[document_index] = root
    document_has_content[document_index] = 1
    return root
}

function add_mapping(parent, key, child, source_line, is_merge,    seen_key, entry) {
    ensure_container(parent, "mapping", source_line)
    seen_key = parent SUBSEP key
    if (seen_key in mapping_seen) {
        fail("duplicate mapping key " key " on line " source_line)
    }
    mapping_seen[seen_key] = 1
    entry = ++mapping_count[parent]
    mapping_key[parent, entry] = key
    mapping_child[parent, entry] = child
    mapping_merge[parent, entry] = is_merge
    node_parent[child] = parent
    node_parent_edge[child] = "key " key
}

function add_sequence(parent, child, source_line,    entry) {
    ensure_container(parent, "sequence", source_line)
    entry = ++sequence_count[parent]
    sequence_child[parent, entry] = child
    node_parent[child] = parent
    node_parent_edge[child] = "index " (entry - 1)
}

function alias_node(name, source_line,    key, node) {
    key = document_index SUBSEP name
    if (!(key in anchor_target)) {
        fail("undefined or forward alias *" name " on line " source_line)
    }
    node = new_node("alias", source_line, name, "", "")
    alias_target[node] = anchor_target[key]
    return node
}

function parse_scalar_key(value, source_line,    remainder, tag, anchor, node, resolved) {
    remainder = parse_properties(strip_inline_comment(trim(value)), source_line)
    tag = parsed_tag
    anchor = parsed_anchor
    if (substr(remainder, 1, 1) == "[" || substr(remainder, 1, 1) == "{") {
        fail("collection-valued mapping keys are not supported on line " source_line)
    }
    node = parse_core(remainder, source_line, tag, anchor)
    resolved = resolve_alias(node)
    if (node_kind[resolved] != "scalar") {
        fail("collection-valued mapping keys are not supported on line " source_line)
    }
    parsed_key_is_merge = remainder == "<<" && tag == ""
    return node_value[resolved]
}

function parse_core(value, source_line, tag, anchor,    node, inner, count, i, separator, raw_key, key, child, alias_name, flow_serial, piece, is_merge) {
    if (substr(value, 1, 1) == "*" && valid_anchor_name(substr(value, 2))) {
        if (tag != "" || anchor != "") {
            fail("aliases cannot carry a tag or anchor on line " source_line)
        }
        alias_name = substr(value, 2)
        return alias_node(alias_name, source_line)
    }

    if ((substr(value, 1, 1) == "[" || substr(value, 1, 1) == "{") && flow_balance(value) != 0) {
        fail("unbalanced flow collection on line " source_line)
    }

    if (substr(value, 1, 1) == "[" && substr(value, length(value), 1) == "]") {
        node = new_node("sequence", source_line, "", "", tag)
        bind_anchor(anchor, node, source_line)
        inner = substr(value, 2, length(value) - 2)
        count = split_flow(inner, flow_piece)
        for (i = 1; i <= count; i++) {
            flow_piece_saved[flow_piece_serial + 1, i] = flow_piece[i]
            delete flow_piece[i]
        }
        flow_serial = ++flow_piece_serial
        for (i = 1; i <= count; i++) {
            piece = flow_piece_saved[flow_serial, i]
            if (i == count && piece == "") {
                delete flow_piece_saved[flow_serial, i]
                continue
            }
            if (piece == "") {
                fail("empty entry between flow commas on line " source_line)
            }
            separator = find_mapping_separator(piece, 1)
            if (!separator && (substr(piece, 1, 1) == "\"" || substr(piece, 1, 1) == sprintf("%c", 39))) {
                separator = find_mapping_separator(piece, 0)
            }
            if (separator) {
                raw_key = trim(substr(piece, 1, separator - 1))
                if (raw_key ~ /^\?[[:space:]]/) {
                    raw_key = trim(substr(raw_key, 2))
                }
                child = new_node("mapping", source_line, "", "", "")
                key = parse_scalar_key(raw_key, source_line)
                is_merge = parsed_key_is_merge
                add_mapping(child, key, parse_value(substr(piece, separator + 1), source_line, -1, 0), source_line, is_merge)
            } else {
                child = parse_value(piece, source_line, -1, 0)
            }
            add_sequence(node, child, source_line)
            delete flow_piece_saved[flow_serial, i]
        }
        return node
    }

    if (substr(value, 1, 1) == "{" && substr(value, length(value), 1) == "}") {
        node = new_node("mapping", source_line, "", "", tag)
        bind_anchor(anchor, node, source_line)
        inner = substr(value, 2, length(value) - 2)
        count = split_flow(inner, flow_piece)
        for (i = 1; i <= count; i++) {
            flow_piece_saved[flow_piece_serial + 1, i] = flow_piece[i]
            delete flow_piece[i]
        }
        flow_serial = ++flow_piece_serial
        for (i = 1; i <= count; i++) {
            piece = flow_piece_saved[flow_serial, i]
            if (i == count && piece == "") {
                delete flow_piece_saved[flow_serial, i]
                continue
            }
            if (piece == "") {
                fail("empty entry between flow commas on line " source_line)
            }
            separator = find_mapping_separator(piece, 0)
            if (separator) {
                raw_key = trim(substr(piece, 1, separator - 1))
                if (raw_key ~ /^\?[[:space:]]/) {
                    raw_key = trim(substr(raw_key, 2))
                }
                key = parse_scalar_key(raw_key, source_line)
                is_merge = parsed_key_is_merge
                child = parse_value(substr(piece, separator + 1), source_line, -1, 0)
                add_mapping(node, key, child, source_line, is_merge)
            } else {
                key = parse_scalar_key(piece, source_line)
                is_merge = parsed_key_is_merge
                child = new_node("scalar", source_line, "", "null", "")
                add_mapping(node, key, child, source_line, is_merge)
            }
            delete flow_piece_saved[flow_serial, i]
        }
        return node
    }

    if (substr(value, 1, 1) == "[" || substr(value, 1, 1) == "{") {
        fail("multiline or unclosed flow collection on line " source_line)
    }

    if ((substr(value, 1, 1) == "\"" && substr(value, length(value), 1) != "\"") ||
        (substr(value, 1, 1) == sprintf("%c", 39) && substr(value, length(value), 1) != sprintf("%c", 39))) {
        fail("trailing content after quoted scalar on line " source_line)
    }
    node = new_node("scalar", source_line, scalar_value(value), scalar_type(value, tag, scalar_value(value)), tag)
    bind_anchor(anchor, node, source_line)
    return node
}

function parse_value(value, source_line, indent, allow_block,    cleaned, remainder, tag, anchor, node) {
    cleaned = strip_inline_comment(trim(value))
    remainder = parse_properties(cleaned, source_line)
    tag = parsed_tag
    anchor = parsed_anchor

    if (remainder == "") {
        node = new_node("pending", source_line, "", "", tag)
        bind_anchor(anchor, node, source_line)
        return node
    }
    if (!allow_block && remainder == "-") {
        fail("plain dash is not valid in a flow collection on line " source_line)
    }
    if (allow_block && remainder ~ /^[|>]([-+]?[1-9]?|[1-9][-+]?)$/) {
        node = new_node("scalar", source_line, "", "string", tag)
        bind_anchor(anchor, node, source_line)
        start_block(node, remainder, indent, source_line)
        return node
    }
    if (allow_block && remainder ~ /^[|>]/) {
        fail("invalid block scalar indicator on line " source_line)
    }
    if (!(substr(remainder, 1, 1) == "*" && valid_anchor_name(substr(remainder, 2))) &&
        find_top_level_colon(remainder, 1)) {
        fail("mapping indicator inside plain scalar on line " source_line)
    }
    return parse_core(remainder, source_line, tag, anchor)
}

function clear_deeper(indent,    i) {
    for (i = indent + 1; i <= max_indent; i++) {
        delete context_node[i]
        delete context_valid[i]
        delete list_node[i]
        delete list_valid[i]
        delete explicit_key[i]
        delete explicit_key_valid[i]
    }
    if (indent > max_indent) {
        max_indent = indent
    }
}

function clear_structure(    i) {
    for (i = 0; i <= max_indent; i++) {
        delete context_node[i]
        delete context_valid[i]
        delete list_node[i]
        delete list_valid[i]
        delete explicit_key[i]
        delete explicit_key_valid[i]
    }
    max_indent = 0
}

function find_parent(indent,    i) {
    for (i = indent - 1; i >= 0; i--) {
        if (context_valid[i]) {
            return context_node[i]
        }
    }
    return 0
}

function fail_pending_explicit_keys(source_line,    i) {
    for (i = 0; i <= max_indent; i++) {
        if (explicit_key_valid[i]) {
            add_explicit_null(i, source_line)
        }
    }
}

function start_block(node, indicator, indent, source_line,    digit) {
    block_active = 1
    block_node = node
    block_style = substr(indicator, 1, 1)
    block_chomp = "clip"
    if (indicator ~ /-/) {
        block_chomp = "strip"
    } else if (indicator ~ /\+/) {
        block_chomp = "keep"
    }
    block_base_indent = document_marker_inline ? -1 : indent
    digit = indicator
    gsub(/[^1-9]/, "", digit)
    block_content_indent = digit == "" ? -1 : block_base_indent + (digit + 0)
    block_count = 0
    block_source_line = source_line
}

function append_block_line(value, more_indented, raw_blank) {
    block_lines[++block_count] = value
    block_line_more[block_count] = more_indented
    block_line_raw_blank[block_count] = raw_blank
}

function flush_block(    value, i, line, previous, more, previous_more, seen_nonblank, last_nonblank_more, blank_run) {
    if (!block_active) {
        return
    }

    value = ""
    previous = ""
    previous_more = 0
    seen_nonblank = 0
    last_nonblank_more = 0
    blank_run = 0
    for (i = 1; i <= block_count; i++) {
        line = block_lines[i]
        if (block_line_raw_blank[i]) {
            if (block_content_indent >= 0) {
                line = length(line) > block_content_indent ? substr(line, block_content_indent + 1) : ""
            } else {
                line = ""
            }
        }
        more = block_line_more[i]
        if (block_line_raw_blank[i] && line != "") {
            more = 1
        }
        if (block_style == "|") {
            value = value line "\n"
        } else if (line == "") {
            value = value "\n"
            blank_run = 1
        } else {
            if (i == 1 || previous == "") {
                if (blank_run && seen_nonblank && (last_nonblank_more || more)) {
                    value = value "\n"
                }
                value = value line
            } else if (previous_more || more) {
                value = value "\n" line
            } else {
                value = value " " line
            }
            seen_nonblank = 1
            last_nonblank_more = more
            blank_run = 0
        }
        previous = line
        previous_more = more
        delete block_lines[i]
        delete block_line_more[i]
        delete block_line_raw_blank[i]
    }
    if (block_style == ">" && block_count > 0 && previous != "") {
        value = value "\n"
    }

    if (block_chomp == "strip") {
        while (substr(value, length(value), 1) == "\n") {
            value = substr(value, 1, length(value) - 1)
        }
    } else if (block_chomp == "clip") {
        while (substr(value, length(value), 1) == "\n") {
            value = substr(value, 1, length(value) - 1)
        }
        if (value != "") {
            value = value "\n"
        }
    }

    node_value[block_node] = value
    block_active = 0
    block_count = 0
}

function parse_mapping_into(value, parent, indent, source_line,    separator, raw_key, key, child, raw_value, is_merge) {
    separator = find_mapping_separator(value, 1)
    if (!separator) {
        fail("invalid mapping syntax on line " source_line)
    }

    raw_key = trim(substr(value, 1, separator - 1))
    key = parse_scalar_key(raw_key, source_line)
    is_merge = parsed_key_is_merge
    raw_value = trim(substr(value, separator + 1))
    child = parse_value(raw_value, source_line, indent, 1)
    add_mapping(parent, key, child, source_line, is_merge)

    delete list_node[indent]
    delete list_valid[indent]
    if (node_kind[child] == "pending") {
        context_node[indent] = child
        context_valid[indent] = 1
    } else if (node_kind[child] == "scalar" && raw_value != "" && substr(raw_value, 1, 1) != "\"" &&
        substr(raw_value, 1, 1) != sprintf("%c", 39) && substr(raw_value, 1, 1) !~ /^[\[{!&*|>]$/) {
        context_node[indent] = child
        context_valid[indent] = 1
        node_plain_continuable[child] = 1
        node_last_content_line[child] = source_line
    } else {
        delete context_node[indent]
        delete context_valid[indent]
    }
    return child
}

function parse_mapping_line(value, indent, source_line,    parent) {
    parent = find_parent(indent)
    if (!parent) {
        parent = ensure_root("mapping", source_line)
    } else {
        ensure_container(parent, "mapping", source_line)
    }
    parse_mapping_into(value, parent, indent, source_line)
}

function parse_sequence_line(value, indent, source_line,    sequence, parent, original, remainder, tag, anchor, item, separator, raw_key, key, child) {
    if (indent > max_indent) {
        max_indent = indent
    }
    if (list_valid[indent]) {
        sequence = list_node[indent]
    } else if (context_valid[indent]) {
        sequence = context_node[indent]
        ensure_container(sequence, "sequence", source_line)
    } else {
        parent = find_parent(indent)
        if (!parent) {
            sequence = ensure_root("sequence", source_line)
        } else {
            sequence = parent
            ensure_container(sequence, "sequence", source_line)
        }
    }

    list_node[indent] = sequence
    list_valid[indent] = 1
    original = trim(substr(value, 2))

    if (original == "") {
        item = new_node("pending", source_line, "", "", "")
    } else if (original == "-" || original ~ /^-[[:space:]]/) {
        item = new_node("sequence", source_line, "", "", "")
        add_sequence(sequence, item, source_line)
        context_node[indent] = item
        context_valid[indent] = 1
        parse_sequence_line(original, indent + 2, source_line)
        return
    } else {
        remainder = parse_properties(strip_inline_comment(original), source_line)
        tag = parsed_tag
        anchor = parsed_anchor
        separator = find_mapping_separator(remainder, 1)
        if (separator && substr(remainder, 1, 1) != "{" && substr(remainder, 1, 1) != "[") {
            item = new_node("mapping", source_line, "", "", tag)
            bind_anchor(anchor, item, source_line)
            add_sequence(sequence, item, source_line)
            context_node[indent] = item
            context_valid[indent] = 1
            parse_mapping_into(remainder, item, indent + 2, source_line)
            return
        }
        item = parse_value(original, source_line, indent, 1)
    }

    add_sequence(sequence, item, source_line)
    if (node_kind[item] == "pending" || node_kind[item] == "mapping" ||
        (node_kind[item] == "scalar" && original != "" && substr(original, 1, 1) != "\"" &&
        substr(original, 1, 1) != sprintf("%c", 39))) {
        context_node[indent] = item
        context_valid[indent] = 1
        if (node_kind[item] == "scalar") {
            node_plain_continuable[item] = 1
            node_last_content_line[item] = source_line
        }
    } else {
        delete context_node[indent]
        delete context_valid[indent]
    }
}

function indentation(value, source_line,    copy) {
    copy = value
    sub(/[^ ].*$/, "", copy)
    if (substr(value, 1, length(copy) + 1) ~ /^ *\t/) {
        fail("tabs cannot be used for indentation on line " source_line)
    }
    return length(copy)
}

function parse_directive(text, source_line,    count, i, handle, prefix) {
    for (i = 1; i <= directive_piece_count; i++) {
        delete directive_piece[i]
    }
    count = split(text, directive_piece, /[[:space:]]+/)
    directive_piece_count = count

    document_directive_pending[document_index] = 1
    if (directive_piece[1] == "%YAML") {
        if (count != 2 || directive_piece[2] !~ /^[0-9]+\.[0-9]+$/) {
            fail("malformed YAML directive on line " source_line)
        }
        if (document_yaml_directive_seen[document_index]) {
            fail("duplicate YAML directive on line " source_line)
        }
        document_yaml_directive_seen[document_index] = 1
        document_yaml_version[document_index] = directive_piece[2]
        return
    }
    if (directive_piece[1] == "%TAG" && count == 3) {
        handle = directive_piece[2]
        prefix = directive_piece[3]
        if (substr(handle, 1, 1) == "!" && substr(handle, length(handle), 1) == "!") {
            if (document_tag_directive_seen[document_index SUBSEP handle]) {
                fail("duplicate TAG directive on line " source_line)
            }
            document_tag_directive_seen[document_index SUBSEP handle] = 1
            tag_prefix[document_index SUBSEP handle] = prefix
            return
        }
        fail("malformed TAG directive on line " source_line)
    }
    if (directive_piece[1] == "%TAG") {
        fail("malformed TAG directive on line " source_line)
    }
    if (substr(directive_piece[1], 1, 1) == "%") {
        return
    }
    fail("unsupported or malformed directive on line " source_line)
}

function add_explicit_value(indent, text, source_line,    parent, child, raw_value) {
    if (!explicit_key_valid[indent]) {
        fail("explicit mapping value has no scalar key on line " source_line)
    }
    parent = find_parent(indent)
    if (!parent) {
        parent = ensure_root("mapping", source_line)
    } else {
        ensure_container(parent, "mapping", source_line)
    }
    raw_value = trim(substr(text, 2))
    child = parse_value(raw_value, source_line, indent, 1)
    add_mapping(parent, explicit_key[indent], child, source_line, 0)
    delete explicit_key[indent]
    delete explicit_key_valid[indent]
    if (node_kind[child] == "pending" || (node_kind[child] == "scalar" && raw_value != "" &&
        substr(raw_value, 1, 1) != "\"" && substr(raw_value, 1, 1) != sprintf("%c", 39))) {
        context_node[indent] = child
        context_valid[indent] = 1
        if (node_kind[child] == "scalar") {
            node_plain_continuable[child] = 1
            node_last_content_line[child] = source_line
        }
    }
}

function add_explicit_null(indent, source_line,    parent, child) {
    if (!explicit_key_valid[indent]) {
        return
    }
    parent = find_parent(indent)
    if (!parent) {
        parent = ensure_root("mapping", source_line)
    } else {
        ensure_container(parent, "mapping", source_line)
    }
    child = new_node("scalar", source_line, "", "null", "")
    add_mapping(parent, explicit_key[indent], child, source_line, 0)
    delete explicit_key[indent]
    delete explicit_key_valid[indent]
    delete explicit_key_last_line[indent]
}

function find_explicit_key_indent(indent,    i) {
    for (i = indent - 1; i >= 0; i--) {
        if (explicit_key_valid[i]) {
            return i
        }
    }
    return -1
}

function fill_pending_scalar(node, text, source_line,    cleaned, remainder, tag, anchor) {
    cleaned = strip_inline_comment(trim(text))
    remainder = parse_properties(cleaned, source_line)
    tag = parsed_tag
    anchor = parsed_anchor
    if (remainder == "" || substr(remainder, 1, 1) == "[" || substr(remainder, 1, 1) == "{" || remainder ~ /^[|>]/) {
        return 0
    }
    node_kind[node] = "scalar"
    node_value[node] = scalar_value(remainder)
    if (tag == "") {
        tag = node_tag[node]
    } else if (node_tag[node] != "" && node_tag[node] != tag) {
        fail("multiple tags on one node on line " source_line)
    }
    node_type[node] = scalar_type(remainder, tag, node_value[node])
    node_tag[node] = tag
    if (anchor != "") {
        if (node_anchor[node] != "") {
            fail("multiple anchors on one node on line " source_line)
        }
        bind_anchor(anchor, node, source_line)
    }
    if (substr(remainder, 1, 1) != "\"" && substr(remainder, 1, 1) != sprintf("%c", 39)) {
        node_plain_continuable[node] = 1
        node_last_content_line[node] = source_line
    }
    return 1
}

function extend_pending_properties(node, text, source_line,    remainder, tag, anchor) {
    remainder = parse_properties(strip_inline_comment(trim(text)), source_line)
    tag = parsed_tag
    anchor = parsed_anchor
    if (remainder != "" || (tag == "" && anchor == "")) {
        return 0
    }
    if (tag != "") {
        if (node_tag[node] != "" && node_tag[node] != tag) {
            fail("multiple tags on one node on line " source_line)
        }
        node_tag[node] = tag
    }
    if (anchor != "") {
        if (node_anchor[node] != "") {
            fail("multiple anchors on one node on line " source_line)
        }
        bind_anchor(anchor, node, source_line)
    }
    return 1
}

function append_plain_scalar(node, text, source_line,    cleaned, separator) {
    cleaned = strip_inline_comment(trim(text))
    if (cleaned == "") {
        return 0
    }
    if (find_top_level_colon(cleaned, 1)) {
        fail("mapping indicator inside multiline plain scalar on line " source_line)
    }
    separator = source_line > node_last_content_line[node] + 1 ? "\n" : " "
    node_value[node] = node_value[node] separator scalar_value(cleaned)
    node_type[node] = scalar_type(node_value[node], node_tag[node], node_value[node])
    node_last_content_line[node] = source_line
    return 1
}

function process_line(raw, source_line,    indent, text, clean, key_text, separator, root, marker_content, parent, prefix, candidate, tab_position, explicit_indent) {
    sub(/\r$/, "", raw)

    if (block_active) {
        candidate = strip_inline_comment(trim(raw))
        if (raw !~ /^[[:space:]]/ && (candidate == "..." || candidate == "---" || candidate ~ /^---[[:space:]]/)) {
            flush_block()
        }
    }

    if (block_active) {
        if (raw ~ /^[[:space:]]*$/) {
            append_block_line(raw, 0, 1)
            return
        }
        prefix = raw
        sub(/[^ ].*$/, "", prefix)
        indent = length(prefix)
        if (block_content_indent < 0 && indent > block_base_indent) {
            block_content_indent = indent
        }
        if (block_content_indent >= 0 && indent >= block_content_indent) {
            append_block_line(substr(raw, block_content_indent + 1),
                indent > block_content_indent || substr(raw, block_content_indent + 1, 1) ~ /[ \t]/, 0)
            return
        }
        if (block_content_indent >= 0 && trim(raw) ~ /^#/) {
            flush_block()
        } else if (indent > block_base_indent) {
            if (block_content_indent < 0 || indent < block_content_indent) {
                fail("invalid block scalar indentation on line " source_line)
            }
        } else {
            flush_block()
        }
    }

    if (raw ~ /^[[:space:]]*$/ || raw ~ /^[[:space:]]*#/) {
        return
    }

    prefix = raw
    sub(/[^ \t].*$/, "", prefix)
    if (index(prefix, "\t")) {
        candidate = substr(raw, length(prefix) + 1)
        tab_position = index(raw, "\t")
        if (substr(candidate, 1, 1) == "[" || substr(candidate, 1, 1) == "{" ||
            find_mapping_separator(candidate, 1)) {
            raw = candidate
        } else {
            raw = substr(raw, 1, tab_position - 1) candidate
        }
    }

    root = (document_index in document_root) ? document_root[document_index] : 0
    candidate = strip_inline_comment(trim(raw))
    if (!document_ended && root && node_kind[root] == "scalar" && node_plain_continuable[root] &&
        !(raw !~ /^[[:space:]]/ && (candidate == "---" || candidate ~ /^---[[:space:]]/ || candidate == "...")) &&
        (raw ~ /^[[:space:]]/ || !find_mapping_separator(candidate, 1))) {
        append_plain_scalar(root, raw, source_line)
        return
    }

    indent = indentation(raw, source_line)
    text = substr(raw, indent + 1)
    clean = strip_inline_comment(text)

    root = (document_index in document_root) ? document_root[document_index] : 0
    if (root && indent == 0 && node_kind[root] == "pending") {
        if (extend_pending_properties(root, text, source_line)) {
            return
        }
        if (text != "-" && text !~ /^-[[:space:]]/ &&
            text != "?" && text !~ /^\?[[:space:]]/ &&
            text != ":" && text !~ /^:[[:space:]]/ &&
            !find_mapping_separator(text, 1) && fill_pending_scalar(root, text, source_line)) {
            return
        }
    }

    if (substr(text, 1, 1) == "%") {
        if (document_ended && indent == 0) {
            document_index++
            document_ended = 0
            clear_structure()
        } else if (indent != 0 || (document_index in document_root) || document_explicit[document_index]) {
            fail("directives must appear before a document on line " source_line)
        }
        parse_directive(clean, source_line)
        return
    }

    if (clean == "---" || clean ~ /^---[[:space:]]/) {
        marker_content = trim(substr(clean, 4))
        fail_pending_explicit_keys(source_line)
        if (document_has_content[document_index] || document_explicit[document_index]) {
            if (!document_has_content[document_index]) {
                create_empty_document(source_line)
            }
            document_index++
        }
        document_explicit[document_index] = 1
        delete document_directive_pending[document_index]
        document_ended = 0
        clear_structure()
        if (marker_content != "") {
            document_marker_inline = 1
            process_line(marker_content, source_line)
            document_marker_inline = 0
        }
        return
    }
    if (clean == "...") {
        if (document_ended) {
            return
        }
        if (document_directive_pending[document_index]) {
            fail("directive requires a document marker before line " source_line)
        }
        fail_pending_explicit_keys(source_line)
        if (!document_has_content[document_index] && document_explicit[document_index]) {
            create_empty_document(source_line)
        }
        document_ended = 1
        clear_structure()
        return
    }
    if (document_ended) {
        if ((document_index in document_root) || document_explicit[document_index] || document_has_content[document_index]) {
            document_index++
        }
        document_ended = 0
        clear_structure()
    }

    clear_deeper(indent)
    explicit_indent = find_explicit_key_indent(indent)
    if (explicit_indent >= 0) {
        separator = source_line > explicit_key_last_line[explicit_indent] + 1 ? "\n" : " "
        explicit_key[explicit_indent] = explicit_key[explicit_indent] separator scalar_value(strip_inline_comment(trim(text)))
        explicit_key_last_line[explicit_indent] = source_line
        return
    }
    parent = find_parent(indent)
    if (parent && node_kind[parent] == "scalar" && node_plain_continuable[parent]) {
        append_plain_scalar(parent, text, source_line)
        return
    }
    if (parent && node_kind[parent] == "pending" &&
        trim(text) ~ /^[|>]([-+]?[1-9]?|[1-9][-+]?)$/) {
        node_kind[parent] = "scalar"
        node_value[parent] = ""
        node_type[parent] = "string"
        start_block(parent, trim(text), indentation(raw_input_line[node_line[parent]], source_line), source_line)
        return
    }
    if (parent && node_kind[parent] == "pending" &&
        text != "-" && text !~ /^-[[:space:]]/ &&
        text != "?" && text !~ /^\?[[:space:]]/ &&
        text != ":" && text !~ /^:[[:space:]]/ &&
        !find_top_level_colon(text, 1)) {
        if (extend_pending_properties(parent, text, source_line)) {
            return
        }
        if (fill_pending_scalar(parent, text, source_line)) {
            return
        }
    }
    if (text == "?" || text ~ /^\?[[:space:]]/) {
        if (explicit_key_valid[indent]) {
            add_explicit_null(indent, source_line)
        }
        key_text = trim(substr(text, 2))
        if (key_text == "" || substr(key_text, 1, 1) == "[" || substr(key_text, 1, 1) == "{" || find_top_level_colon(key_text, 1)) {
            fail("collection-valued complex keys are not supported on line " source_line)
        }
        explicit_key[indent] = parse_scalar_key(key_text, source_line)
        explicit_key_valid[indent] = 1
        explicit_key_last_line[indent] = source_line
        return
    }
    if (text == ":" || text ~ /^:[[:space:]]/) {
        add_explicit_value(indent, text, source_line)
        return
    }
    if (explicit_key_valid[indent]) {
        add_explicit_null(indent, source_line)
    }

    if (text == "-" || text ~ /^-[[:space:]]/) {
        parse_sequence_line(text, indent, source_line)
        return
    }

    separator = find_mapping_separator(text, 1)
    if (separator) {
        parse_mapping_line(text, indent, source_line)
        return
    }

    if ((indent != 0 && substr(trim(text), 1, 1) != "[" && substr(trim(text), 1, 1) != "{") ||
        (document_index in document_root)) {
        fail("unknown syntax on line " source_line)
    }
    root = parse_value(text, source_line, indent, 1)
    document_root[document_index] = root
    document_has_content[document_index] = 1
    if (node_kind[root] == "scalar" && substr(trim(text), 1, 1) != "\"" &&
        substr(trim(text), 1, 1) != sprintf("%c", 39)) {
        node_plain_continuable[root] = 1
        node_last_content_line[root] = source_line
    }
}

function quote_is_open(value, quote,    i, char, escaped) {
    escaped = 0
    for (i = 2; i <= length(value); i++) {
        char = substr(value, i, 1)
        if (quote == "\"" && escaped) {
            escaped = 0
            continue
        }
        if (quote == "\"" && char == "\\") {
            escaped = 1
            continue
        }
        if (char == quote) {
            if (quote == sprintf("%c", 39) && substr(value, i + 1, 1) == quote) {
                i++
                continue
            }
            return 0
        }
    }
    return 1
}

function multiline_quote_is_open(value, quote,    i, char, escaped, open) {
    escaped = 0
    open = 0
    for (i = 1; i <= length(value); i++) {
        char = substr(value, i, 1)
        if (quote == "\"" && open && escaped) {
            escaped = 0
            continue
        }
        if (quote == "\"" && open && char == "\\") {
            escaped = 1
            continue
        }
        if (char == quote) {
            if (quote == sprintf("%c", 39) && open && substr(value, i + 1, 1) == quote) {
                i++
                continue
            }
            open = !open
        }
    }
    return open
}

function multiline_scalar_quote(raw,    first_line, indent, text, clean, separator, candidate, space, token, quote) {
    first_line = raw
    sub(/\n.*/, "", first_line)
    candidate = first_line
    sub(/[^ ].*$/, "", candidate)
    indent = length(candidate)
    text = substr(first_line, indent + 1)
    clean = trim(text)

    if (clean ~ /^---[[:space:]]/) {
        candidate = trim(substr(clean, 4))
    } else if (clean ~ /^-[[:space:]]/) {
        candidate = trim(substr(clean, 2))
    } else {
        separator = find_top_level_colon(clean, 1)
        candidate = separator ? trim(substr(clean, separator + 1)) : clean
    }

    while (substr(candidate, 1, 1) == "&" || substr(candidate, 1, 1) == "!") {
        space = match(candidate, /[[:space:]]/)
        if (!space) {
            return ""
        }
        token = substr(candidate, 1, space - 1)
        candidate = trim(substr(candidate, space + 1))
    }

    quote = substr(candidate, 1, 1)
    if (quote != "\"" && quote != sprintf("%c", 39)) {
        return ""
    }
    return quote_is_open(candidate, quote) ? quote : ""
}

function flow_balance(value,    i, char, quote, escaped, braces, brackets, previous) {
    quote = ""
    escaped = 0
    braces = 0
    brackets = 0
    for (i = 1; i <= length(value); i++) {
        char = substr(value, i, 1)
        previous = i > 1 ? substr(value, i - 1, 1) : ""
        if (escaped) {
            escaped = 0
            continue
        }
        if (quote == "\"" && char == "\\") {
            escaped = 1
            continue
        }
        if (quote != "") {
            if (char == quote) {
                quote = ""
            }
            continue
        }
        if (char == "\"" || char == sprintf("%c", 39)) {
            quote = char
        } else if (char == "#" && (i == 1 || previous ~ /[[:space:]]/)) {
            break
        } else if (char == "{") {
            braces++
        } else if (char == "}") {
            braces--
        } else if (char == "[") {
            brackets++
        } else if (char == "]") {
            brackets--
        }
    }
    return braces + brackets
}

function finalize_nodes(    node) {
    for (node = 1; node <= node_count; node++) {
        if (node_kind[node] == "pending") {
            node_kind[node] = "scalar"
            node_value[node] = ""
            node_type[node] = node_tag[node] == "tag:yaml.org,2002:str" ? "string" : "null"
        }
    }
}

function resolve_alias(node,    serial, key) {
    serial = ++resolution_serial
    while (node_kind[node] == "alias") {
        key = serial SUBSEP node
        if (key in resolution_seen) {
            fail("recursive alias chain at node " node)
        }
        resolution_seen[key] = 1
        node = alias_target[node]
    }
    return node
}

function validate_aliases(    node, parent) {
    for (node = 1; node <= node_count; node++) {
        if (node_kind[node] != "alias") {
            continue
        }
        parent = node_parent[node]
        while (parent) {
            if (parent == alias_target[node]) {
                fail("recursive alias *" node_value[node] " on line " node_line[node])
            }
            parent = node_parent[parent]
        }
    }
}

function validate_merge_source(node, source_line,    resolved, i) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] == "mapping") {
        return
    }
    if (node_kind[resolved] == "sequence") {
        for (i = 1; i <= sequence_count[resolved]; i++) {
            if (node_kind[resolve_alias(sequence_child[resolved, i])] != "mapping") {
                fail("merge sequence contains a non-mapping source on line " source_line)
            }
        }
        return
    }
    fail("merge source is not a mapping or sequence of mappings on line " source_line)
}

function validate_merges(    node, i) {
    for (node = 1; node <= node_count; node++) {
        if (node_kind[node] != "mapping") {
            continue
        }
        for (i = 1; i <= mapping_count[node]; i++) {
            if (mapping_merge[node, i]) {
                validate_merge_source(mapping_child[node, i], node_line[mapping_child[node, i]])
            }
        }
    }
}

function mapping_lookup_from_source(source, key, serial,    resolved, i, result) {
    resolved = resolve_alias(source)
    if (node_kind[resolved] == "mapping") {
        return mapping_lookup_internal(resolved, key, serial)
    }
    if (node_kind[resolved] == "sequence") {
        for (i = 1; i <= sequence_count[resolved]; i++) {
            result = mapping_lookup_from_source(sequence_child[resolved, i], key, serial)
            if (result) {
                return result
            }
        }
    }
    return 0
}

function mapping_lookup_internal(mapping, key, serial,    visit_key, i, result) {
    mapping = resolve_alias(mapping)
    visit_key = serial SUBSEP mapping SUBSEP key
    if (visit_key in lookup_seen) {
        fail("recursive merge while resolving key " key)
    }
    lookup_seen[visit_key] = 1

    for (i = 1; i <= mapping_count[mapping]; i++) {
        if (!mapping_merge[mapping, i] && mapping_key[mapping, i] == key) {
            delete lookup_seen[visit_key]
            return mapping_child[mapping, i]
        }
    }
    for (i = 1; i <= mapping_count[mapping]; i++) {
        if (mapping_merge[mapping, i]) {
            result = mapping_lookup_from_source(mapping_child[mapping, i], key, serial)
            if (result) {
                delete lookup_seen[visit_key]
                return result
            }
        }
    }
    delete lookup_seen[visit_key]
    return 0
}

function mapping_lookup(mapping, key) {
    return mapping_lookup_internal(mapping, key, ++lookup_serial)
}

function expression_token_name(type) {
    if (type == "end") {
        return "end of expression"
    }
    if (expression_token_value != "") {
        return expression_token_value
    }
    return type
}

function expression_is_word_char(char) {
    return char ~ /^[A-Za-z0-9_-]$/
}

function expression_token_is_key() {
    return expression_token_type == "identifier" || expression_token_type == "and" ||
        expression_token_type == "or" || expression_token_type == "not" ||
        expression_token_type == "literal_true" || expression_token_type == "literal_false" ||
        expression_token_type == "literal_null"
}

function expression_lex_next(    char, next_char, start, quote, escaped, word, lowered) {
    while (expression_position <= length(expression_source) && substr(expression_source, expression_position, 1) ~ /[[:space:]]/) {
        expression_position++
    }
    expression_token_value = ""
    if (expression_position > length(expression_source)) {
        expression_token_type = "end"
        return
    }

    char = substr(expression_source, expression_position, 1)
    next_char = substr(expression_source, expression_position + 1, 1)
    if (char next_char == "//") {
        expression_token_type = "alternative"
        expression_token_value = "//"
        expression_position += 2
        return
    }
    if (char next_char == "..") {
        expression_token_type = "recursive"
        expression_token_value = ".."
        expression_position += 2
        return
    }
    if (char next_char == "|=") {
        expression_token_type = "update"
        expression_token_value = "|="
        expression_position += 2
        return
    }
    if ((char == "+" || char == "-" || char == "*" || char == "/" || char == "%") && next_char == "=") {
        expression_token_type = "compound"
        expression_token_value = char next_char
        expression_position += 2
        return
    }
    if (char next_char == "==" || char next_char == "!=" || char next_char == ">=" || char next_char == "<=") {
        expression_token_type = "compare"
        expression_token_value = char next_char
        expression_position += 2
        return
    }
    if (char == ">" || char == "<") {
        expression_token_type = "compare"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == "=") {
        expression_token_type = "assign"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == ".") {
        expression_token_type = "dot"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == "|") {
        expression_token_type = "pipe"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == "(") {
        expression_token_type = "left_parenthesis"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == ")") {
        expression_token_type = "right_parenthesis"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == "[") {
        expression_token_type = "left_bracket"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == "]") {
        expression_token_type = "right_bracket"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == ",") {
        expression_token_type = "comma"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == "{") {
        expression_token_type = "left_brace"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == "}") {
        expression_token_type = "right_brace"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == ":") {
        expression_token_type = "colon"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == "?") {
        expression_token_type = "question"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == ";") {
        expression_token_type = "semicolon"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == "$") {
        start = expression_position + 1
        expression_position++
        while (expression_position <= length(expression_source) && expression_is_word_char(substr(expression_source, expression_position, 1))) {
            expression_position++
        }
        if (expression_position == start) {
            fail("variable names require characters after $")
        }
        expression_token_type = "variable"
        expression_token_value = substr(expression_source, start, expression_position - start)
        return
    }
    if (char == "+" || char == "-" || char == "*" || char == "/" || char == "%") {
        expression_token_type = "arithmetic"
        expression_token_value = char
        expression_position++
        return
    }

    quote = sprintf("%c", 39)
    if (char == "\"" || char == quote) {
        start = expression_position
        quote = char
        escaped = 0
        expression_position++
        while (expression_position <= length(expression_source)) {
            char = substr(expression_source, expression_position, 1)
            if (escaped) {
                escaped = 0
            } else if (quote == "\"" && char == "\\") {
                escaped = 1
            } else if (char == quote) {
                expression_position++
                expression_token_type = "string"
                expression_token_value = scalar_value(substr(expression_source, start, expression_position - start))
                return
            }
            expression_position++
        }
        fail("unterminated string in expression")
    }

    if (char ~ /^[0-9]$/) {
        start = expression_position
        while (expression_position <= length(expression_source) && substr(expression_source, expression_position, 1) ~ /^[0-9_]$/) {
            expression_position++
        }
        if (substr(expression_source, expression_position, 1) == "." && substr(expression_source, expression_position + 1, 1) ~ /^[0-9]$/) {
            expression_position++
            while (expression_position <= length(expression_source) && substr(expression_source, expression_position, 1) ~ /^[0-9_]$/) {
                expression_position++
            }
        }
        if (tolower(substr(expression_source, expression_position, 1)) == "e") {
            expression_position++
            if (substr(expression_source, expression_position, 1) == "+" || substr(expression_source, expression_position, 1) == "-") {
                expression_position++
            }
            while (expression_position <= length(expression_source) && substr(expression_source, expression_position, 1) ~ /^[0-9_]$/) {
                expression_position++
            }
        }
        expression_token_type = "number"
        expression_token_value = substr(expression_source, start, expression_position - start)
        return
    }

    if (expression_is_word_char(char)) {
        start = expression_position
        while (expression_position <= length(expression_source) && expression_is_word_char(substr(expression_source, expression_position, 1))) {
            expression_position++
        }
        word = substr(expression_source, start, expression_position - start)
        lowered = tolower(word)
        if (lowered == "and" || lowered == "or" || lowered == "not" || lowered == "as") {
            expression_token_type = lowered
        } else if (lowered == "true" || lowered == "false" || lowered == "null") {
            expression_token_type = "literal_" lowered
        } else {
            expression_token_type = "identifier"
        }
        expression_token_value = word
        return
    }
    fail("unexpected character in expression: " char)
}

function expression_new(kind, left, right, value,    expression) {
    expression = ++expression_count
    expression_kind[expression] = kind
    expression_left[expression] = left
    expression_right[expression] = right
    expression_value[expression] = value
    return expression
}

function expression_expect(type,    actual) {
    if (expression_token_type != type) {
        actual = expression_token_name(expression_token_type)
        fail("expected " type " but found " actual)
    }
    expression_lex_next()
}

function expression_parse_primary(    expression, name, step, argument, value, value_type, child, key, source, initial, update, variable) {
    if (expression_token_type == "dot") {
        expression = expression_new("identity", 0, 0, "")
        expression_lex_next()
        if (expression_token_is_key()) {
            expression = expression_new("key", expression, 0, expression_token_value)
            expression_lex_next()
        }
    } else if (expression_token_type == "recursive") {
        expression = expression_new("recursive", 0, 0, "")
        expression_lex_next()
    } else if (expression_token_type == "string") {
        expression = expression_new("literal", 0, 0, expression_token_value)
        expression_literal_type[expression] = "string"
        expression_lex_next()
    } else if (expression_token_type == "number") {
        value = expression_token_value
        value_type = scalar_type(value, "", value)
        if (value_type != "int" && value_type != "float") {
            fail("invalid numeric literal: " value)
        }
        expression = expression_new("literal", 0, 0, value)
        expression_literal_type[expression] = value_type
        expression_lex_next()
    } else if (expression_token_type == "literal_true" || expression_token_type == "literal_false") {
        expression = expression_new("literal", 0, 0, tolower(expression_token_value))
        expression_literal_type[expression] = "bool"
        expression_lex_next()
    } else if (expression_token_type == "literal_null") {
        expression = expression_new("literal", 0, 0, "")
        expression_literal_type[expression] = "null"
        expression_lex_next()
    } else if (expression_token_type == "variable") {
        expression = expression_new("variable", 0, 0, expression_token_value)
        expression_lex_next()
    } else if (expression_token_type == "left_parenthesis") {
        expression_lex_next()
        expression = expression_parse_stream()
        expression_expect("right_parenthesis")
    } else if (expression_token_type == "left_bracket") {
        expression = expression_new("array", 0, 0, "")
        expression_lex_next()
        if (expression_token_type != "right_bracket") {
            while (1) {
                child = expression_parse_pipe()
                expression_child[expression, ++expression_child_count[expression]] = child
                if (expression_token_type != "comma") {
                    break
                }
                expression_lex_next()
            }
        }
        expression_expect("right_bracket")
    } else if (expression_token_type == "left_brace") {
        expression = expression_new("object", 0, 0, "")
        expression_lex_next()
        if (expression_token_type != "right_brace") {
            while (1) {
                if (expression_token_type != "identifier" && expression_token_type != "string") {
                    fail("object keys must be identifiers or strings")
                }
                key = expression_token_value
                expression_lex_next()
                expression_expect("colon")
                child = expression_parse_pipe()
                expression_object_key[expression, ++expression_child_count[expression]] = key
                expression_child[expression, expression_child_count[expression]] = child
                if (expression_token_type != "comma") {
                    break
                }
                expression_lex_next()
            }
        }
        expression_expect("right_brace")
    } else if (expression_token_type == "identifier") {
        name = tolower(expression_token_value)
        expression_lex_next()
        if (name == "reduce") {
            source = expression_parse_assignment()
            expression_expect("as")
            if (expression_token_type != "variable") {
                fail("reduce requires a variable after as")
            }
            variable = expression_token_value
            expression_lex_next()
            expression_expect("left_parenthesis")
            initial = expression_parse_pipe()
            expression_expect("semicolon")
            update = expression_parse_pipe()
            expression_expect("right_parenthesis")
            expression = expression_new("reduce", source, initial, variable)
            expression_child[expression, 1] = update
        } else if (name == "select" || name == "has" || name == "del" || name == "map" || name == "map_values" || name == "with_entries" ||
            name == "contains" || name == "startswith" || name == "endswith" || name == "split" || name == "join" ||
            name == "sort_by" || name == "group_by" || name == "unique_by" || name == "min_by" || name == "max_by" ||
            name == "any_c" || name == "all_c") {
            expression_expect("left_parenthesis")
            argument = expression_parse_stream()
            expression_expect("right_parenthesis")
            expression = expression_new(name, argument, 0, "")
        } else if (name == "length" || name == "keys" || name == "kind" || name == "type" || name == "to_entries" || name == "from_entries" ||
            name == "sort" || name == "unique" || name == "flatten" || name == "reverse" || name == "upcase" || name == "downcase" ||
            name == "min" || name == "max" || name == "any" || name == "all" || name == "add") {
            if (expression_token_type == "left_parenthesis") {
                expression_lex_next()
                expression_expect("right_parenthesis")
            }
            expression = expression_new(name, 0, 0, "")
        } else {
            fail("unknown expression operator: " name)
        }
    } else {
        fail("expected expression but found " expression_token_name(expression_token_type))
    }

    if (expression_token_type == "question") {
        expression_optional[expression] = 1
        expression_lex_next()
    }
    while (1) {
        if (expression_token_type == "dot") {
            expression_lex_next()
            if (!expression_token_is_key()) {
                fail("expected a key after .")
            }
            expression = expression_new("key", expression, 0, expression_token_value)
            expression_lex_next()
        } else if (expression_token_type == "left_bracket") {
            expression_lex_next()
            if (expression_token_type == "right_bracket") {
                expression = expression_new("each", expression, 0, "")
                expression_lex_next()
            } else if (expression_token_type == "number") {
                if (expression_token_value !~ /^-?[0-9]+$/) {
                    fail("sequence indexes must be integers")
                }
                step = expression_token_value + 0
                expression_lex_next()
                expression_expect("right_bracket")
                expression = expression_new("index", expression, 0, step)
            } else if (expression_token_type == "string") {
                step = expression_token_value
                expression_lex_next()
                expression_expect("right_bracket")
                expression = expression_new("key", expression, 0, step)
            } else {
                step = expression_parse_stream()
                expression_expect("right_bracket")
                expression = expression_new("dynamic", expression, step, "")
            }
        } else {
            break
        }
        if (expression_token_type == "question") {
            expression_optional[expression] = 1
            expression_lex_next()
        }
    }
    return expression
}

function expression_parse_unary(    operand) {
    if (expression_token_type == "not") {
        expression_lex_next()
        operand = expression_new("identity", 0, 0, "")
        return expression_new("not", operand, 0, "")
    }
    if (expression_token_type == "arithmetic" && expression_token_value == "-") {
        expression_lex_next()
        operand = expression_parse_unary()
        return expression_new("negate", operand, 0, "")
    }
    return expression_parse_primary()
}

function expression_parse_product(    left, operator, right) {
    left = expression_parse_unary()
    while (expression_token_type == "arithmetic" && (expression_token_value == "*" || expression_token_value == "/" || expression_token_value == "%")) {
        operator = expression_token_value
        expression_lex_next()
        right = expression_parse_unary()
        left = expression_new("arithmetic", left, right, operator)
    }
    return left
}

function expression_parse_sum(    left, operator, right) {
    left = expression_parse_product()
    while (expression_token_type == "arithmetic" && (expression_token_value == "+" || expression_token_value == "-")) {
        operator = expression_token_value
        expression_lex_next()
        right = expression_parse_product()
        left = expression_new("arithmetic", left, right, operator)
    }
    return left
}

function expression_parse_compare(    left, operator, right) {
    left = expression_parse_sum()
    while (expression_token_type == "compare") {
        operator = expression_token_value
        expression_lex_next()
        right = expression_parse_sum()
        left = expression_new("compare", left, right, operator)
    }
    return left
}

function expression_parse_and(    left, right) {
    left = expression_parse_compare()
    while (expression_token_type == "and") {
        expression_lex_next()
        right = expression_parse_compare()
        left = expression_new("and", left, right, "")
    }
    return left
}

function expression_parse_or(    left, right) {
    left = expression_parse_and()
    while (expression_token_type == "or") {
        expression_lex_next()
        right = expression_parse_and()
        left = expression_new("or", left, right, "")
    }
    return left
}

function expression_parse_alternative(    left, right) {
    left = expression_parse_or()
    while (expression_token_type == "alternative") {
        expression_lex_next()
        right = expression_parse_or()
        left = expression_new("alternative", left, right, "")
    }
    return left
}

function expression_parse_assignment(    left, right, kind, operator, identity, arithmetic) {
    left = expression_parse_alternative()
    if (expression_token_type == "assign" || expression_token_type == "update" || expression_token_type == "compound") {
        kind = expression_token_type
        operator = expression_token_value
        expression_lex_next()
        right = expression_parse_assignment()
        if (kind == "compound") {
            identity = expression_new("identity", 0, 0, "")
            arithmetic = expression_new("arithmetic", identity, right, substr(operator, 1, 1))
            return expression_new("update", left, arithmetic, "")
        }
        return expression_new(kind, left, right, "")
    }
    return left
}

function expression_parse_pipe(    left, right, variable) {
    left = expression_parse_assignment()
    if (expression_token_type == "as") {
        expression_lex_next()
        if (expression_token_type != "variable") {
            fail("as requires a variable")
        }
        variable = expression_token_value
        expression_lex_next()
        expression_expect("pipe")
        right = expression_parse_pipe()
        return expression_new("bind", left, right, variable)
    }
    if (expression_token_type == "pipe") {
        expression_lex_next()
        right = expression_parse_pipe()
        return expression_new("pipe", left, right, "")
    }
    return left
}

function expression_parse_stream(    left, right) {
    left = expression_parse_pipe()
    while (expression_token_type == "comma") {
        expression_lex_next()
        right = expression_parse_pipe()
        left = expression_new("comma", left, right, "")
    }
    return left
}

function expression_parse(source,    expression) {
    expression_source = source
    expression_position = 1
    expression_count = 0
    expression_lex_next()
    expression = expression_parse_stream()
    if (expression_token_type != "end") {
        fail("unexpected token after expression: " expression_token_name(expression_token_type))
    }
    return expression
}

function collect_keys_from_source(source, collection,    resolved, i) {
    resolved = resolve_alias(source)
    if (node_kind[resolved] == "mapping") {
        collect_mapping_keys(resolved, collection)
    } else if (node_kind[resolved] == "sequence") {
        for (i = 1; i <= sequence_count[resolved]; i++) {
            collect_keys_from_source(sequence_child[resolved, i], collection)
        }
    }
}

function collect_mapping_keys(mapping, collection,    stack_key, seen_key, i, key) {
    mapping = resolve_alias(mapping)
    stack_key = collection SUBSEP mapping
    if (stack_key in collection_stack) {
        fail("recursive merge while collecting mapping keys")
    }
    collection_stack[stack_key] = 1

    for (i = 1; i <= mapping_count[mapping]; i++) {
        if (mapping_merge[mapping, i]) {
            collect_keys_from_source(mapping_child[mapping, i], collection)
        }
    }
    for (i = 1; i <= mapping_count[mapping]; i++) {
        if (!mapping_merge[mapping, i]) {
            key = mapping_key[mapping, i]
            seen_key = collection SUBSEP key
            if (!(seen_key in collection_seen)) {
                collection_seen[seen_key] = 1
                collection_key[collection, ++collection_count[collection]] = key
            }
        }
    }
    delete collection_stack[stack_key]
}

function expression_stream_new() {
    return ++expression_stream_serial
}

function expression_stream_push(stream, node) {
    expression_stream_node[stream, ++expression_stream_count[stream]] = node
}

function expression_stream_single(node,    stream) {
    stream = expression_stream_new()
    expression_stream_push(stream, node)
    return stream
}

function expression_stream_append(target, source,    i) {
    for (i = 1; i <= expression_stream_count[source]; i++) {
        expression_stream_push(target, expression_stream_node[source, i])
    }
}

function expression_scalar(value, value_type) {
    return new_node("scalar", 0, value, value_type, "")
}

function expression_boolean(value) {
    if (value) {
        return expression_scalar("true", "bool")
    }
    return expression_scalar("false", "bool")
}

function expression_null() {
    return expression_scalar("", "null")
}

function expression_truthy(node,    resolved, lowered) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] != "scalar") {
        return 1
    }
    if (node_type[resolved] == "null") {
        return 0
    }
    if (node_type[resolved] == "bool") {
        lowered = tolower(node_value[resolved])
        return lowered != "false"
    }
    return 1
}

function expression_numeric(node,    resolved, value) {
    resolved = resolve_alias(node)
    if (node_type[resolved] == "int") {
        return json_integer(node_value[resolved]) + 0
    }
    value = node_value[resolved]
    gsub(/_/, "", value)
    if (tolower(value) ~ /\.(inf|nan)$/) {
        fail("non-finite numbers cannot be compared")
    }
    return value + 0
}

function expression_nodes_equal(left, right,    left_node, right_node) {
    left_node = resolve_alias(left)
    right_node = resolve_alias(right)
    if (node_kind[left_node] != "scalar" || node_kind[right_node] != "scalar") {
        return 0
    }
    if (node_type[left_node] == "null" || node_type[right_node] == "null") {
        return node_type[left_node] == "null" && node_type[right_node] == "null"
    }
    if ((node_type[left_node] == "int" || node_type[left_node] == "float") &&
        (node_type[right_node] == "int" || node_type[right_node] == "float")) {
        return expression_numeric(left_node) == expression_numeric(right_node)
    }
    if (node_type[left_node] == "bool" && node_type[right_node] == "bool") {
        return tolower(node_value[left_node]) == tolower(node_value[right_node])
    }
    return node_value[left_node] == node_value[right_node]
}

function expression_compare(left, right, operator,    left_node, right_node, left_value, right_value, equal) {
    equal = expression_nodes_equal(left, right)
    if (operator == "==") {
        return equal
    }
    if (operator == "!=") {
        return !equal
    }
    left_node = resolve_alias(left)
    right_node = resolve_alias(right)
    if (node_kind[left_node] != "scalar" || node_kind[right_node] != "scalar") {
        fail("ordering comparisons require scalar values")
    }
    if ((node_type[left_node] == "int" || node_type[left_node] == "float") &&
        (node_type[right_node] == "int" || node_type[right_node] == "float")) {
        left_value = expression_numeric(left_node)
        right_value = expression_numeric(right_node)
    } else if (node_type[left_node] == "string" && node_type[right_node] == "string") {
        left_value = node_value[left_node]
        right_value = node_value[right_node]
    } else {
        fail("ordering comparisons require two numbers or two strings")
    }
    if (operator == ">") {
        return left_value > right_value
    }
    if (operator == ">=") {
        return left_value >= right_value
    }
    if (operator == "<") {
        return left_value < right_value
    }
    return left_value <= right_value
}

function expression_mapping_length(node,    collection) {
    collection = ++collection_serial
    collect_mapping_keys(node, collection)
    return collection_count[collection]
}

function expression_kind_name(node,    resolved) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] == "mapping") {
        return "map"
    }
    if (node_kind[resolved] == "sequence") {
        return "seq"
    }
    return "scalar"
}

function expression_type_name(node,    resolved) {
    resolved = resolve_alias(node)
    if (node_tag[resolved] != "") {
        if (node_tag[resolved] ~ /^tag:yaml.org,2002:/) {
            return "!!" substr(node_tag[resolved], length("tag:yaml.org,2002:") + 1)
        }
        return node_tag[resolved]
    }
    if (node_kind[resolved] == "mapping") {
        return "!!map"
    }
    if (node_kind[resolved] == "sequence") {
        return "!!seq"
    }
    if (node_type[resolved] == "string") {
        return "!!str"
    }
    if (node_type[resolved] == "tagged") {
        return "!"
    }
    return "!!" node_type[resolved]
}

function expression_clone_node(source,    resolved, clone, i, collection, key, child) {
    resolved = resolve_alias(source)
    clone = new_node(node_kind[resolved], 0, node_value[resolved], node_type[resolved], node_tag[resolved])
    node_origin[clone] = (resolved in node_origin) ? node_origin[resolved] : resolved
    if (node_kind[resolved] == "sequence") {
        for (i = 1; i <= sequence_count[resolved]; i++) {
            add_sequence(clone, expression_clone_node(sequence_child[resolved, i]), 0)
        }
    } else if (node_kind[resolved] == "mapping") {
        collection = ++collection_serial
        collect_mapping_keys(resolved, collection)
        for (i = 1; i <= collection_count[collection]; i++) {
            key = collection_key[collection, i]
            child = mapping_lookup(resolved, key)
            add_mapping(clone, key, expression_clone_node(child), 0, 0)
        }
    }
    return clone
}

function expression_clear_node(node,    i, key) {
    if (node_kind[node] == "mapping") {
        for (i = 1; i <= mapping_count[node]; i++) {
            key = mapping_key[node, i]
            delete mapping_seen[node SUBSEP key]
            delete mapping_key[node, i]
            delete mapping_child[node, i]
            delete mapping_merge[node, i]
        }
        mapping_count[node] = 0
    } else if (node_kind[node] == "sequence") {
        for (i = 1; i <= sequence_count[node]; i++) {
            delete sequence_child[node, i]
        }
        sequence_count[node] = 0
    }
    delete alias_target[node]
    delete node_anchor[node]
}

function expression_attach_missing(node,    parent, key) {
    if (!(node in expression_missing_parent) || expression_placeholder_attached[node]) {
        return
    }
    parent = expression_missing_parent[node]
    key = expression_missing_key[node]
    if (parent in expression_missing_parent) {
        if (node_kind[parent] == "scalar" && node_type[parent] == "null") {
            node_kind[parent] = "mapping"
            node_type[parent] = ""
            node_value[parent] = ""
        }
        expression_attach_missing(parent)
    }
    if (node_kind[parent] != "mapping") {
        fail("cannot create key " key " below " expression_type_name(parent))
    }
    add_mapping(parent, key, node, 0, 0)
    expression_placeholder_attached[node] = 1
}

function expression_replace_node(target, source,    clone, saved_parent, saved_edge, saved_line, saved_document, i, key, child) {
    if (resolve_alias(target) == resolve_alias(source) && !(target in expression_missing_parent)) {
        return target
    }
    clone = expression_clone_node(source)
    presentation_track_replace(target, clone)
    saved_parent = node_parent[target]
    saved_edge = node_parent_edge[target]
    saved_line = node_line[target]
    saved_document = node_document[target]
    expression_clear_node(target)
    node_kind[target] = node_kind[clone]
    node_value[target] = node_value[clone]
    node_type[target] = node_type[clone]
    node_tag[target] = node_tag[clone]
    node_line[target] = saved_line
    node_document[target] = saved_document
    node_parent[target] = saved_parent
    node_parent_edge[target] = saved_edge
    if (node_kind[clone] == "sequence") {
        for (i = 1; i <= sequence_count[clone]; i++) {
            child = sequence_child[clone, i]
            add_sequence(target, child, 0)
        }
    } else if (node_kind[clone] == "mapping") {
        for (i = 1; i <= mapping_count[clone]; i++) {
            key = mapping_key[clone, i]
            child = mapping_child[clone, i]
            add_mapping(target, key, child, 0, mapping_merge[clone, i])
        }
    }
    expression_attach_missing(target)
    return target
}

function expression_delete_node(target,    parent, i, j, key, child) {
    if (target in expression_missing_parent && !expression_placeholder_attached[target]) {
        return
    }
    if (inplace_mode) {
        presentation_track_delete(target)
    }
    parent = node_parent[target]
    if (!parent) {
        expression_clear_node(target)
        node_kind[target] = "scalar"
        node_value[target] = ""
        node_type[target] = "null"
        node_tag[target] = ""
        return
    }
    if (node_kind[parent] == "mapping") {
        for (i = 1; i <= mapping_count[parent]; i++) {
            if (mapping_child[parent, i] != target) {
                continue
            }
            key = mapping_key[parent, i]
            delete mapping_seen[parent SUBSEP key]
            for (j = i; j < mapping_count[parent]; j++) {
                mapping_key[parent, j] = mapping_key[parent, j + 1]
                mapping_child[parent, j] = mapping_child[parent, j + 1]
                mapping_merge[parent, j] = mapping_merge[parent, j + 1]
                child = mapping_child[parent, j]
                node_parent_edge[child] = "key " mapping_key[parent, j]
            }
            delete mapping_key[parent, mapping_count[parent]]
            delete mapping_child[parent, mapping_count[parent]]
            delete mapping_merge[parent, mapping_count[parent]]
            mapping_count[parent]--
            return
        }
    } else if (node_kind[parent] == "sequence") {
        for (i = 1; i <= sequence_count[parent]; i++) {
            if (sequence_child[parent, i] != target) {
                continue
            }
            for (j = i; j < sequence_count[parent]; j++) {
                sequence_child[parent, j] = sequence_child[parent, j + 1]
                child = sequence_child[parent, j]
                node_parent_edge[child] = "index " (j - 1)
            }
            delete sequence_child[parent, sequence_count[parent]]
            sequence_count[parent]--
            return
        }
    }
}

function expression_collect_recursive(node, stream, serial,    resolved, seen_key, i, collection, key) {
    resolved = resolve_alias(node)
    seen_key = serial SUBSEP resolved
    if (seen_key in expression_recursive_seen) {
        return
    }
    expression_recursive_seen[seen_key] = 1
    expression_stream_push(stream, resolved)
    if (node_kind[resolved] == "sequence") {
        for (i = 1; i <= sequence_count[resolved]; i++) {
            expression_collect_recursive(sequence_child[resolved, i], stream, serial)
        }
    } else if (node_kind[resolved] == "mapping") {
        collection = ++collection_serial
        collect_mapping_keys(resolved, collection)
        for (i = 1; i <= collection_count[collection]; i++) {
            key = collection_key[collection, i]
            expression_collect_recursive(mapping_lookup(resolved, key), stream, serial)
        }
    }
}

function expression_arithmetic_number(value, value_type, operator,    rendered) {
    rendered = sprintf("%.15g", value)
    if (value_type == "float" && rendered !~ /[.eE]/) {
        rendered = rendered ".0"
    }
    return expression_scalar(rendered, value_type)
}

function expression_deep_merge(left, right,    left_node, right_node, result, collection, i, key, child, existing, merged) {
    left_node = resolve_alias(left)
    right_node = resolve_alias(right)
    if (node_kind[left_node] != "mapping" || node_kind[right_node] != "mapping") {
        return expression_clone_node(right_node)
    }
    result = expression_clone_node(left_node)
    collection = ++collection_serial
    collect_mapping_keys(right_node, collection)
    for (i = 1; i <= collection_count[collection]; i++) {
        key = collection_key[collection, i]
        child = mapping_lookup(right_node, key)
        existing = mapping_lookup(result, key)
        if (!existing) {
            add_mapping(result, key, expression_clone_node(child), 0, 0)
        } else if (node_kind[resolve_alias(existing)] == "mapping" && node_kind[resolve_alias(child)] == "mapping") {
            merged = expression_deep_merge(existing, child)
            expression_replace_node(existing, merged)
        } else {
            expression_replace_node(existing, child)
        }
    }
    return result
}

function expression_arithmetic(left, right, operator,    left_node, right_node, left_type, right_type, result_type, value, result, i, collection, key, child) {
    left_node = resolve_alias(left)
    right_node = resolve_alias(right)
    left_type = node_type[left_node]
    right_type = node_type[right_node]

    if (operator == "+" && left_type == "null") {
        return expression_clone_node(right_node)
    }
    if (operator == "+" && right_type == "null") {
        return expression_clone_node(left_node)
    }
    if ((left_type == "int" || left_type == "float") && (right_type == "int" || right_type == "float")) {
        if (operator == "/" && expression_numeric(right_node) == 0) {
            fail("division by zero")
        }
        if (operator == "%" && expression_numeric(right_node) == 0) {
            fail("modulo by zero")
        }
        if (operator == "+") {
            value = expression_numeric(left_node) + expression_numeric(right_node)
        } else if (operator == "-") {
            value = expression_numeric(left_node) - expression_numeric(right_node)
        } else if (operator == "*") {
            value = expression_numeric(left_node) * expression_numeric(right_node)
        } else if (operator == "/") {
            value = expression_numeric(left_node) / expression_numeric(right_node)
        } else {
            value = expression_numeric(left_node) % expression_numeric(right_node)
        }
        result_type = (operator == "/" || left_type == "float" || right_type == "float") ? "float" : "int"
        return expression_arithmetic_number(value, result_type, operator)
    }
    if (operator == "+" && left_type == "string" && right_type == "string") {
        return expression_scalar(node_value[left_node] node_value[right_node], "string")
    }
    if (operator == "+" && node_kind[left_node] == "sequence" && node_kind[right_node] == "sequence") {
        result = new_node("sequence", 0, "", "", "")
        for (i = 1; i <= sequence_count[left_node]; i++) {
            add_sequence(result, expression_clone_node(sequence_child[left_node, i]), 0)
        }
        for (i = 1; i <= sequence_count[right_node]; i++) {
            add_sequence(result, expression_clone_node(sequence_child[right_node, i]), 0)
        }
        return result
    }
    if (operator == "+" && node_kind[left_node] == "mapping" && node_kind[right_node] == "mapping") {
        result = expression_clone_node(left_node)
        collection = ++collection_serial
        collect_mapping_keys(right_node, collection)
        for (i = 1; i <= collection_count[collection]; i++) {
            key = collection_key[collection, i]
            child = mapping_lookup(right_node, key)
            if (mapping_lookup(result, key)) {
                expression_replace_node(mapping_lookup(result, key), child)
            } else {
                add_mapping(result, key, expression_clone_node(child), 0, 0)
            }
        }
        return result
    }
    if (operator == "*" && node_kind[left_node] == "mapping" && node_kind[right_node] == "mapping") {
        return expression_deep_merge(left_node, right_node)
    }
    fail("operator " operator " does not support " expression_type_name(left_node) " and " expression_type_name(right_node))
}

function expression_fingerprint(node,    resolved, result, i, collection, key, child, value) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] == "scalar") {
        value = node_value[resolved]
        return "s" length(node_type[resolved]) ":" node_type[resolved] length(value) ":" value
    }
    if (node_kind[resolved] == "sequence") {
        result = "q" sequence_count[resolved] ":"
        for (i = 1; i <= sequence_count[resolved]; i++) {
            value = expression_fingerprint(sequence_child[resolved, i])
            result = result length(value) ":" value
        }
        return result
    }
    collection = ++collection_serial
    collect_mapping_keys(resolved, collection)
    result = "m" collection_count[collection] ":"
    for (i = 1; i <= collection_count[collection]; i++) {
        key = collection_key[collection, i]
        child = mapping_lookup(resolved, key)
        value = expression_fingerprint(child)
        result = result length(key) ":" key length(value) ":" value
    }
    return result
}

function expression_sort_rank(node) {
    if (node_type[node] == "null") {
        return 0
    }
    if (node_type[node] == "bool") {
        return 1
    }
    if (node_type[node] == "int" || node_type[node] == "float") {
        return 2
    }
    if (node_kind[node] == "scalar") {
        return 3
    }
    if (node_kind[node] == "sequence") {
        return 4
    }
    return 5
}

function expression_sort_less(left, right,    left_node, right_node, left_rank, right_rank, left_value, right_value) {
    left_node = resolve_alias(left)
    right_node = resolve_alias(right)
    left_rank = expression_sort_rank(left_node)
    right_rank = expression_sort_rank(right_node)
    if (left_rank != right_rank) {
        return left_rank < right_rank
    }
    if (left_rank == 2) {
        return expression_numeric(left_node) < expression_numeric(right_node)
    }
    if (left_rank <= 3) {
        left_value = tolower(node_value[left_node])
        right_value = tolower(node_value[right_node])
        return left_value < right_value
    }
    return expression_fingerprint(left_node) < expression_fingerprint(right_node)
}

function expression_flatten_into(node, target,    resolved, i) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] != "sequence") {
        add_sequence(target, expression_clone_node(resolved), 0)
        return
    }
    for (i = 1; i <= sequence_count[resolved]; i++) {
        expression_flatten_into(sequence_child[resolved, i], target)
    }
}

function expression_string_value(node,    resolved) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] != "scalar") {
        fail("string operation requires scalar values")
    }
    if (node_type[resolved] == "null") {
        return ""
    }
    return node_value[resolved]
}

function expression_split_string(value, delimiter, result,    position, found) {
    if (delimiter == "") {
        for (position = 1; position <= length(value); position++) {
            add_sequence(result, expression_scalar(substr(value, position, 1), "string"), 0)
        }
        return
    }
    while ((found = index(value, delimiter))) {
        add_sequence(result, expression_scalar(substr(value, 1, found - 1), "string"), 0)
        value = substr(value, found + length(delimiter))
    }
    add_sequence(result, expression_scalar(value, "string"), 0)
}

function expression_entry(key, value, key_type,    entry) {
    entry = new_node("mapping", 0, "", "", "")
    add_mapping(entry, "key", expression_scalar(key, key_type), 0, 0)
    add_mapping(entry, "value", expression_clone_node(value), 0, 0)
    return entry
}

function expression_evaluate(expression, input,    output, middle, left_stream, right_stream, single, kind, node, resolved, child, i, j, collection, key, predicate, matched, argument_stream, argument, result_node, variable, previous, had, accumulator, update_stream) {
    output = expression_stream_new()
    kind = expression_kind[expression]

    if (kind == "identity") {
        expression_stream_append(output, input)
        return output
    }
    if (kind == "literal") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            expression_stream_push(output, expression_scalar(expression_value[expression], expression_literal_type[expression]))
        }
        return output
    }
    if (kind == "variable") {
        variable = expression_value[expression]
        if (!(variable in expression_variable_node)) {
            fail("undefined variable $" variable)
        }
        for (i = 1; i <= expression_stream_count[input]; i++) {
            expression_stream_push(output, expression_variable_node[variable])
        }
        return output
    }
    if (kind == "array" || kind == "object") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            single = expression_stream_single(expression_stream_node[input, i])
            if (kind == "array") {
                result_node = new_node("sequence", 0, "", "", "")
                for (j = 1; j <= expression_child_count[expression]; j++) {
                    middle = expression_evaluate(expression_child[expression, j], single)
                    for (collection = 1; collection <= expression_stream_count[middle]; collection++) {
                        add_sequence(result_node, expression_clone_node(expression_stream_node[middle, collection]), 0)
                    }
                }
            } else {
                result_node = new_node("mapping", 0, "", "", "")
                for (j = 1; j <= expression_child_count[expression]; j++) {
                    middle = expression_evaluate(expression_child[expression, j], single)
                    child = expression_stream_count[middle] ? expression_stream_node[middle, 1] : expression_null()
                    add_mapping(result_node, expression_object_key[expression, j], expression_clone_node(child), 0, 0)
                }
            }
            expression_stream_push(output, result_node)
        }
        return output
    }
    if (kind == "recursive") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            expression_collect_recursive(expression_stream_node[input, i], output, ++expression_recursive_serial)
        }
        return output
    }
    if (kind == "negate") {
        middle = expression_evaluate(expression_left[expression], input)
        for (i = 1; i <= expression_stream_count[middle]; i++) {
            node = resolve_alias(expression_stream_node[middle, i])
            if (node_type[node] != "int" && node_type[node] != "float") {
                fail("unary - requires a number")
            }
            expression_stream_push(output, expression_arithmetic_number(-expression_numeric(node), node_type[node], "-"))
        }
        return output
    }
    if (kind == "arithmetic") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            single = expression_stream_single(expression_stream_node[input, i])
            left_stream = expression_evaluate(expression_left[expression], single)
            right_stream = expression_evaluate(expression_right[expression], single)
            for (j = 1; j <= expression_stream_count[left_stream]; j++) {
                for (collection = 1; collection <= expression_stream_count[right_stream]; collection++) {
                    expression_stream_push(output, expression_arithmetic(expression_stream_node[left_stream, j], expression_stream_node[right_stream, collection], expression_value[expression]))
                }
            }
        }
        return output
    }
    if (kind == "pipe") {
        middle = expression_evaluate(expression_left[expression], input)
        return expression_evaluate(expression_right[expression], middle)
    }
    if (kind == "bind") {
        variable = expression_value[expression]
        had = variable in expression_variable_node
        previous = expression_variable_node[variable]
        for (i = 1; i <= expression_stream_count[input]; i++) {
            single = expression_stream_single(expression_stream_node[input, i])
            left_stream = expression_evaluate(expression_left[expression], single)
            for (j = 1; j <= expression_stream_count[left_stream]; j++) {
                expression_variable_node[variable] = expression_stream_node[left_stream, j]
                right_stream = expression_evaluate(expression_right[expression], single)
                expression_stream_append(output, right_stream)
            }
        }
        if (had) {
            expression_variable_node[variable] = previous
        } else {
            delete expression_variable_node[variable]
        }
        return output
    }
    if (kind == "reduce") {
        variable = expression_value[expression]
        had = variable in expression_variable_node
        previous = expression_variable_node[variable]
        for (i = 1; i <= expression_stream_count[input]; i++) {
            single = expression_stream_single(expression_stream_node[input, i])
            left_stream = expression_evaluate(expression_left[expression], single)
            right_stream = expression_evaluate(expression_right[expression], single)
            accumulator = expression_stream_count[right_stream] ? expression_stream_node[right_stream, 1] : expression_null()
            for (j = 1; j <= expression_stream_count[left_stream]; j++) {
                expression_variable_node[variable] = expression_stream_node[left_stream, j]
                single = expression_stream_single(accumulator)
                update_stream = expression_evaluate(expression_child[expression, 1], single)
                accumulator = expression_stream_count[update_stream] ? expression_stream_node[update_stream, 1] : expression_null()
            }
            expression_stream_push(output, accumulator)
        }
        if (had) {
            expression_variable_node[variable] = previous
        } else {
            delete expression_variable_node[variable]
        }
        return output
    }
    if (kind == "comma") {
        middle = expression_evaluate(expression_left[expression], input)
        expression_stream_append(output, middle)
        middle = expression_evaluate(expression_right[expression], input)
        expression_stream_append(output, middle)
        return output
    }
    if (kind == "key" || kind == "index" || kind == "each") {
        middle = expression_evaluate(expression_left[expression], input)
        for (i = 1; i <= expression_stream_count[middle]; i++) {
            node = expression_stream_node[middle, i]
            resolved = resolve_alias(node)
            if (kind == "key") {
                if (node_kind[resolved] == "mapping") {
                    child = mapping_lookup(resolved, expression_value[expression])
                } else {
                    child = 0
                }
                if (child) {
                    expression_stream_push(output, child)
                } else if (!expression_optional[expression]) {
                    child = expression_null()
                    expression_missing_parent[child] = resolved
                    expression_missing_key[child] = expression_value[expression]
                    expression_stream_push(output, child)
                }
            } else if (kind == "index") {
                collection = expression_value[expression] + 0
                if (node_kind[resolved] == "sequence" && collection < 0) {
                    collection = sequence_count[resolved] + collection
                }
                if (node_kind[resolved] == "sequence" && collection >= 0 && collection < sequence_count[resolved]) {
                    child = sequence_child[resolved, collection + 1]
                } else {
                    child = 0
                }
                if (child) {
                    expression_stream_push(output, child)
                } else if (!expression_optional[expression]) {
                    expression_stream_push(output, expression_null())
                }
            } else if (node_kind[resolved] == "sequence") {
                for (j = 1; j <= sequence_count[resolved]; j++) {
                    expression_stream_push(output, sequence_child[resolved, j])
                }
            } else if (node_kind[resolved] == "mapping") {
                collection = ++collection_serial
                collect_mapping_keys(resolved, collection)
                for (j = 1; j <= collection_count[collection]; j++) {
                    key = collection_key[collection, j]
                    expression_stream_push(output, mapping_lookup(resolved, key))
                }
            } else {
                if (expression_optional[expression]) {
                    continue
                }
                if (node_kind[resolved] == "scalar") {
                    fail("cannot iterate over " node_type[resolved])
                }
                fail("cannot iterate over " node_kind[resolved])
            }
        }
        return output
    }
    if (kind == "dynamic") {
        middle = expression_evaluate(expression_left[expression], input)
        for (i = 1; i <= expression_stream_count[middle]; i++) {
            node = expression_stream_node[middle, i]
            resolved = resolve_alias(node)
            single = expression_stream_single(resolved)
            argument_stream = expression_evaluate(expression_right[expression], single)
            for (j = 1; j <= expression_stream_count[argument_stream]; j++) {
                argument = resolve_alias(expression_stream_node[argument_stream, j])
                if (node_kind[argument] != "scalar") {
                    fail("dynamic indexes require a scalar key or index")
                }
                if (node_kind[resolved] == "sequence" && node_type[argument] == "int") {
                    collection = node_value[argument] + 0
                    if (collection < 0) {
                        collection = sequence_count[resolved] + collection
                    }
                    if (collection >= 0 && collection < sequence_count[resolved]) {
                        expression_stream_push(output, sequence_child[resolved, collection + 1])
                    } else if (!expression_optional[expression]) {
                        expression_stream_push(output, expression_null())
                    }
                } else if (node_kind[resolved] == "mapping") {
                    key = node_value[argument]
                    child = mapping_lookup(resolved, key)
                    if (child) {
                        expression_stream_push(output, child)
                    } else if (!expression_optional[expression]) {
                        child = expression_null()
                        expression_missing_parent[child] = resolved
                        expression_missing_key[child] = key
                        expression_stream_push(output, child)
                    }
                } else if (!expression_optional[expression]) {
                    fail("dynamic indexing requires a mapping or sequence")
                }
            }
        }
        return output
    }
    if (kind == "assign" || kind == "update") {
        left_stream = expression_evaluate(expression_left[expression], input)
        if (kind == "assign") {
            right_stream = expression_evaluate(expression_right[expression], input)
            if (!expression_stream_count[right_stream]) {
                expression_stream_push(right_stream, expression_null())
            }
            for (i = 1; i <= expression_stream_count[left_stream]; i++) {
                j = expression_stream_count[right_stream] == expression_stream_count[left_stream] ? i : 1
                expression_replace_node(expression_stream_node[left_stream, i], expression_stream_node[right_stream, j])
            }
        } else {
            for (i = 1; i <= expression_stream_count[left_stream]; i++) {
                node = expression_stream_node[left_stream, i]
                single = expression_stream_single(node)
                right_stream = expression_evaluate(expression_right[expression], single)
                child = expression_stream_count[right_stream] ? expression_stream_node[right_stream, 1] : expression_null()
                expression_replace_node(node, child)
            }
        }
        expression_stream_append(output, input)
        return output
    }
    if (kind == "del") {
        middle = expression_evaluate(expression_left[expression], input)
        for (i = expression_stream_count[middle]; i >= 1; i--) {
            expression_delete_node(expression_stream_node[middle, i])
        }
        expression_stream_append(output, input)
        return output
    }
    if (kind == "select") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = expression_stream_node[input, i]
            single = expression_stream_single(node)
            predicate = expression_evaluate(expression_left[expression], single)
            matched = 0
            for (j = 1; j <= expression_stream_count[predicate]; j++) {
                if (expression_truthy(expression_stream_node[predicate, j])) {
                    matched = 1
                    break
                }
            }
            if (matched) {
                expression_stream_push(output, node)
            }
        }
        return output
    }
    if (kind == "compare" || kind == "and" || kind == "or") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            single = expression_stream_single(expression_stream_node[input, i])
            left_stream = expression_evaluate(expression_left[expression], single)
            right_stream = expression_evaluate(expression_right[expression], single)
            for (j = 1; j <= expression_stream_count[left_stream]; j++) {
                for (collection = 1; collection <= expression_stream_count[right_stream]; collection++) {
                    node = expression_stream_node[left_stream, j]
                    child = expression_stream_node[right_stream, collection]
                    if (kind == "compare") {
                        matched = expression_compare(node, child, expression_value[expression])
                    } else if (kind == "and") {
                        matched = expression_truthy(node) && expression_truthy(child)
                    } else {
                        matched = expression_truthy(node) || expression_truthy(child)
                    }
                    expression_stream_push(output, expression_boolean(matched))
                }
            }
        }
        return output
    }
    if (kind == "not") {
        middle = expression_evaluate(expression_left[expression], input)
        for (i = 1; i <= expression_stream_count[middle]; i++) {
            expression_stream_push(output, expression_boolean(!expression_truthy(expression_stream_node[middle, i])))
        }
        return output
    }
    if (kind == "alternative") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            single = expression_stream_single(expression_stream_node[input, i])
            left_stream = expression_evaluate(expression_left[expression], single)
            matched = 0
            for (j = 1; j <= expression_stream_count[left_stream]; j++) {
                node = expression_stream_node[left_stream, j]
                if (expression_truthy(node)) {
                    expression_stream_push(output, node)
                    matched = 1
                }
            }
            if (!matched) {
                right_stream = expression_evaluate(expression_right[expression], single)
                expression_stream_append(output, right_stream)
            }
        }
        return output
    }
    if (kind == "map" || kind == "map_values") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = expression_stream_node[input, i]
            resolved = resolve_alias(node)
            if (node_kind[resolved] != "sequence" && node_kind[resolved] != "mapping") {
                fail(kind " requires a sequence or mapping")
            }
            result_node = new_node(kind == "map" ? "sequence" : node_kind[resolved], 0, "", "", "")
            if (node_kind[resolved] == "sequence") {
                for (j = 1; j <= sequence_count[resolved]; j++) {
                    single = expression_stream_single(sequence_child[resolved, j])
                    argument_stream = expression_evaluate(expression_left[expression], single)
                    for (collection = 1; collection <= expression_stream_count[argument_stream]; collection++) {
                        add_sequence(result_node, expression_clone_node(expression_stream_node[argument_stream, collection]), 0)
                    }
                }
            } else {
                collection = ++collection_serial
                collect_mapping_keys(resolved, collection)
                for (j = 1; j <= collection_count[collection]; j++) {
                    key = collection_key[collection, j]
                    single = expression_stream_single(mapping_lookup(resolved, key))
                    argument_stream = expression_evaluate(expression_left[expression], single)
                    if (kind == "map") {
                        for (matched = 1; matched <= expression_stream_count[argument_stream]; matched++) {
                            add_sequence(result_node, expression_clone_node(expression_stream_node[argument_stream, matched]), 0)
                        }
                    } else if (expression_stream_count[argument_stream]) {
                        add_mapping(result_node, key, expression_clone_node(expression_stream_node[argument_stream, 1]), 0, 0)
                    }
                }
            }
            expression_stream_push(output, result_node)
        }
        return output
    }
    if (kind == "to_entries" || kind == "from_entries" || kind == "with_entries") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            if (kind == "to_entries") {
                result_node = new_node("sequence", 0, "", "", "")
                if (node_kind[node] == "mapping") {
                    collection = ++collection_serial
                    collect_mapping_keys(node, collection)
                    for (j = 1; j <= collection_count[collection]; j++) {
                        key = collection_key[collection, j]
                        add_sequence(result_node, expression_entry(key, mapping_lookup(node, key), "string"), 0)
                    }
                } else if (node_kind[node] == "sequence") {
                    for (j = 1; j <= sequence_count[node]; j++) {
                        add_sequence(result_node, expression_entry((j - 1) "", sequence_child[node, j], "int"), 0)
                    }
                } else {
                    fail("to_entries requires a mapping or sequence")
                }
                expression_stream_push(output, result_node)
                continue
            }
            if (kind == "with_entries") {
                if (node_kind[node] != "mapping" && node_kind[node] != "sequence") {
                    fail("with_entries requires a mapping or sequence")
                }
                middle = expression_stream_new()
                if (node_kind[node] == "mapping") {
                    collection = ++collection_serial
                    collect_mapping_keys(node, collection)
                    for (j = 1; j <= collection_count[collection]; j++) {
                        key = collection_key[collection, j]
                        single = expression_stream_single(expression_entry(key, mapping_lookup(node, key), "string"))
                        argument_stream = expression_evaluate(expression_left[expression], single)
                        expression_stream_append(middle, argument_stream)
                    }
                } else {
                    for (j = 1; j <= sequence_count[node]; j++) {
                        single = expression_stream_single(expression_entry((j - 1) "", sequence_child[node, j], "int"))
                        argument_stream = expression_evaluate(expression_left[expression], single)
                        expression_stream_append(middle, argument_stream)
                    }
                }
            } else {
                if (node_kind[node] != "sequence") {
                    fail("from_entries requires a sequence")
                }
                middle = expression_stream_new()
                for (j = 1; j <= sequence_count[node]; j++) {
                    expression_stream_push(middle, sequence_child[node, j])
                }
            }
            result_node = new_node("mapping", 0, "", "", "")
            for (j = 1; j <= expression_stream_count[middle]; j++) {
                child = resolve_alias(expression_stream_node[middle, j])
                if (node_kind[child] != "mapping" || !mapping_lookup(child, "key") || !mapping_lookup(child, "value")) {
                    fail(kind " requires entries containing key and value")
                }
                key = expression_string_value(mapping_lookup(child, "key"))
                if (mapping_lookup(result_node, key)) {
                    expression_replace_node(mapping_lookup(result_node, key), mapping_lookup(child, "value"))
                } else {
                    add_mapping(result_node, key, expression_clone_node(mapping_lookup(child, "value")), 0, 0)
                }
            }
            expression_stream_push(output, result_node)
        }
        return output
    }
    if (kind == "sort" || kind == "unique" || kind == "reverse" || kind == "flatten") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            if (node_kind[node] != "sequence") {
                fail(kind " requires a sequence")
            }
            result_node = new_node("sequence", 0, "", "", "")
            if (kind == "flatten") {
                expression_flatten_into(node, result_node)
            } else if (kind == "reverse") {
                for (j = sequence_count[node]; j >= 1; j--) {
                    add_sequence(result_node, expression_clone_node(sequence_child[node, j]), 0)
                }
            } else if (kind == "unique") {
                middle = ++expression_sort_serial
                for (j = 1; j <= sequence_count[node]; j++) {
                    child = sequence_child[node, j]
                    key = middle SUBSEP expression_fingerprint(child)
                    if (!(key in expression_unique_seen)) {
                        expression_unique_seen[key] = 1
                        add_sequence(result_node, expression_clone_node(child), 0)
                    }
                }
            } else {
                middle = ++expression_sort_serial
                matched = 0
                for (j = 1; j <= sequence_count[node]; j++) {
                    child = sequence_child[node, j]
                    collection = ++matched
                    while (collection > 1 && expression_sort_less(child, expression_sort_node[middle, collection - 1])) {
                        expression_sort_node[middle, collection] = expression_sort_node[middle, collection - 1]
                        collection--
                    }
                    expression_sort_node[middle, collection] = child
                }
                for (j = 1; j <= matched; j++) {
                    add_sequence(result_node, expression_clone_node(expression_sort_node[middle, j]), 0)
                }
            }
            expression_stream_push(output, result_node)
        }
        return output
    }
    if (kind == "min_by" || kind == "max_by") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            if (node_kind[node] != "sequence") {
                fail(kind " requires a sequence")
            }
            child = 0
            argument = 0
            for (j = 1; j <= sequence_count[node]; j++) {
                result_node = sequence_child[node, j]
                single = expression_stream_single(result_node)
                argument_stream = expression_evaluate(expression_left[expression], single)
                key = expression_stream_count[argument_stream] ? expression_stream_node[argument_stream, 1] : expression_null()
                if (!child || (kind == "min_by" && expression_sort_less(key, argument)) ||
                    (kind == "max_by" && expression_sort_less(argument, key))) {
                    child = result_node
                    argument = key
                }
            }
            if (child) {
                expression_stream_push(output, expression_clone_node(child))
            }
        }
        return output
    }
    if (kind == "sort_by" || kind == "group_by" || kind == "unique_by") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            if (node_kind[node] != "sequence") {
                fail(kind " requires a sequence")
            }
            result_node = new_node("sequence", 0, "", "", "")
            middle = ++expression_sort_serial
            matched = 0
            for (j = 1; j <= sequence_count[node]; j++) {
                child = sequence_child[node, j]
                single = expression_stream_single(child)
                argument_stream = expression_evaluate(expression_left[expression], single)
                argument = expression_stream_count[argument_stream] ? expression_stream_node[argument_stream, 1] : expression_null()
                if (kind == "unique_by") {
                    key = middle SUBSEP expression_fingerprint(argument)
                    if (!(key in expression_unique_seen)) {
                        expression_unique_seen[key] = 1
                        add_sequence(result_node, expression_clone_node(child), 0)
                    }
                } else if (kind == "group_by") {
                    key = middle SUBSEP expression_fingerprint(argument)
                    collection = expression_group_index[key]
                    if (!collection) {
                        collection = ++matched
                        expression_group_index[key] = collection
                        expression_sort_node[middle, collection] = new_node("sequence", 0, "", "", "")
                        add_sequence(result_node, expression_sort_node[middle, collection], 0)
                    }
                    add_sequence(expression_sort_node[middle, collection], expression_clone_node(child), 0)
                } else {
                    collection = ++matched
                    while (collection > 1 && expression_sort_less(argument, expression_sort_key[middle, collection - 1])) {
                        expression_sort_key[middle, collection] = expression_sort_key[middle, collection - 1]
                        expression_sort_node[middle, collection] = expression_sort_node[middle, collection - 1]
                        collection--
                    }
                    expression_sort_key[middle, collection] = argument
                    expression_sort_node[middle, collection] = child
                }
            }
            if (kind == "sort_by") {
                for (j = 1; j <= matched; j++) {
                    add_sequence(result_node, expression_clone_node(expression_sort_node[middle, j]), 0)
                }
            }
            expression_stream_push(output, result_node)
        }
        return output
    }
    if (kind == "add") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            if (node_kind[node] != "sequence") {
                fail("add requires a sequence")
            }
            if (!sequence_count[node]) {
                expression_stream_push(output, expression_null())
                continue
            }
            child = expression_clone_node(sequence_child[node, 1])
            for (j = 2; j <= sequence_count[node]; j++) {
                child = expression_arithmetic(child, sequence_child[node, j], "+")
            }
            expression_stream_push(output, child)
        }
        return output
    }
    if (kind == "min" || kind == "max" || kind == "any" || kind == "all" || kind == "any_c" || kind == "all_c") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            if (node_kind[node] != "sequence") {
                fail(kind " requires a sequence")
            }
            if (kind == "min" || kind == "max") {
                if (!sequence_count[node]) {
                    continue
                }
                child = sequence_child[node, 1]
                for (j = 2; j <= sequence_count[node]; j++) {
                    argument = sequence_child[node, j]
                    if ((kind == "min" && expression_sort_less(argument, child)) ||
                        (kind == "max" && expression_sort_less(child, argument))) {
                        child = argument
                    }
                }
                expression_stream_push(output, expression_clone_node(child))
                continue
            }
            matched = kind == "all" || kind == "all_c"
            for (j = 1; j <= sequence_count[node]; j++) {
                child = sequence_child[node, j]
                if (kind == "any_c" || kind == "all_c") {
                    single = expression_stream_single(child)
                    argument_stream = expression_evaluate(expression_left[expression], single)
                    predicate = 0
                    for (collection = 1; collection <= expression_stream_count[argument_stream]; collection++) {
                        if (expression_truthy(expression_stream_node[argument_stream, collection])) {
                            predicate = 1
                        }
                    }
                } else {
                    predicate = expression_truthy(child)
                }
                if ((kind == "any" || kind == "any_c") && predicate) {
                    matched = 1
                    break
                }
                if ((kind == "all" || kind == "all_c") && !predicate) {
                    matched = 0
                    break
                }
            }
            expression_stream_push(output, expression_boolean(matched))
        }
        return output
    }
    if (kind == "upcase" || kind == "downcase") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            if (node_kind[node] != "scalar" || node_type[node] != "string") {
                fail(kind " requires a string")
            }
            expression_stream_push(output, expression_scalar(kind == "upcase" ? toupper(node_value[node]) : tolower(node_value[node]), "string"))
        }
        return output
    }
    if (kind == "contains" || kind == "startswith" || kind == "endswith" || kind == "split" || kind == "join") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            single = expression_stream_single(node)
            argument_stream = expression_evaluate(expression_left[expression], single)
            if (!expression_stream_count[argument_stream]) {
                fail(kind " requires an argument")
            }
            argument = expression_string_value(expression_stream_node[argument_stream, 1])
            if (kind == "join") {
                if (node_kind[node] != "sequence") {
                    fail("join requires a sequence")
                }
                key = ""
                for (j = 1; j <= sequence_count[node]; j++) {
                    if (j > 1) {
                        key = key argument
                    }
                    key = key expression_string_value(sequence_child[node, j])
                }
                expression_stream_push(output, expression_scalar(key, "string"))
                continue
            }
            if (node_kind[node] != "scalar" || node_type[node] != "string") {
                fail(kind " requires a string")
            }
            key = node_value[node]
            if (kind == "contains") {
                expression_stream_push(output, expression_boolean(index(key, argument) > 0))
            } else if (kind == "startswith") {
                expression_stream_push(output, expression_boolean(substr(key, 1, length(argument)) == argument))
            } else if (kind == "endswith") {
                expression_stream_push(output, expression_boolean(substr(key, length(key) - length(argument) + 1) == argument))
            } else {
                result_node = new_node("sequence", 0, "", "", "")
                expression_split_string(key, argument, result_node)
                expression_stream_push(output, result_node)
            }
        }
        return output
    }
    if (kind == "length" || kind == "keys" || kind == "kind" || kind == "type" || kind == "has") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = expression_stream_node[input, i]
            resolved = resolve_alias(node)
            if (kind == "length") {
                if (node_kind[resolved] == "mapping") {
                    matched = expression_mapping_length(resolved)
                } else if (node_kind[resolved] == "sequence") {
                    matched = sequence_count[resolved]
                } else if (node_type[resolved] == "null") {
                    matched = 0
                } else {
                    matched = length(node_value[resolved])
                }
                expression_stream_push(output, expression_scalar(matched "", "int"))
            } else if (kind == "kind") {
                expression_stream_push(output, expression_scalar(expression_kind_name(resolved), "string"))
            } else if (kind == "type") {
                expression_stream_push(output, expression_scalar(expression_type_name(resolved), "string"))
            } else if (kind == "keys") {
                result_node = new_node("sequence", 0, "", "", "")
                if (node_kind[resolved] == "mapping") {
                    collection = ++collection_serial
                    collect_mapping_keys(resolved, collection)
                    for (j = 1; j <= collection_count[collection]; j++) {
                        add_sequence(result_node, expression_scalar(collection_key[collection, j], "string"), 0)
                    }
                } else if (node_kind[resolved] == "sequence") {
                    for (j = 0; j < sequence_count[resolved]; j++) {
                        add_sequence(result_node, expression_scalar(j "", "int"), 0)
                    }
                } else {
                    fail("keys requires a mapping or sequence")
                }
                expression_stream_push(output, result_node)
            } else {
                single = expression_stream_single(node)
                argument_stream = expression_evaluate(expression_left[expression], single)
                if (expression_stream_count[argument_stream] < 1) {
                    expression_stream_push(output, expression_boolean(0))
                    continue
                }
                argument = resolve_alias(expression_stream_node[argument_stream, 1])
                if (node_kind[argument] != "scalar") {
                    fail("has requires a scalar key or index")
                }
                if (node_kind[resolved] == "mapping") {
                    matched = mapping_lookup(resolved, node_value[argument]) != 0
                } else if (node_kind[resolved] == "sequence" && node_type[argument] == "int") {
                    matched = (node_value[argument] + 0) >= 0 && (node_value[argument] + 0) < sequence_count[resolved]
                } else {
                    matched = 0
                }
                expression_stream_push(output, expression_boolean(matched))
            }
        }
        return output
    }
    fail("cannot evaluate expression kind " kind)
}

function base_integer(value, base,    result, i, char, digit) {
    result = 0
    for (i = 1; i <= length(value); i++) {
        char = substr(value, i, 1)
        if (char >= "0" && char <= "9") {
            digit = char + 0
        } else {
            digit = index("abcdef", tolower(char)) + 9
        }
        result = result * base + digit
    }
    return sprintf("%.0f", result)
}

function json_integer(value,    sign, body) {
    gsub(/_/, "", value)
    sign = ""
    if (substr(value, 1, 1) == "-" || substr(value, 1, 1) == "+") {
        sign = substr(value, 1, 1)
        value = substr(value, 2)
    }
    if (sign == "+") {
        sign = ""
    }
    if (substr(value, 1, 2) == "0b") {
        body = base_integer(substr(value, 3), 2)
    } else if (substr(value, 1, 2) == "0o") {
        body = base_integer(substr(value, 3), 8)
    } else if (substr(value, 1, 2) == "0x") {
        body = base_integer(substr(value, 3), 16)
    } else {
        body = value
    }
    return sign body
}

function json_float(value,    lowered) {
    gsub(/_/, "", value)
    lowered = tolower(value)
    if (lowered ~ /\.(inf|nan)$/) {
        return json_quote(value)
    }
    if (substr(value, 1, 1) == "+") {
        value = substr(value, 2)
    }
    if (substr(value, 1, 1) == ".") {
        value = "0" value
    } else if (substr(value, 1, 2) == "-.") {
        value = "-0" substr(value, 2)
    }
    if (value ~ /\.$/) {
        value = value "0"
    }
    if (value !~ /[eE]/ && value ~ /\.([0-9_]*00)$/) {
        sub(/0+$/, "", value)
        sub(/\.$/, "", value)
    }
    return value
}

function emit_json(node,    resolved, stack_key, i, collection, key, child, lowered) {
    resolved = resolve_alias(node)
    stack_key = resolved
    if ((node_kind[resolved] == "mapping" || node_kind[resolved] == "sequence") && (stack_key in json_stack)) {
        fail("cyclic graph cannot be emitted as JSON")
    }

    if (node_kind[resolved] == "scalar") {
        if (node_type[resolved] == "null") {
            printf "null"
        } else if (node_type[resolved] == "bool") {
            lowered = tolower(node_value[resolved])
            if (lowered == "true" || lowered == "false") {
                printf "%s", lowered
            } else {
                printf "%s", json_quote(node_value[resolved])
            }
        } else if (node_type[resolved] == "int" && node_value[resolved] ~ /^[-+]?(0|[1-9][0-9_]*|0b[01_]+|0o[0-7_]+|0x[0-9a-fA-F_]+)$/) {
            printf "%s", json_integer(node_value[resolved])
        } else if (node_type[resolved] == "float") {
            printf "%s", json_float(node_value[resolved])
        } else {
            printf "%s", json_quote(node_value[resolved])
        }
        return
    }

    json_stack[stack_key] = 1
    if (node_kind[resolved] == "sequence") {
        printf "["
        for (i = 1; i <= sequence_count[resolved]; i++) {
            if (i > 1) {
                printf ","
            }
            emit_json(sequence_child[resolved, i])
        }
        printf "]"
    } else if (node_kind[resolved] == "mapping") {
        collection = ++collection_serial
        collect_mapping_keys(resolved, collection)
        printf "{"
        for (i = 1; i <= collection_count[collection]; i++) {
            if (i > 1) {
                printf ","
            }
            key = collection_key[collection, i]
            child = mapping_lookup(resolved, key)
            printf "%s:", json_quote(key)
            emit_json(child)
        }
        printf "}"
    } else {
        fail("cannot emit node kind " node_kind[resolved])
    }
    delete json_stack[stack_key]
}

function yaml_spaces(indent,    result, i) {
    result = ""
    for (i = 0; i < indent; i++) {
        result = result " "
    }
    return result
}

function yaml_properties(node,    result, tag) {
    result = ""
    tag = node_tag[node]
    if (tag != "") {
        if (tag ~ /^tag:yaml.org,2002:/) {
            tag = "!!" substr(tag, length("tag:yaml.org,2002:") + 1)
        } else {
            tag = "!<" tag ">"
        }
        result = tag
    }
    if (node_anchor[node] != "") {
        if (result != "") {
            result = result " "
        }
        result = result "&" node_anchor[node]
    }
    return result
}

function yaml_scalar_text(node,    value, properties, lowered) {
    if (node_kind[node] == "alias") {
        return "*" node_value[node]
    }
    properties = yaml_properties(node)
    if (properties != "") {
        properties = properties " "
    }
    value = node_value[node]
    if (node_type[node] == "null") {
        return properties "null"
    }
    if (node_type[node] == "bool") {
        lowered = tolower(value)
        if (lowered == "true" || lowered == "false") {
            return properties lowered
        }
    }
    if (node_type[node] == "int" || node_type[node] == "float" || node_type[node] == "timestamp") {
        return properties value
    }
    return properties json_quote(value)
}

function yaml_inline_node(node,    properties) {
    if (node_kind[node] == "scalar" || node_kind[node] == "alias") {
        return yaml_scalar_text(node)
    }
    properties = yaml_properties(node)
    if (properties != "") {
        properties = properties " "
    }
    if (node_kind[node] == "mapping" && mapping_count[node] == 0) {
        return properties "{}"
    }
    if (node_kind[node] == "sequence" && sequence_count[node] == 0) {
        return properties "[]"
    }
    return ""
}

function emit_yaml_collection(node, indent,    i, child, inline, properties, key) {
    if (node_kind[node] == "mapping") {
        for (i = 1; i <= mapping_count[node]; i++) {
            key = mapping_key[node, i]
            if (mapping_merge[node, i]) {
                printf "%s<<:", yaml_spaces(indent)
            } else {
                printf "%s%s:", yaml_spaces(indent), json_quote(key)
            }
            child = mapping_child[node, i]
            inline = yaml_inline_node(child)
            if (inline != "") {
                printf " %s\n", inline
            } else {
                properties = yaml_properties(child)
                if (properties != "") {
                    printf " %s", properties
                }
                printf "\n"
                emit_yaml_collection(child, indent + 2)
            }
        }
        return
    }
    for (i = 1; i <= sequence_count[node]; i++) {
        child = sequence_child[node, i]
        printf "%s-", yaml_spaces(indent)
        inline = yaml_inline_node(child)
        if (inline != "") {
            printf " %s\n", inline
        } else {
            properties = yaml_properties(child)
            if (properties != "") {
                printf " %s", properties
            }
            printf "\n"
            emit_yaml_collection(child, indent + 2)
        }
    }
}

function emit_yaml(node,    inline, properties) {
    inline = yaml_inline_node(node)
    if (inline != "") {
        print inline
        return
    }
    properties = yaml_properties(node)
    if (properties != "") {
        print properties
    }
    emit_yaml_collection(node, 0)
}

function presentation_comment_position(value,    i, char, previous, quote, escaped, braces, brackets) {
    quote = ""
    escaped = 0
    braces = 0
    brackets = 0
    for (i = 1; i <= length(value); i++) {
        char = substr(value, i, 1)
        previous = i > 1 ? substr(value, i - 1, 1) : ""
        if (quote != "") {
            if (escaped) {
                escaped = 0
            } else if (quote == "\"" && char == "\\") {
                escaped = 1
            } else if (char == quote) {
                quote = ""
            }
            continue
        }
        if (char == "\"" || char == sprintf("%c", 39)) {
            quote = char
        } else if (char == "{") {
            braces++
        } else if (char == "}") {
            braces--
        } else if (char == "[") {
            brackets++
        } else if (char == "]") {
            brackets--
        } else if (char == "#" && braces == 0 && brackets == 0 && (i == 1 || previous ~ /[[:space:]]/)) {
            return i
        }
    }
    return 0
}

function presentation_plain_safe(value,    lowered, i) {
    lowered = tolower(value)
    if (value == "" || value ~ /^[[:space:]]/ || value ~ /[[:space:]]$/) {
        return 0
    }
    for (i = 1; i <= length(value); i++) {
        if (index(":#[]{},&*!|>@`", substr(value, i, 1))) {
            return 0
        }
    }
    if (lowered == "null" || lowered == "true" || lowered == "false" || value == "~") {
        return 0
    }
    if (scalar_type(value, "", value) != "string") {
        return 0
    }
    return 1
}

function presentation_scalar_text(node, original,    quote, value) {
    value = node_value[node]
    if (node_type[node] != "string") {
        return yaml_scalar_text(node)
    }
    original = trim(original)
    quote = sprintf("%c", 39)
    if (substr(original, 1, 1) == quote && substr(original, length(original), 1) == quote) {
        gsub(quote, quote quote, value)
        return quote value quote
    }
    if (substr(original, 1, 1) == "\"") {
        return json_quote(value)
    }
    if (presentation_plain_safe(value)) {
        return value
    }
    return json_quote(value)
}

function presentation_attached_start(child, lower_bound,    line, raw, indent) {
    line = node_line[child]
    indent = indentation(raw_input_line[line], line)
    while (line > lower_bound) {
        raw = raw_input_line[line - 1]
        if (trim(raw) == "") {
            line--
            continue
        }
        if (trim(raw) ~ /^#/ && indentation(raw, line - 1) >= indent) {
            line--
            continue
        }
        break
    }
    return line
}

function presentation_track_sequence_reorder(target, source,    parent, header, raw, text, target_end, serial, i, j, child, origin, found, lower, start, previous_end) {
    if (node_kind[target] != "sequence" || node_kind[source] != "sequence" ||
        sequence_count[target] == 0 || sequence_count[target] != sequence_count[source]) {
        return 0
    }
    parent = node_parent[target]
    header = node_line[target]
    if (!parent || node_kind[parent] != "mapping" || header < 1 || header in presentation_line_node ||
        header in presentation_deleted_line || header in presentation_reorder_count) {
        return 0
    }
    raw = raw_input_line[header]
    text = substr(raw, indentation(raw, header) + 1)
    if (!find_mapping_separator(text, 1) || text ~ /[\[{].*[\]}]/) {
        return 0
    }

    serial = ++presentation_reorder_serial
    lower = header + 1
    previous_end = header
    for (i = 1; i <= sequence_count[target]; i++) {
        child = sequence_child[target, i]
        if (node_line[child] <= header) {
            return 0
        }
        lower = previous_end + 1
        start = presentation_attached_start(child, lower)
        presentation_original_start[serial, child] = start
        previous_end = presentation_span_end(child)
    }
    target_end = presentation_span_end(target)
    for (i = 1; i <= sequence_count[source]; i++) {
        child = sequence_child[source, i]
        origin = node_origin[child]
        found = 0
        for (j = 1; j <= sequence_count[target]; j++) {
            if (sequence_child[target, j] == origin && !(serial SUBSEP origin in presentation_reorder_seen)) {
                found = 1
                presentation_reorder_seen[serial, origin] = 1
                break
            }
        }
        if (!found) {
            return 0
        }
        presentation_reorder_start[header, i] = presentation_original_start[serial, origin]
        for (j = 1; j <= sequence_count[target]; j++) {
            if (sequence_child[target, j] == origin) {
                if (j < sequence_count[target]) {
                    presentation_reorder_end[header, i] = presentation_original_start[serial, sequence_child[target, j + 1]] - 1
                } else {
                    presentation_reorder_end[header, i] = target_end
                }
                break
            }
        }
    }
    presentation_reorder_count[header] = sequence_count[source]
    for (i = header + 1; i <= target_end; i++) {
        presentation_deleted_line[i] = 1
    }
    return 1
}

function presentation_track_replace(target, source,    line, raw, resolved_source) {
    if (!inplace_mode || !presentation_possible) {
        return
    }
    resolved_source = resolve_alias(source)
    if (node_kind[target] == "sequence" && node_kind[resolved_source] == "sequence") {
        if (presentation_track_sequence_reorder(target, resolved_source)) {
            return
        }
        presentation_possible = 0
        return
    }
    if ((target in expression_missing_parent) && !expression_placeholder_attached[target]) {
        presentation_track_insert(target)
        return
    }
    line = node_line[target]
    raw = raw_input_line[line]
    if (line < 1 || node_kind[target] != "scalar" || node_kind[resolved_source] != "scalar" ||
        raw ~ /(^|:[[:space:]]*)[|>][+-]?[[:space:]]*(#|$)/ || raw ~ /[\[{].*[\]}]/ || raw ~ /:[[:space:]]*[!&]/) {
        presentation_possible = 0
        return
    }
    if ((line in presentation_line_node) && presentation_line_node[line] != target) {
        presentation_possible = 0
        return
    }
    presentation_line_node[line] = target
}

function presentation_track_insert(target,    parent, key, i, child, first_line, after, end, indent, raw) {
    parent = expression_missing_parent[target]
    key = expression_missing_key[target]
    if (!parent || (parent in expression_missing_parent) || node_kind[parent] != "mapping" || mapping_count[parent] == 0) {
        presentation_possible = 0
        return
    }
    first_line = 0
    after = 0
    for (i = 1; i <= mapping_count[parent]; i++) {
        child = mapping_child[parent, i]
        if (node_line[child] < 1) {
            continue
        }
        if (!first_line) {
            first_line = node_line[child]
        }
        end = presentation_span_end(child)
        if (end > after) {
            after = end
        }
    }
    if (!first_line || !after) {
        presentation_possible = 0
        return
    }
    raw = raw_input_line[first_line]
    if (raw ~ /[\[{].*[\]}]/) {
        presentation_possible = 0
        return
    }
    indent = indentation(raw, first_line)
    i = ++presentation_insert_count[after]
    presentation_insert_node[after, i] = target
    presentation_insert_key[after, i] = key
    presentation_insert_indent[after, i] = indent
}

function presentation_span_end(target,    start, start_indent, line, raw, raw_indent, end) {
    start = node_line[target]
    start_indent = indentation(raw_input_line[start], start)
    end = start
    for (line = start + 1; line <= NR; line++) {
        raw = raw_input_line[line]
        sub(/\r$/, "", raw)
        if (trim(raw) == "") {
            continue
        }
        raw_indent = indentation(raw, line)
        if (trim(raw) ~ /^#/ && raw_indent <= start_indent) {
            break
        }
        if (raw_indent <= start_indent || trim(raw) == "---" || trim(raw) == "...") {
            break
        }
        end = line
    }
    return end
}

function presentation_track_delete(target,    parent, line, end, raw, indent, text, i, sibling) {
    if (!inplace_mode || !presentation_possible) {
        return
    }
    parent = node_parent[target]
    line = node_line[target]
    if (!parent || line < 1 || line in presentation_line_node) {
        presentation_possible = 0
        return
    }
    raw = raw_input_line[line]
    indent = indentation(raw, line)
    text = substr(raw, indent + 1)
    if ((text ~ /^-[[:space:]]+/ && find_top_level_colon(text, 1)) || text ~ /[\[{].*[\]}]/) {
        presentation_possible = 0
        return
    }
    if (node_kind[parent] == "mapping") {
        for (i = 1; i <= mapping_count[parent]; i++) {
            sibling = mapping_child[parent, i]
            if (sibling != target && node_line[sibling] == line) {
                presentation_possible = 0
                return
            }
        }
    } else if (node_kind[parent] == "sequence") {
        for (i = 1; i <= sequence_count[parent]; i++) {
            sibling = sequence_child[parent, i]
            if (sibling != target && node_line[sibling] == line) {
                presentation_possible = 0
                return
            }
        }
    } else {
        presentation_possible = 0
        return
    }
    end = presentation_span_end(target)
    for (i = line; i <= end; i++) {
        presentation_deleted_line[i] = 1
    }
}

function emit_presented_line(line, node,    raw, indent, text, separator, rest, prefix, leading, comment_at, token, suffix, body, trailing) {
    raw = raw_input_line[line]
    sub(/\r$/, "", raw)
    indent = indentation(raw, line)
    text = substr(raw, indent + 1)
    separator = find_top_level_colon(text, 1)
    if (separator) {
        prefix = substr(raw, 1, indent + separator)
        rest = substr(text, separator + 1)
    } else if (text == "-" || text ~ /^-[[:space:]]/) {
        prefix = substr(raw, 1, indent + 1)
        rest = substr(text, 2)
    } else {
        prefix = substr(raw, 1, indent)
        rest = text
    }
    leading = rest
    sub(/[^ ].*$/, "", leading)
    comment_at = presentation_comment_position(rest)
    if (comment_at) {
        token = trim(substr(rest, 1, comment_at - 1))
        body = substr(rest, length(leading) + 1, comment_at - length(leading) - 1)
        trailing = body
        sub(/^.*[^ ]/, "", trailing)
        if (trailing == "") {
            trailing = " "
        }
        suffix = trailing substr(rest, comment_at)
    } else {
        token = trim(rest)
        suffix = ""
    }
    print prefix leading presentation_scalar_text(node, token) suffix
}

function emit_presented_insert(key, node, indent,    inline, properties) {
    printf "%s%s:", yaml_spaces(indent), presentation_plain_safe(key) ? key : json_quote(key)
    inline = yaml_inline_node(node)
    if (inline != "") {
        printf " %s\n", inline
        return
    }
    properties = yaml_properties(node)
    if (properties != "") {
        printf " %s", properties
    }
    printf "\n"
    emit_yaml_collection(node, indent + 2)
}

function emit_presented_reorder(line,    item, source_line, start, end) {
    for (item = 1; item <= presentation_reorder_count[line]; item++) {
        start = presentation_reorder_start[line, item]
        end = presentation_reorder_end[line, item]
        for (source_line = start; source_line <= end; source_line++) {
            print raw_input_line[source_line]
        }
    }
}

function emit_preserved_input(    line, i) {
    for (line = 1; line <= NR; line++) {
        if (line in presentation_deleted_line) {
        } else if (line in presentation_line_node) {
            emit_presented_line(line, presentation_line_node[line])
        } else {
            print raw_input_line[line]
        }
        if (line in presentation_reorder_count) {
            emit_presented_reorder(line)
        }
        for (i = 1; i <= presentation_insert_count[line]; i++) {
            emit_presented_insert(presentation_insert_key[line, i], presentation_insert_node[line, i], presentation_insert_indent[line, i])
        }
    }
}

function transform_all_documents(query,    document, root, expression, input) {
    for (document = 0; document <= document_index; document++) {
        if (!(document in document_root)) {
            continue
        }
        root = document_root[document]
        expression = expression_parse(query)
        input = expression_stream_single(root)
        expression_evaluate(expression, input)
    }
}

function emit_all_yaml_documents(    document, emitted) {
    emitted = 0
    for (document = 0; document <= document_index; document++) {
        if (!(document in document_root)) {
            continue
        }
        if (emitted++) {
            print "---"
        }
        emit_yaml(document_root[document])
    }
}

function output_ast(document,    node, i) {
    for (node = 1; node <= node_count; node++) {
        if (node_document[node] != document) {
            continue
        }
        printf "node\t%d\t%s\tline=%d", node, node_kind[node], node_line[node]
        if (node_anchor[node] != "") {
            printf "\tanchor=%s", json_quote(node_anchor[node])
        }
        if (node_tag[node] != "") {
            printf "\ttag=%s", json_quote(node_tag[node])
        }
        if (node_kind[node] == "scalar") {
            printf "\ttype=%s\tvalue=%s", node_type[node], json_quote(node_value[node])
        } else if (node_kind[node] == "alias") {
            printf "\tname=%s\ttarget=%d", json_quote(node_value[node]), alias_target[node]
        }
        printf "\n"

        if (node_kind[node] == "mapping") {
            for (i = 1; i <= mapping_count[node]; i++) {
                printf "edge\t%d\tkey=%s\tchild=%d\tmerge=%d\n", node, json_quote(mapping_key[node, i]), mapping_child[node, i], mapping_merge[node, i]
            }
        } else if (node_kind[node] == "sequence") {
            for (i = 1; i <= sequence_count[node]; i++) {
                printf "edge\t%d\tindex=%d\tchild=%d\n", node, i - 1, sequence_child[node, i]
            }
        }
    }
}

function event_indent(depth,    prefix, i) {
    prefix = ""
    for (i = 0; i < depth; i++) {
        prefix = prefix "  "
    }
    return prefix
}

function output_node_events(node, depth,    i, prefix) {
    prefix = event_indent(depth)
    if (node_kind[node] == "alias") {
        print prefix "ALIAS name=" json_quote(node_value[node]) " line=" node_line[node]
        return
    }
    if (node_kind[node] == "scalar") {
        print prefix "SCALAR type=" node_type[node] " value=" json_quote(node_value[node]) " line=" node_line[node]
        return
    }
    if (node_kind[node] == "mapping") {
        print prefix "MAPPING_START line=" node_line[node]
        for (i = 1; i <= mapping_count[node]; i++) {
            print prefix "  KEY value=" json_quote(mapping_key[node, i]) " merge=" mapping_merge[node, i]
            output_node_events(mapping_child[node, i], depth + 1)
        }
        print prefix "MAPPING_END"
        return
    }
    if (node_kind[node] == "sequence") {
        print prefix "SEQUENCE_START line=" node_line[node]
        for (i = 1; i <= sequence_count[node]; i++) {
            output_node_events(sequence_child[node, i], depth + 1)
        }
        print prefix "SEQUENCE_END"
    }
}

function output_events(document) {
    print "STREAM_START"
    print "DOCUMENT_START index=" document
    output_node_events(document_root[document], 1)
    print "DOCUMENT_END index=" document
    print "STREAM_END"
}

function output_expression_node(target, output_mode,    resolved) {
    resolved = resolve_alias(target)
    if (output_mode == "line") {
        print node_line[target]
    } else if (output_mode == "type") {
        if (node_kind[resolved] == "scalar") {
            print node_type[resolved]
        } else {
            print node_kind[resolved]
        }
    } else if (output_mode == "tag") {
        print node_tag[resolved]
    } else if (output_mode == "json") {
        emit_json(target)
        printf "\n"
    } else if (output_mode == "yaml") {
        emit_yaml(target)
    } else if (node_kind[resolved] == "scalar") {
        print node_value[resolved]
    } else {
        emit_json(target)
        printf "\n"
    }
}

function output_result(document, query, output_mode,    root, expression, input, results, i) {
    if (!(document in document_root)) {
        if (document == 0 && node_count == 0) {
            return
        }
        fail("document index not found: " document)
    }
    if (output_mode == "ast") {
        output_ast(document)
        return
    }
    if (output_mode == "events") {
        output_events(document)
        return
    }

    root = document_root[document]
    expression = expression_parse(query)
    input = expression_stream_single(root)
    results = expression_evaluate(expression, input)
    for (i = 1; i <= expression_stream_count[results]; i++) {
        if (output_mode == "yaml" && i > 1) {
            print "---"
        }
        output_expression_node(expression_stream_node[results, i], output_mode)
    }
}

BEGIN {
    document_index = 0
    if (query == "") {
        query = "."
    }
    if (output_mode == "") {
        output_mode = "value"
    }
    if (selected_document == "") {
        selected_document = 0
    }
    presentation_possible = 1
}

{
    raw_input_line[NR] = $0
    if (block_active) {
        process_line($0, NR)
        next
    }
    if (multiline_scalar_active) {
        multiline_scalar_text = multiline_scalar_text "\n" $0
        if (!multiline_quote_is_open(multiline_scalar_text, multiline_scalar_delimiter)) {
            process_line(multiline_scalar_text, multiline_scalar_line)
            multiline_scalar_active = 0
            multiline_scalar_text = ""
        }
        next
    }
    if (multiline_flow_active) {
        flow_line_clean = strip_flow_line_comment($0)
        if (flow_line_clean == "") {
            next
        }
        multiline_flow_text = multiline_flow_text " " flow_line_clean
        multiline_flow_depth = flow_balance(multiline_flow_text)
        if (multiline_flow_depth <= 0) {
            process_line(multiline_flow_text, multiline_flow_line)
            multiline_flow_active = 0
            multiline_flow_text = ""
        }
        next
    }
    if ($0 ~ /^[[:space:]]*$/ || $0 ~ /^[[:space:]]*#/) {
        process_line($0, NR)
        next
    }
    multiline_scalar_delimiter = multiline_scalar_quote($0)
    if (multiline_scalar_delimiter != "") {
        multiline_scalar_active = 1
        multiline_scalar_line = NR
        multiline_scalar_text = $0
        next
    }
    multiline_flow_depth = flow_balance($0)
    if (multiline_flow_depth > 0) {
        multiline_flow_active = 1
        multiline_flow_line = NR
        multiline_flow_text = strip_flow_line_comment($0)
        next
    }
    process_line($0, NR)
}

END {
    if (!exit_status && multiline_scalar_active) {
        print "Error: unclosed quoted scalar on line " multiline_scalar_line > "/dev/stderr"
        exit_status = 1
    }
    if (!exit_status && multiline_flow_active) {
        print "Error: unclosed multiline flow collection on line " multiline_flow_line > "/dev/stderr"
        exit_status = 1
    }
    if (!exit_status) {
        flush_block()
        for (pending_indent = 0; pending_indent <= max_indent; pending_indent++) {
            if (explicit_key_valid[pending_indent]) {
                add_explicit_null(pending_indent, NR + 1)
            }
        }
    }
    if (!exit_status && document_directive_pending[document_index]) {
        print "Error: directive requires a following document" > "/dev/stderr"
        exit_status = 1
    }
    if (!exit_status) {
        if (null_input_mode && !(0 in document_root) && node_count == 0) {
            document_index = 0
            create_empty_document(1)
        } else if (document_explicit[document_index] && !document_has_content[document_index]) {
            create_empty_document(NR + 1)
        }
        finalize_nodes()
        validate_aliases()
        validate_merges()
        if (inplace_mode) {
            transform_all_documents(query)
            if (presentation_possible) {
                emit_preserved_input()
            } else {
                emit_all_yaml_documents()
            }
        } else {
            output_result(selected_document + 0, query, output_mode)
        }
    }
    exit exit_status
}
