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

function scalar_type(raw, tag, value,    lowered, normalized_tag) {
    normalized_tag = tag
    sub(/^!</, "", normalized_tag)
    sub(/>$/, "", normalized_tag)
    sub(/^!!/, "", normalized_tag)
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

function record_key(document, path) {
    return document SUBSEP path
}

function emit(path, value, source_line, value_type,    key, position) {
    key = record_key(document_index, path)
    if (merge_mode && (key in record_position)) {
        return
    }

    if (key in record_position) {
        position = record_position[key]
        if (!record_merged[position]) {
            fail("duplicate or ambiguous mapping path " path " on line " source_line)
        }
    } else {
        position = ++record_count
        record_position[key] = position
        record_document[position] = document_index
        record_path[position] = path
    }

    record_value[position] = value
    record_line[position] = source_line
    record_type[position] = (value_type == "" ? "string" : value_type)
    record_merged[position] = merge_mode
    content_seen = 1
}

function output_records(    i, prefix) {
    for (i = 1; i <= record_count; i++) {
        prefix = repeat("-", record_document[i])
        if (line_numbers) {
            print prefix record_path[i] "=" record_line[i]
        } else if (value_types) {
            print prefix record_path[i] "=" record_type[i]
        } else {
            print prefix record_path[i] "=\"" encode(record_value[i]) "\""
        }
    }
}

function valid_anchor_name(name) {
    return name ~ /^[A-Za-z0-9_-]+$/
}

function define_anchor(name, path, source_line,    key) {
    if (!valid_anchor_name(name)) {
        fail("invalid anchor name on line " source_line)
    }
    key = document_index SUBSEP name
    anchor_path[key] = path
    anchor_defined[key] = 1
}

function parse_properties(value, path, source_line,    token, separator, anchor_name) {
    parsed_property_tag = ""
    parsed_property_anchor = ""
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
            anchor_name = substr(token, 2)
            define_anchor(anchor_name, path, source_line)
            parsed_property_anchor = anchor_name
        } else {
            parsed_property_tag = token
        }
    }
    return value
}

function copy_anchor(name, target_path, source_line, as_merge,    key, source_path, limit, i, relative_path, destination, found, previous_merge) {
    key = document_index SUBSEP name
    if (!(key in anchor_defined)) {
        fail("undefined alias *" name " on line " source_line)
    }
    source_path = anchor_path[key]
    if (target_path == source_path || index(target_path, source_path ".") == 1) {
        fail("recursive alias *" name " on line " source_line)
    }

    limit = record_count
    found = 0

    if (as_merge) {
        for (i = 1; i <= limit; i++) {
            if (record_document[i] != document_index) {
                continue
            }
            if (record_path[i] == source_path) {
                fail("merge alias *" name " does not reference a mapping on line " source_line)
            }
            if (index(record_path[i], source_path ".") == 1) {
                relative_path = substr(record_path[i], length(source_path) + 2)
                if (substr(relative_path, 1, 1) == "[") {
                    fail("merge alias *" name " does not reference a mapping on line " source_line)
                }
            }
        }
    }

    previous_merge = merge_mode
    merge_mode = as_merge
    for (i = 1; i <= limit; i++) {
        if (record_document[i] != document_index) {
            continue
        }
        if (record_path[i] == source_path) {
            destination = target_path
        } else if (index(record_path[i], source_path ".") == 1) {
            relative_path = substr(record_path[i], length(source_path) + 2)
            destination = join_path(target_path, relative_path)
        } else {
            continue
        }
        emit(destination, record_value[i], source_line, record_type[i])
        found = 1
    }
    merge_mode = previous_merge

    # Empty collections have no flattened values, so a defined anchor may copy no records.
    return found
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

function parse_node(value, path, source_line,    inner, count, pieces, i, separator, raw_key, key, child_value, tag, resolved_value, alias_name) {
    value = strip_inline_comment(trim(value))
    value = parse_properties(value, path, source_line)
    tag = parsed_property_tag

    if (value ~ /^\*[A-Za-z0-9_-]+$/) {
        alias_name = substr(value, 2)
        copy_anchor(alias_name, path, source_line, 0)
        return
    }

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
            raw_key = trim(substr(pieces[i], 1, separator - 1))
            key = scalar_value(raw_key)
            child_value = substr(pieces[i], separator + 1)
            if (raw_key == "<<") {
                apply_merge(child_value, path, source_line)
            } else {
                parse_node(child_value, join_path(path, key), source_line)
            }
            delete pieces[i]
        }
        return
    }

    if (substr(value, 1, 1) == "[" || substr(value, 1, 1) == "{") {
        fail("multiline or unclosed flow collection on line " source_line)
    }

    resolved_value = scalar_value(value)
    emit(path, resolved_value, source_line, scalar_type(value, tag, resolved_value))
}

function clear_deeper(indent,    i) {
    for (i = indent + 1; i <= max_indent; i++) {
        delete context_path[i]
        delete context_valid[i]
        delete list_path[i]
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
        delete context_path[i]
        delete context_valid[i]
        delete list_path[i]
        delete list_valid[i]
        delete explicit_key[i]
        delete explicit_key_valid[i]
    }
    max_indent = 0
}

function fail_pending_explicit_keys(source_line,    i) {
    for (i = 0; i <= max_indent; i++) {
        if (explicit_key_valid[i]) {
            fail("explicit scalar key has no mapping value before line " source_line)
        }
    }
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

function apply_merge_value(value, target_path, source_line,    alias_name, previous_merge) {
    value = trim(value)
    if (value ~ /^\*[A-Za-z0-9_-]+$/) {
        alias_name = substr(value, 2)
        copy_anchor(alias_name, target_path, source_line, 1)
        return
    }
    if (substr(value, 1, 1) == "{" && substr(value, length(value), 1) == "}") {
        previous_merge = merge_mode
        merge_mode = 1
        parse_node(value, target_path, source_line)
        merge_mode = previous_merge
        return
    }
    fail("merge value must be an alias, alias list, or flow mapping on line " source_line)
}

function apply_merge(value, target_path, source_line,    inner, count, pieces, i) {
    value = strip_inline_comment(trim(value))
    if (substr(value, 1, 1) == "[" && substr(value, length(value), 1) == "]") {
        inner = substr(value, 2, length(value) - 2)
        count = split_flow(inner, pieces)
        for (i = 1; i <= count; i++) {
            apply_merge_value(pieces[i], target_path, source_line)
            delete pieces[i]
        }
        return
    }
    apply_merge_value(value, target_path, source_line)
}

function parse_mapping_value(key, child_value, indent, parent, source_line, is_merge_key,    child_path, original_value, property_value, property_tag, property_anchor) {
    child_value = strip_inline_comment(child_value)

    delete list_path[indent]
    delete list_valid[indent]

    if (is_merge_key) {
        delete context_path[indent]
        delete context_valid[indent]
        if (child_value == "") {
            fail("block merge lists are not supported on line " source_line "; use <<: [*first, *second]")
        }
        apply_merge(child_value, parent, source_line)
        return
    }

    child_path = join_path(parent, key)
    original_value = child_value
    property_value = parse_properties(child_value, child_path, source_line)
    property_tag = parsed_property_tag
    property_anchor = parsed_property_anchor

    if (property_value == "") {
        context_path[indent] = child_path
        context_valid[indent] = 1
        return
    }

    delete context_path[indent]
    delete context_valid[indent]
    if (property_value ~ /^[|>][-+0-9]*$/) {
        start_block(child_path, property_value, indent, source_line)
    } else {
        parse_node(original_value, child_path, source_line)
    }
}

function parse_mapping(value, indent, parent, source_line,    separator, raw_key, key, child_value) {
    separator = find_top_level_colon(value)
    if (!separator) {
        fail("unknown syntax on line " source_line)
    }

    raw_key = trim(substr(value, 1, separator - 1))
    key = scalar_value(raw_key)
    if (key == "") {
        fail("empty key on line " source_line)
    }
    child_value = substr(value, separator + 1)
    parse_mapping_value(key, child_value, indent, parent, source_line, raw_key == "<<")
}

function parse_sequence(value, indent, source_line,    parent, counter_key, item_index, item_path, item_value, original_value, property_value, mapping_separator, mapping_suffix) {
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

    original_value = trim(substr(value, 2))
    if (original_value == "") {
        return
    }

    property_value = parse_properties(original_value, item_path, source_line)
    if (property_value == "") {
        return
    }

    item_value = property_value
    mapping_separator = find_top_level_colon(item_value)
    mapping_suffix = substr(item_value, mapping_separator + 1, 1)
    if (mapping_separator && (mapping_suffix == "" || mapping_suffix ~ /[[:space:]]/)) {
        parse_mapping(item_value, indent + 2, item_path, source_line)
    } else {
        parse_node(original_value, item_path, source_line)
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

function process_line(raw, source_line,    indent, text, parent, directive, key_text, child_value) {
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

    if (substr(text, 1, 1) == "%") {
        directive = strip_inline_comment(text)
        if (indent != 0) {
            fail("directives must not be indented on line " source_line)
        }
        if (directive ~ /^%YAML[[:space:]]+(1\.1|1\.2)$/ ||
            directive ~ /^%TAG[[:space:]]+![^[:space:]]*[[:space:]]+[^[:space:]]+$/) {
            return
        }
        fail("unsupported or malformed directive on line " source_line)
    }

    if (strip_inline_comment(text) == "---") {
        fail_pending_explicit_keys(source_line)
        if (content_seen) {
            document_index++
        }
        clear_structure()
        return
    }
    if (strip_inline_comment(text) == "...") {
        fail_pending_explicit_keys(source_line)
        clear_structure()
        return
    }

    clear_deeper(indent)
    if (text == "?" || text ~ /^\?[[:space:]]/) {
        key_text = trim(substr(text, 2))
        if (key_text == "" || substr(key_text, 1, 1) == "[" || substr(key_text, 1, 1) == "{" || find_top_level_colon(key_text)) {
            fail("collection-valued complex keys are not supported on line " source_line)
        }
        explicit_key[indent] = scalar_value(strip_inline_comment(key_text))
        explicit_key_valid[indent] = 1
        return
    }
    if (text == ":" || text ~ /^:[[:space:]]/) {
        if (!explicit_key_valid[indent]) {
            fail("explicit mapping value has no scalar key on line " source_line)
        }
        parent = find_parent(indent)
        child_value = substr(text, 2)
        parse_mapping_value(explicit_key[indent], child_value, indent, parent, source_line, 0)
        delete explicit_key[indent]
        delete explicit_key_valid[indent]
        return
    }

    if (explicit_key_valid[indent]) {
        fail("explicit scalar key has no mapping value before line " source_line)
    }
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
        for (pending_indent = 0; pending_indent <= max_indent; pending_indent++) {
            if (explicit_key_valid[pending_indent]) {
                print "Error: explicit scalar key has no mapping value at end of input" > "/dev/stderr"
                exit_status = 1
            }
        }
        if (!exit_status) {
            flush_block()
            output_records()
        }
    }
    exit exit_status
}
