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

function repeat(value, count,    result, i) {
    result = ""
    for (i = 0; i < count; i++) {
        result = result value
    }
    return result
}

function join_path(parent, child) {
    if (parent == "") {
        return child
    }
    return parent "." child
}

function encode(value,    result, i, char) {
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
        value = substr(value, 2, length(value) - 2)
        return decode_double_quoted(value)
    }

    if (length(value) >= 2 && substr(value, 1, 1) == quote && substr(value, length(value), 1) == quote) {
        value = substr(value, 2, length(value) - 2)
        gsub(quote quote, quote, value)
    }

    return value
}

function emit(path, value, source_line,    prefix) {
    prefix = repeat("-", document_index)
    if (line_numbers) {
        print prefix path "=" source_line
    } else {
        print prefix path "=\"" encode(value) "\""
    }
    content_seen = 1
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

function find_top_level_colon(value,    i, char, quote, escaped, braces, brackets) {
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
            return i
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

function parse_node(value, path, source_line,    inner, count, pieces, i, separator, key, child_value) {
    value = strip_inline_comment(trim(value))

    if (substr(value, 1, 1) == "[" && substr(value, length(value), 1) == "]") {
        inner = substr(value, 2, length(value) - 2)
        count = split_flow(inner, pieces)
        for (i = 1; i <= count; i++) {
            parse_node(pieces[i], join_path(path, "[" (i - 1) "]"), source_line)
            delete pieces[i]
        }
        return
    }

    if (substr(value, 1, 1) == "{" && substr(value, length(value), 1) == "}") {
        inner = substr(value, 2, length(value) - 2)
        count = split_flow(inner, pieces)
        for (i = 1; i <= count; i++) {
            separator = find_top_level_colon(pieces[i])
            if (!separator) {
                fail("invalid flow mapping on line " source_line)
            }
            key = scalar_value(substr(pieces[i], 1, separator - 1))
            child_value = substr(pieces[i], separator + 1)
            parse_node(child_value, join_path(path, key), source_line)
            delete pieces[i]
        }
        return
    }

    emit(path, scalar_value(value), source_line)
}

function clear_deeper(indent,    i) {
    for (i = indent + 1; i <= max_indent; i++) {
        delete context_path[i]
        delete context_valid[i]
        delete list_path[i]
        delete list_valid[i]
    }
    if (indent > max_indent) {
        max_indent = indent
    }
}

function clear_structure(    i) {
    for (i = 0; i <= max_indent; i++) {
        delete context_path[i]
        delete context_valid[i]
        delete list_path[i]
        delete list_valid[i]
    }
    max_indent = 0
}

function find_parent(indent,    i) {
    for (i = indent - 1; i >= 0; i--) {
        if (context_valid[i]) {
            return context_path[i]
        }
    }
    return ""
}

function start_block(path, indicator, indent, source_line) {
    block_active = 1
    block_path = path
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

    emit(block_path, value, block_source_line)
    block_active = 0
    block_count = 0
}

function parse_mapping(value, indent, parent, source_line,    separator, key, child_path, child_value) {
    separator = find_top_level_colon(value)
    if (!separator) {
        fail("unknown syntax on line " source_line)
    }

    key = scalar_value(substr(value, 1, separator - 1))
    if (key == "") {
        fail("empty key on line " source_line)
    }
    child_path = join_path(parent, key)
    child_value = strip_inline_comment(substr(value, separator + 1))

    delete list_path[indent]
    delete list_valid[indent]

    if (child_value == "") {
        context_path[indent] = child_path
        context_valid[indent] = 1
        return
    }

    delete context_path[indent]
    delete context_valid[indent]
    if (child_value ~ /^[|>][-+0-9]*$/) {
        start_block(child_path, child_value, indent, source_line)
    } else {
        parse_node(child_value, child_path, source_line)
    }
}

function parse_sequence(value, indent, source_line,    parent, counter_key, item_index, item_path, item_value, mapping_separator, mapping_suffix) {
    if (list_valid[indent]) {
        parent = list_path[indent]
    } else if (context_valid[indent]) {
        parent = context_path[indent]
    } else {
        parent = find_parent(indent)
    }

    list_path[indent] = parent
    list_valid[indent] = 1
    counter_key = document_index SUBSEP parent SUBSEP indent
    item_index = list_counter[counter_key]++
    item_path = join_path(parent, "[" item_index "]")
    context_path[indent] = item_path
    context_valid[indent] = 1

    item_value = trim(substr(value, 2))
    if (item_value == "") {
        return
    }
    mapping_separator = find_top_level_colon(item_value)
    mapping_suffix = substr(item_value, mapping_separator + 1, 1)
    if (mapping_separator && (mapping_suffix == "" || mapping_suffix ~ /[[:space:]]/)) {
        parse_mapping(item_value, indent + 2, item_path, source_line)
    } else {
        parse_node(item_value, item_path, source_line)
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

function process_line(raw, source_line,    indent, text, parent) {
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

    if (strip_inline_comment(text) == "---") {
        if (content_seen) {
            document_index++
        }
        clear_structure()
        return
    }
    if (strip_inline_comment(text) == "...") {
        clear_structure()
        return
    }

    clear_deeper(indent)
    if (text == "-" || text ~ /^-[[:space:]]/) {
        parse_sequence(text, indent, source_line)
    } else {
        parent = find_parent(indent)
        parse_mapping(text, indent, parent, source_line)
    }
}

{
    process_line($0, NR)
}

END {
    if (!exit_status) {
        flush_block()
    }
    exit exit_status
}
