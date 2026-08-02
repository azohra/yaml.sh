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
        } else {
            result = result char
        }
    }
    return result
}

function json_quote(value) {
    return "\"" json_escape(value) "\""
}

function decode_double_quoted(value,    result, i, char, next_char) {
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
        } else if (next_char == "f") {
            result = result sprintf("%c", 12)
        } else if (next_char == "/" || next_char == "\\" || next_char == "\"") {
            result = result next_char
        } else {
            result = result "\\" next_char
        }
    }
    return result
}

function scalar_value(value,    quote) {
    value = trim(value)
    quote = sprintf("%c", 39)

    if (length(value) >= 2 && substr(value, 1, 1) == "\"" && substr(value, length(value), 1) == "\"") {
        return decode_double_quoted(substr(value, 2, length(value) - 2))
    }

    if (length(value) >= 2 && substr(value, 1, 1) == quote && substr(value, length(value), 1) == quote) {
        value = substr(value, 2, length(value) - 2)
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
        } else if (char == "}") {
            braces--
        } else if (char == "[") {
            brackets++
        } else if (char == "]") {
            brackets--
        } else if (char == "#" && braces == 0 && brackets == 0 && (i == 1 || previous ~ /[[:space:]]/)) {
            return trim(substr(value, 1, i - 1))
        }
    }
    return trim(value)
}

function find_top_level_colon(value, require_space,    i, char, next_char, quote, escaped, braces, brackets) {
    quote = ""
    escaped = 0
    braces = 0
    brackets = 0

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
        } else if (char == ":" && braces == 0 && brackets == 0) {
            next_char = substr(value, i + 1, 1)
            if (!require_space || next_char == "" || next_char ~ /[[:space:]]/) {
                return i
            }
        }
    }
    return 0
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
            if (parsed_anchor !~ /^[A-Za-z0-9_-]+$/) {
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
    root = document_root[document_index]
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

function parse_core(value, source_line, tag, anchor,    node, inner, count, i, separator, raw_key, key, child, alias_name) {
    if (value ~ /^\*[A-Za-z0-9_-]+$/) {
        if (tag != "" || anchor != "") {
            fail("aliases cannot carry a tag or anchor on line " source_line)
        }
        alias_name = substr(value, 2)
        return alias_node(alias_name, source_line)
    }

    if (substr(value, 1, 1) == "[" && substr(value, length(value), 1) == "]") {
        node = new_node("sequence", source_line, "", "", tag)
        bind_anchor(anchor, node, source_line)
        inner = substr(value, 2, length(value) - 2)
        count = split_flow(inner, flow_piece)
        for (i = 1; i <= count; i++) {
            child = parse_value(flow_piece[i], source_line, -1, 0)
            add_sequence(node, child, source_line)
            delete flow_piece[i]
        }
        return node
    }

    if (substr(value, 1, 1) == "{" && substr(value, length(value), 1) == "}") {
        node = new_node("mapping", source_line, "", "", tag)
        bind_anchor(anchor, node, source_line)
        inner = substr(value, 2, length(value) - 2)
        count = split_flow(inner, flow_piece)
        for (i = 1; i <= count; i++) {
            separator = find_top_level_colon(flow_piece[i], 0)
            if (!separator) {
                fail("invalid flow mapping on line " source_line)
            }
            raw_key = trim(substr(flow_piece[i], 1, separator - 1))
            if (raw_key == "" || substr(raw_key, 1, 1) == "[" || substr(raw_key, 1, 1) == "{") {
                fail("collection-valued mapping keys are not supported on line " source_line)
            }
            key = scalar_value(raw_key)
            child = parse_value(substr(flow_piece[i], separator + 1), source_line, -1, 0)
            add_mapping(node, key, child, source_line, raw_key == "<<")
            delete flow_piece[i]
        }
        return node
    }

    if (substr(value, 1, 1) == "[" || substr(value, 1, 1) == "{") {
        fail("multiline or unclosed flow collection on line " source_line)
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
    if (allow_block && remainder ~ /^[|>][-+0-9]*$/) {
        node = new_node("scalar", source_line, "", "string", tag)
        bind_anchor(anchor, node, source_line)
        start_block(node, remainder, indent, source_line)
        return node
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
            fail("explicit scalar key has no mapping value before line " source_line)
        }
    }
}

function start_block(node, indicator, indent, source_line) {
    block_active = 1
    block_node = node
    block_style = substr(indicator, 1, 1)
    block_chomp = "clip"
    if (indicator ~ /-/) {
        block_chomp = "strip"
    } else if (indicator ~ /\+/) {
        block_chomp = "keep"
    }
    block_base_indent = indent
    block_content_indent = -1
    block_count = 0
    block_source_line = source_line
}

function append_block_line(value) {
    block_lines[++block_count] = value
}

function flush_block(    value, i, separator) {
    if (!block_active) {
        return
    }

    value = ""
    for (i = 1; i <= block_count; i++) {
        value = value block_lines[i]
        if (i < block_count) {
            if (block_style == ">" && block_lines[i] != "" && block_lines[i + 1] != "") {
                separator = " "
            } else {
                separator = "\n"
            }
            value = value separator
        }
        delete block_lines[i]
    }

    if (block_count > 0) {
        if (block_chomp == "strip") {
            while (substr(value, length(value), 1) == "\n") {
                value = substr(value, 1, length(value) - 1)
            }
        } else if (block_chomp == "clip") {
            while (substr(value, length(value), 1) == "\n") {
                value = substr(value, 1, length(value) - 1)
            }
            value = value "\n"
        } else {
            value = value "\n"
        }
    }

    node_value[block_node] = value
    block_active = 0
    block_count = 0
}

function parse_mapping_into(value, parent, indent, source_line,    separator, raw_key, key, child) {
    separator = find_top_level_colon(value, 1)
    if (!separator) {
        fail("invalid mapping syntax on line " source_line)
    }

    raw_key = trim(substr(value, 1, separator - 1))
    if (raw_key == "" || substr(raw_key, 1, 1) == "[" || substr(raw_key, 1, 1) == "{") {
        fail("collection-valued mapping keys are not supported on line " source_line)
    }
    key = scalar_value(raw_key)
    child = parse_value(substr(value, separator + 1), source_line, indent, 1)
    add_mapping(parent, key, child, source_line, raw_key == "<<")

    delete list_node[indent]
    delete list_valid[indent]
    if (node_kind[child] == "pending") {
        context_node[indent] = child
        context_valid[indent] = 1
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
    } else {
        remainder = parse_properties(strip_inline_comment(original), source_line)
        tag = parsed_tag
        anchor = parsed_anchor
        separator = find_top_level_colon(remainder, 1)
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
    if (node_kind[item] == "pending" || node_kind[item] == "mapping") {
        context_node[indent] = item
        context_valid[indent] = 1
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

    if (directive_piece[1] == "%YAML" && count == 2 && directive_piece[2] ~ /^(1\.1|1\.2)$/) {
        document_yaml_version[document_index] = directive_piece[2]
        return
    }
    if (directive_piece[1] == "%TAG" && count == 3) {
        handle = directive_piece[2]
        prefix = directive_piece[3]
        if (substr(handle, 1, 1) == "!" && substr(handle, length(handle), 1) == "!") {
            tag_prefix[document_index SUBSEP handle] = prefix
            return
        }
    }
    fail("unsupported or malformed directive on line " source_line)
}

function add_explicit_value(indent, text, source_line,    parent, child) {
    if (!explicit_key_valid[indent]) {
        fail("explicit mapping value has no scalar key on line " source_line)
    }
    parent = find_parent(indent)
    if (!parent) {
        parent = ensure_root("mapping", source_line)
    } else {
        ensure_container(parent, "mapping", source_line)
    }
    child = parse_value(substr(text, 2), source_line, indent, 1)
    add_mapping(parent, explicit_key[indent], child, source_line, 0)
    delete explicit_key[indent]
    delete explicit_key_valid[indent]
    if (node_kind[child] == "pending") {
        context_node[indent] = child
        context_valid[indent] = 1
    }
}

function process_line(raw, source_line,    indent, text, clean, key_text, separator, root) {
    sub(/\r$/, "", raw)

    if (block_active) {
        if (raw ~ /^[[:space:]]*$/) {
            append_block_line("")
            return
        }
        indent = indentation(raw, source_line)
        if (indent > block_base_indent) {
            if (block_content_indent < 0) {
                block_content_indent = indent
            }
            if (indent < block_content_indent) {
                fail("invalid block scalar indentation on line " source_line)
            }
            append_block_line(substr(raw, block_content_indent + 1))
            return
        }
        flush_block()
    }

    if (raw ~ /^[[:space:]]*$/ || raw ~ /^[[:space:]]*#/) {
        return
    }

    indent = indentation(raw, source_line)
    text = substr(raw, indent + 1)
    clean = strip_inline_comment(text)

    if (substr(text, 1, 1) == "%") {
        if (indent != 0 || (document_index in document_root)) {
            fail("directives must appear before a document on line " source_line)
        }
        parse_directive(clean, source_line)
        return
    }

    if (clean == "---") {
        fail_pending_explicit_keys(source_line)
        if (document_has_content[document_index] || document_explicit[document_index]) {
            if (!document_has_content[document_index]) {
                create_empty_document(source_line)
            }
            document_index++
        }
        document_explicit[document_index] = 1
        document_ended = 0
        clear_structure()
        return
    }
    if (clean == "...") {
        fail_pending_explicit_keys(source_line)
        if (!document_has_content[document_index]) {
            create_empty_document(source_line)
        }
        document_ended = 1
        clear_structure()
        return
    }
    if (document_ended) {
        fail("content after document end requires --- on line " source_line)
    }

    clear_deeper(indent)
    if (text == "?" || text ~ /^\?[[:space:]]/) {
        key_text = trim(substr(text, 2))
        if (key_text == "" || substr(key_text, 1, 1) == "[" || substr(key_text, 1, 1) == "{" || find_top_level_colon(key_text, 1)) {
            fail("collection-valued complex keys are not supported on line " source_line)
        }
        explicit_key[indent] = scalar_value(strip_inline_comment(key_text))
        explicit_key_valid[indent] = 1
        return
    }
    if (text == ":" || text ~ /^:[[:space:]]/) {
        add_explicit_value(indent, text, source_line)
        return
    }
    if (explicit_key_valid[indent]) {
        fail("explicit scalar key has no mapping value before line " source_line)
    }

    if (text == "-" || text ~ /^-[[:space:]]/) {
        parse_sequence_line(text, indent, source_line)
        return
    }

    separator = find_top_level_colon(text, 1)
    if (separator) {
        parse_mapping_line(text, indent, source_line)
        return
    }

    if (indent != 0 || (document_index in document_root)) {
        fail("unknown syntax on line " source_line)
    }
    root = parse_value(text, source_line, indent, 1)
    document_root[document_index] = root
    document_has_content[document_index] = 1
}

function finalize_nodes(    node) {
    for (node = 1; node <= node_count; node++) {
        if (node_kind[node] == "pending") {
            node_kind[node] = "scalar"
            node_value[node] = ""
            node_type[node] = "null"
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

function parse_query(query,    i, start, char, content, quote, escaped, end, segment) {
    query_segment_count = 0
    if (query == ".") {
        return
    }
    if (substr(query, 1, 1) != ".") {
        fail("query must start with .")
    }

    i = 2
    while (i <= length(query)) {
        char = substr(query, i, 1)
        if (char == ".") {
            i++
            if (i > length(query)) {
                fail("query cannot end with .")
            }
            char = substr(query, i, 1)
        }

        if (char == "[") {
            start = i + 1
            quote = substr(query, start, 1)
            escaped = 0
            end = 0
            for (i = start; i <= length(query); i++) {
                char = substr(query, i, 1)
                if (escaped) {
                    escaped = 0
                    continue
                }
                if (quote == "\"" && char == "\\") {
                    escaped = 1
                    continue
                }
                if ((quote == "\"" || quote == sprintf("%c", 39)) && i > start && char == quote && substr(query, i + 1, 1) == "]") {
                    end = i + 1
                    content = substr(query, start, i - start + 1)
                    break
                }
                if (quote != "\"" && quote != sprintf("%c", 39) && char == "]") {
                    end = i
                    content = substr(query, start, i - start)
                    break
                }
            }
            if (!end) {
                fail("unclosed query bracket")
            }
            segment = ++query_segment_count
            if ((substr(content, 1, 1) == "\"" && substr(content, length(content), 1) == "\"") ||
                (substr(content, 1, 1) == sprintf("%c", 39) && substr(content, length(content), 1) == sprintf("%c", 39))) {
                query_segment_kind[segment] = "key"
                query_segment_value[segment] = scalar_value(content)
            } else if (content ~ /^[0-9]+$/) {
                query_segment_kind[segment] = "index"
                query_segment_value[segment] = content + 0
            } else {
                fail("query brackets require an index or quoted key")
            }
            i = end + 1
            continue
        }

        start = i
        while (i <= length(query) && substr(query, i, 1) != "." && substr(query, i, 1) != "[") {
            i++
        }
        content = substr(query, start, i - start)
        if (content == "") {
            fail("empty query segment")
        }
        segment = ++query_segment_count
        query_segment_kind[segment] = "key"
        query_segment_value[segment] = content
    }
}

function query_node(root, query,    node, resolved, i, item_index, child) {
    parse_query(query)
    node = root
    for (i = 1; i <= query_segment_count; i++) {
        resolved = resolve_alias(node)
        if (query_segment_kind[i] == "key") {
            if (node_kind[resolved] != "mapping") {
                fail("cannot select key " query_segment_value[i] " from " node_kind[resolved])
            }
            child = mapping_lookup(resolved, query_segment_value[i])
            if (!child) {
                fail("query key not found: " query_segment_value[i])
            }
            node = child
        } else {
            if (node_kind[resolved] != "sequence") {
                fail("cannot select an index from " node_kind[resolved])
            }
            item_index = query_segment_value[i]
            if (item_index < 0 || item_index >= sequence_count[resolved]) {
                fail("query index out of range: " item_index)
            }
            node = sequence_child[resolved, item_index + 1]
        }
    }
    return node
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

function output_node_events(node, depth,    i, prefix) {
    prefix = sprintf("%*s", depth * 2, "")
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

function output_result(document, query, output_mode,    root, target, resolved) {
    if (!(document in document_root)) {
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
    target = query_node(root, query)
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
    } else if (node_kind[resolved] == "scalar") {
        print node_value[resolved]
    } else {
        emit_json(target)
        printf "\n"
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
}

{
    process_line($0, NR)
}

END {
    if (!exit_status) {
        flush_block()
        for (pending_indent = 0; pending_indent <= max_indent; pending_indent++) {
            if (explicit_key_valid[pending_indent]) {
                print "Error: explicit scalar key has no mapping value at end of input" > "/dev/stderr"
                exit_status = 1
            }
        }
    }
    if (!exit_status) {
        if (!(0 in document_root) && node_count == 0) {
            document_index = 0
            create_empty_document(1)
        } else if (document_explicit[document_index] && !document_has_content[document_index]) {
            create_empty_document(NR + 1)
        }
        finalize_nodes()
        validate_aliases()
        validate_merges()
        output_result(selected_document + 0, query, output_mode)
    }
    exit exit_status
}
