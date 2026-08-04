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
    if (!escape_table_ready) {
        escape_literal["n"] = "\n"
        escape_literal["r"] = "\r"
        escape_literal["t"] = "\t"
        escape_literal["b"] = sprintf("%c", 8)
        escape_literal["0"] = sprintf("%c", 0)
        escape_literal["a"] = sprintf("%c", 7)
        escape_literal["v"] = sprintf("%c", 11)
        escape_literal["f"] = sprintf("%c", 12)
        escape_literal["e"] = sprintf("%c", 27)
        escape_literal[" "] = " "
        escape_literal["\t"] = "\t"
        escape_literal["_"] = unicode_utf8(160)
        escape_literal["N"] = unicode_utf8(133)
        escape_literal["L"] = unicode_utf8(8232)
        escape_literal["P"] = unicode_utf8(8233)
        escape_literal["/"] = "/"
        escape_literal["\\"] = "\\"
        escape_literal["\""] = "\""
        escape_table_ready = 1
    }
    result = ""
    for (i = 1; i <= length(value); i++) {
        char = substr(value, i, 1)
        if (char != "\\" || i == length(value)) {
            result = result char
            continue
        }

        next_char = substr(value, ++i, 1)
        if (next_char in escape_literal) {
            result = result escape_literal[next_char]
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

function fold_quoted_scalar(value, double_quoted,    count, i, line, result, content, breaks, escaped_break, quoted_line) {
    count = split(value, quoted_line, /\n/)
    result = ""
    breaks = 0
    escaped_break = 0

    for (i = 1; i <= count; i++) {
        line = quoted_line[i]
        if (i == 1) {
            content = trim_quoted_right(line, double_quoted)
        } else if (i == count) {
            content = trim_left_horizontal(line)
        } else {
            content = trim_quoted_right(trim_left_horizontal(line), double_quoted)
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
    quote = SQ

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
        (substr(raw, 1, 1) == SQ && substr(raw, length(raw), 1) == SQ)) {
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
    if (!index(value, "#")) {
        return trim(value)
    }
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
        if (char == "\"" || char == SQ) {
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
        if (char == "\"" || char == SQ) {
            quote = char
        } else if (char == "#" && (i == 1 || previous ~ /[[:space:]]/)) {
            return trim(substr(value, 1, i - 1))
        }
    }
    return trim(value)
}

function parser_pending_comment_add(raw, source_line,    text) {
    text = raw
    sub(/^[[:space:]]*#[ ]?/, "", text)
    if (parser_pending_comment != "") parser_pending_comment = parser_pending_comment "\n"
    parser_pending_comment = parser_pending_comment text
    if (!parser_pending_comment_start) parser_pending_comment_start = source_line
    parser_pending_comment_end = source_line
}

function parser_record_content(node, as_key) {
    if (parser_pending_comment != "") {
        if (as_key) {
            node_key_head_comment[node] = parser_pending_comment
            node_key_head_comment_start[node] = parser_pending_comment_start
            node_key_head_comment_end[node] = parser_pending_comment_end
        } else {
            node_head_comment[node] = parser_pending_comment
            node_head_comment_start[node] = parser_pending_comment_start
            node_head_comment_end[node] = parser_pending_comment_end
        }
        parser_pending_comment = ""
        parser_pending_comment_start = 0
        parser_pending_comment_end = 0
    }
    parser_last_content_node = node
    parser_last_content_is_key = as_key
}

function parser_flush_pending_foot() {
    if (parser_pending_comment == "" || !parser_last_content_node) return
    if (parser_last_content_is_key) {
        node_key_foot_comment[parser_last_content_node] = parser_pending_comment
        node_key_foot_comment_start[parser_last_content_node] = parser_pending_comment_start
        node_key_foot_comment_end[parser_last_content_node] = parser_pending_comment_end
    } else {
        node_foot_comment[parser_last_content_node] = parser_pending_comment
        node_foot_comment_start[parser_last_content_node] = parser_pending_comment_start
        node_foot_comment_end[parser_last_content_node] = parser_pending_comment_end
    }
    parser_pending_comment = ""
    parser_pending_comment_start = 0
    parser_pending_comment_end = 0
}

function start_flow_line(value,    prefix) {
    prefix = value
    sub(/[^ ].*$/, "", prefix)
    return prefix strip_flow_line_comment(value)
}

function flow_position_start(value, source_line,    i) {
    active_flow_position_map = ++flow_position_serial
    for (i = 1; i <= length(value); i++) {
        flow_position_line[active_flow_position_map, i] = source_line
        flow_position_column[active_flow_position_map, i] = i
    }
}

function flow_position_append(raw, value, source_line,    position, offset, i) {
    if (!active_flow_position_map) return
    position = length(multiline_flow_text) + 1
    offset = index(raw, value)
    if (!offset) offset = 1
    flow_position_line[active_flow_position_map, position] = source_line
    flow_position_column[active_flow_position_map, position] = offset
    for (i = 1; i <= length(value); i++) {
        flow_position_line[active_flow_position_map, position + i] = source_line
        flow_position_column[active_flow_position_map, position + i] = offset + i - 1
    }
}

function flow_pending_comment_add(raw, source_line,    text) {
    text = raw
    sub(/^[[:space:]]*#[ ]?/, "", text)
    if (multiline_flow_pending_comment != "") multiline_flow_pending_comment = multiline_flow_pending_comment "\n"
    multiline_flow_pending_comment = multiline_flow_pending_comment text
    if (!multiline_flow_pending_start) multiline_flow_pending_start = source_line
    multiline_flow_pending_end = source_line
}

function flow_position_bind_pending(position) {
    if (!active_flow_position_map || multiline_flow_pending_comment == "") return
    flow_position_comment[active_flow_position_map, position] = multiline_flow_pending_comment
    flow_position_comment_start[active_flow_position_map, position] = multiline_flow_pending_start
    flow_position_comment_end[active_flow_position_map, position] = multiline_flow_pending_end
    multiline_flow_pending_comment = ""
    multiline_flow_pending_start = 0
    multiline_flow_pending_end = 0
}

function flow_position_take_comment(position, node, as_key,    key) {
    key = active_flow_position_map SUBSEP position
    if (!active_flow_position_map || !(key in flow_position_comment)) return
    if (as_key) {
        node_key_head_comment[node] = flow_position_comment[key]
        node_key_head_comment_start[node] = flow_position_comment_start[key]
        node_key_head_comment_end[node] = flow_position_comment_end[key]
    } else {
        node_head_comment[node] = flow_position_comment[key]
        node_head_comment_start[node] = flow_position_comment_start[key]
        node_head_comment_end[node] = flow_position_comment_end[key]
    }
    delete flow_position_comment[key]
    delete flow_position_comment_start[key]
    delete flow_position_comment_end[key]
}

function flow_position_source_line(position, fallback) {
    return active_flow_position_map && ((active_flow_position_map SUBSEP position) in flow_position_line) ? flow_position_line[active_flow_position_map, position] : fallback
}

function flow_position_source_column(position, fallback) {
    return active_flow_position_map && ((active_flow_position_map SUBSEP position) in flow_position_column) ? flow_position_column[active_flow_position_map, position] : fallback
}

function flow_position_clear(    i, count) {
    if (!active_flow_position_map) return
    count = length(multiline_flow_text)
    for (i = 1; i <= count; i++) {
        delete flow_position_line[active_flow_position_map, i]
        delete flow_position_column[active_flow_position_map, i]
        delete flow_position_comment[active_flow_position_map, i]
        delete flow_position_comment_start[active_flow_position_map, i]
        delete flow_position_comment_end[active_flow_position_map, i]
    }
    active_flow_position_map = 0
    multiline_flow_pending_comment = ""
    multiline_flow_pending_start = 0
    multiline_flow_pending_end = 0
}

function flow_continuation_indent(value,    prefix, indent, clean, separator) {
    prefix = value
    sub(/[^ ].*$/, "", prefix)
    indent = length(prefix)
    clean = trim(substr(value, indent + 1))
    if (clean ~ /^---[[:space:]]/) {
        clean = trim(substr(clean, 4))
    }
    if (clean ~ /^-[[:space:]]/) {
        return indent + 1
    }
    separator = find_mapping_separator(clean, 1)
    return separator ? indent + 1 : indent
}

function flow_opening(value,    square, brace) {
    square = index(value, "[")
    brace = index(value, "{")
    if (square && (!brace || square < brace)) {
        return "["
    }
    return brace ? "{" : ""
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
        if ((char == "\"" || char == SQ) &&
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
    if (value ~ /^\*[^[:space:]]+:$/ &&
        index(value, "[") == 0 && index(value, "]") == 0 &&
        index(value, "{") == 0 && index(value, "}") == 0 &&
        index(value, ",") == 0) {
        return 0
    }
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

function split_flow(value, output, offsets,    count, start, i, char, quote, escaped, braces, brackets, raw, leading) {
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
        if (char == "\"" || char == SQ) {
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
            raw = substr(value, start, i - start)
            leading = leading_horizontal_width(raw)
            output[++count] = trim(raw)
            offsets[count] = start + leading
            start = i + 1
        }
    }
    raw = substr(value, start)
    leading = leading_horizontal_width(raw)
    output[++count] = trim(raw)
    offsets[count] = start + leading
    return count
}

function expand_tag(token,    rest, position, handle, suffix, key) {
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

