function parse_core(value, source_line, tag, anchor, column_base,    node, inner, count, i, separator, raw_key, raw_value, leading, key, child, alias_name, flow_serial, piece, piece_offset, is_merge) {
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
            flow_piece_saved_offset[flow_piece_serial + 1, i] = flow_piece_offset[i]
            delete flow_piece[i]
            delete flow_piece_offset[i]
        }
        flow_serial = ++flow_piece_serial
        for (i = 1; i <= count; i++) {
            piece = flow_piece_saved[flow_serial, i]
            piece_offset = flow_piece_saved_offset[flow_serial, i]
            if (i == count && piece == "") {
                delete flow_piece_saved[flow_serial, i]
                delete flow_piece_saved_offset[flow_serial, i]
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
                child = new_node("mapping", flow_position_source_line(column_base + piece_offset, source_line), "", "", "")
                node_column[child] = column_base ? flow_position_source_column(column_base + piece_offset, column_base + piece_offset) : 0
                key = parse_scalar_key(raw_key, source_line)
                is_merge = parsed_key_is_merge
                raw_value = substr(piece, separator + 1)
                leading = leading_horizontal_width(raw_value)
                raw_value = trim(raw_value)
                add_mapping(child, key, parse_value(raw_value, source_line, -1, 0, column_base ? column_base + piece_offset + separator + leading : 0), source_line, is_merge)
                node_key_column[mapping_child[child, 1]] = column_base ? flow_position_source_column(column_base + piece_offset, column_base + piece_offset) : 0
                node_key_line[mapping_child[child, 1]] = column_base ? flow_position_source_line(column_base + piece_offset, source_line) : source_line
            } else {
                child = parse_value(piece, source_line, -1, 0, column_base ? column_base + piece_offset : 0)
            }
            if (column_base) flow_position_take_comment(column_base + piece_offset, child, 0)
            add_sequence(node, child, source_line)
            delete flow_piece_saved[flow_serial, i]
            delete flow_piece_saved_offset[flow_serial, i]
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
            flow_piece_saved_offset[flow_piece_serial + 1, i] = flow_piece_offset[i]
            delete flow_piece[i]
            delete flow_piece_offset[i]
        }
        flow_serial = ++flow_piece_serial
        for (i = 1; i <= count; i++) {
            piece = flow_piece_saved[flow_serial, i]
            piece_offset = flow_piece_saved_offset[flow_serial, i]
            if (i == count && piece == "") {
                delete flow_piece_saved[flow_serial, i]
                delete flow_piece_saved_offset[flow_serial, i]
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
                raw_value = substr(piece, separator + 1)
                leading = leading_horizontal_width(raw_value)
                raw_value = trim(raw_value)
                child = parse_value(raw_value, source_line, -1, 0, column_base ? column_base + piece_offset + separator + leading : 0)
                node_key_column[child] = column_base ? flow_position_source_column(column_base + piece_offset, column_base + piece_offset) : 0
                node_key_line[child] = column_base ? flow_position_source_line(column_base + piece_offset, source_line) : source_line
                add_mapping(node, key, child, source_line, is_merge)
                if (column_base) flow_position_take_comment(column_base + piece_offset, child, 1)
            } else {
                key = parse_scalar_key(piece, source_line)
                is_merge = parsed_key_is_merge
                child = new_node("scalar", flow_position_source_line(column_base + piece_offset, source_line), "", "null", "")
                node_column[child] = column_base ? flow_position_source_column(column_base + piece_offset + length(piece), column_base + piece_offset + length(piece)) : 0
                node_key_column[child] = column_base ? flow_position_source_column(column_base + piece_offset, column_base + piece_offset) : 0
                node_key_line[child] = column_base ? flow_position_source_line(column_base + piece_offset, source_line) : source_line
                add_mapping(node, key, child, source_line, is_merge)
                if (column_base) flow_position_take_comment(column_base + piece_offset, child, 1)
            }
            delete flow_piece_saved[flow_serial, i]
            delete flow_piece_saved_offset[flow_serial, i]
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

function record_node_presentation(node, syntax, original,    first, comment_at) {
    first = substr(syntax, 1, 1)
    if (node_kind[node] != "alias") {
        if (first == sprintf("%c", 39)) {
            node_style[node] = "single"
        } else if (first == "\"") {
            node_style[node] = "double"
        } else if (first == "|") {
            node_style[node] = "literal"
        } else if (first == ">") {
            node_style[node] = "folded"
        } else if (first == "[" || first == "{") {
            node_style[node] = "flow"
        }
    }
    comment_at = presentation_comment_position(original)
    if (comment_at) {
        node_line_comment[node] = trim(substr(original, comment_at + 1))
    }
    return node
}

function parse_value(value, source_line, indent, allow_block, column_base,    cleaned, remainder, tag, anchor, node) {
    cleaned = strip_inline_comment(trim(value))
    remainder = parse_properties(cleaned, source_line)
    tag = parsed_tag
    anchor = parsed_anchor

    if (remainder == "") {
        node = new_node("pending", source_line, "", "", tag)
        bind_anchor(anchor, node, source_line)
        return record_node_presentation(node, remainder, value)
    }
    if (!allow_block && remainder == "-") {
        fail("plain dash is not valid in a flow collection on line " source_line)
    }
    if (allow_block && cleaned ~ /^[!&]/ && remainder ~ /^-[[:space:]]/) {
        fail("block sequence entries must begin on their own line " source_line)
    }
    if (allow_block && remainder ~ /^[|>]([-+]?[1-9]?|[1-9][-+]?)$/) {
        node = new_node("scalar", source_line, "", "string", tag)
        bind_anchor(anchor, node, source_line)
        start_block(node, remainder, indent, source_line)
        return record_node_presentation(node, remainder, value)
    }
    if (allow_block && remainder ~ /^[|>]/) {
        fail("invalid block scalar indicator on line " source_line)
    }
    if (substr(remainder, 1, 1) == "@" || substr(remainder, 1, 1) == "`") {
        fail("reserved indicator cannot start a plain scalar on line " source_line)
    }
    if (!(substr(remainder, 1, 1) == "*" && valid_anchor_name(substr(remainder, 2))) &&
        find_top_level_colon(remainder, 1)) {
        fail("mapping indicator inside plain scalar on line " source_line)
    }
    node = parse_core(remainder, source_line, tag, anchor, column_base)
    if (column_base) {
        node_line[node] = flow_position_source_line(column_base, source_line)
        node_column[node] = flow_position_source_column(column_base, column_base)
    }
    return record_node_presentation(node, remainder, value)
}

function is_plain_scalar_source(value, source_line,    remainder, first) {
    remainder = parse_properties(strip_inline_comment(trim(value)), source_line)
    first = substr(remainder, 1, 1)
    return remainder != "" && first != "\"" && first != sprintf("%c", 39) &&
        first != "[" && first != "{" && first != "|" && first != ">"
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

function validate_container_indent(node, indent, source_line) {
    if (!(node in container_entry_indent)) {
        container_entry_indent[node] = indent
    } else if (container_entry_indent[node] != indent) {
        fail("inconsistent collection indentation on line " source_line)
    }
}

function close_plain_contexts(    node) {
    for (node = 1; node <= node_count; node++) {
        if (node_plain_continuable[node]) {
            node_plain_closed[node] = 1
        }
    }
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
    block_leading_blank_max = 0
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
    if (explicit_block_node == block_node) {
        explicit_key[explicit_block_indent] = value
        explicit_block_node = 0
    }
    block_active = 0
    block_count = 0
}

function parse_mapping_into(value, parent, indent, source_line,    separator, raw_key, key, child, raw_value, raw_suffix, column, is_merge) {
    if (indent > max_indent) {
        max_indent = indent
    }
    validate_container_indent(parent, indent, source_line)
    separator = find_mapping_separator(value, 1)
    if (!separator) {
        fail("invalid mapping syntax on line " source_line)
    }

    raw_key = trim(substr(value, 1, separator - 1))
    key = parse_scalar_key(raw_key, source_line)
    is_merge = parsed_key_is_merge
    raw_suffix = substr(value, separator + 1)
    raw_value = trim(raw_suffix)
    column = raw_value == "" ? indent + separator + 1 : indent + separator + leading_horizontal_width(raw_suffix) + 1
    if (raw_key != "" && raw_value ~ /^-[[:space:]]/) {
        fail("block sequence entries must begin on their own line " source_line)
    }
    child = parse_value(raw_value, source_line, indent, 1, column)
    node_indent[child] = indent
    node_column[child] = column
    node_key_column[child] = indent + 1
    node_key_line[child] = source_line
    add_mapping(parent, key, child, source_line, is_merge)
    parser_record_content(child, 1)
    if (source_line in source_line_comment) {
        if (node_kind[child] == "scalar" || node_kind[child] == "alias" || node_style[child] == "flow") {
            node_line_comment[child] = source_line_comment[source_line]
        } else {
            node_key_line_comment[child] = source_line_comment[source_line]
            delete node_line_comment[child]
        }
    }

    delete list_node[indent]
    delete list_valid[indent]
    if (node_kind[child] == "pending") {
        context_node[indent] = child
        context_valid[indent] = 1
    } else if (node_kind[child] == "scalar" && is_plain_scalar_source(raw_value, source_line)) {
        context_node[indent] = child
        context_valid[indent] = 1
        node_plain_continuable[child] = 1
        node_plain_base_indent[child] = indent
        node_plain_closed[child] = strip_inline_comment(raw_value) != trim(raw_value)
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

function parse_sequence_line(value, indent, source_line,    sequence, parent, original, remainder, tag, anchor, item, separator, raw_key, key, child, nested_indent) {
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

    validate_container_indent(sequence, indent, source_line)

    list_node[indent] = sequence
    list_valid[indent] = 1
    remainder = substr(value, 2)
    nested_indent = indent + 1
    while (substr(remainder, 1, 1) == " " || substr(remainder, 1, 1) == "\t") {
        nested_indent++
        remainder = substr(remainder, 2)
    }
    original = trim(remainder)

    if (original == "") {
        item = new_node("pending", source_line, "", "", "")
    } else if (original == "-" || original ~ /^-[[:space:]]/) {
        item = new_node("sequence", source_line, "", "", "")
        add_sequence(sequence, item, source_line)
        parser_record_content(item, 0)
        context_node[indent] = item
        context_valid[indent] = 1
        parse_sequence_line(original, nested_indent, source_line)
        return
    } else {
        remainder = parse_properties(strip_inline_comment(original), source_line)
        tag = parsed_tag
        anchor = parsed_anchor
        separator = find_mapping_separator(remainder, 1)
        if (separator && substr(remainder, 1, 1) != "{" && substr(remainder, 1, 1) != "[") {
            item = new_node("mapping", source_line, "", "", tag)
            node_indent[item] = indent
            node_column[item] = nested_indent + 1
            bind_anchor(anchor, item, source_line)
            add_sequence(sequence, item, source_line)
            parser_record_content(item, 0)
            context_node[indent] = item
            context_valid[indent] = 1
            parse_mapping_into(remainder, item, indent + 2, source_line)
            return
        }
        item = parse_value(original, source_line, indent, 1, original == "" ? indent + 2 : nested_indent + 1)
    }

    add_sequence(sequence, item, source_line)
    parser_record_content(item, 0)
    if (source_line in source_line_comment) {
        node_line_comment[item] = source_line_comment[source_line]
    }
    node_indent[item] = indent
    node_column[item] = original == "" ? indent + 2 : nested_indent + 1
    if (node_kind[item] == "pending" || node_kind[item] == "mapping" ||
        (node_kind[item] == "scalar" && is_plain_scalar_source(original, source_line))) {
        context_node[indent] = item
        context_valid[indent] = 1
        if (node_kind[item] == "scalar") {
            node_plain_continuable[item] = 1
            node_plain_base_indent[item] = indent
            node_plain_closed[item] = strip_inline_comment(original) != trim(original)
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
    if (raw_value ~ /^-[[:space:]]/) {
        child = new_node("sequence", source_line, "", "", "")
        add_mapping(parent, explicit_key[indent], child, source_line, 0)
        parser_record_content(child, 1)
        list_node[indent + 2] = child
        list_valid[indent + 2] = 1
        parse_sequence_line(raw_value, indent + 2, source_line)
    } else {
        child = parse_value(raw_value, source_line, indent, 1, raw_value == "" ? indent + 2 : indent + 2 + leading_horizontal_width(substr(text, 2)))
        add_mapping(parent, explicit_key[indent], child, source_line, 0)
        parser_record_content(child, 1)
    }
    node_indent[child] = indent
    node_key_column[child] = indent + 1
    node_key_line[child] = source_line
    node_column[child] = raw_value == "" ? indent + 2 : indent + 2 + leading_horizontal_width(substr(text, 2))
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
    node_key_column[child] = indent + 1
    node_key_line[child] = source_line
    parser_record_content(child, 1)
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

function fill_pending_scalar(node, text, source_line,    cleaned, remainder, tag, anchor, target) {
    cleaned = strip_inline_comment(trim(text))
    remainder = parse_properties(cleaned, source_line)
    tag = parsed_tag
    anchor = parsed_anchor
    if (remainder == "" || substr(remainder, 1, 1) == "[" || substr(remainder, 1, 1) == "{" || remainder ~ /^[|>]/) {
        return 0
    }
    if (substr(remainder, 1, 1) == "*" && valid_anchor_name(substr(remainder, 2))) {
        target = document_index SUBSEP substr(remainder, 2)
        if (!(target in anchor_target)) {
            fail("undefined or forward alias " remainder " on line " source_line)
        }
        target = resolve_alias(anchor_target[target])
        if (node_kind[target] != "scalar") {
            fail("collection alias cannot fill a scalar value on line " source_line)
        }
        node_kind[node] = "scalar"
        node_value[node] = node_value[target]
        node_type[node] = node_type[target]
        node_tag[node] = node_tag[target]
        return 1
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
    if (strip_inline_comment(text) != trim(text)) {
        node_plain_closed[node] = 1
    }
    return 1
}

function process_line(raw, source_line,    indent, text, clean, key_text, separator, root, marker_content, parent, prefix, candidate, tab_position, explicit_indent, comment_at) {
    sub(/\r$/, "", raw)

    if (block_active) {
        candidate = strip_inline_comment(trim(raw))
        if (raw !~ /^[[:space:]]/ && (candidate == "..." || candidate == "---" || candidate ~ /^---[[:space:]]/)) {
            flush_block()
        }
    }

    if (block_active) {
        if (block_content_indent < 0 && raw ~ /^ *\t[ \t]*$/) {
            prefix = raw
            sub(/\t.*$/, "", prefix)
            if (length(prefix) == 0) {
                fail("tabs cannot begin block scalar indentation on line " source_line)
            }
            if (block_leading_blank_max > length(prefix)) {
                fail("invalid block scalar indentation on line " source_line)
            }
            block_content_indent = length(prefix)
            append_block_line(substr(raw, block_content_indent + 1), 1, 0)
            return
        }
        if (raw ~ /^[[:space:]]*$/) {
            if (block_content_indent < 0 && length(raw) > block_leading_blank_max) {
                block_leading_blank_max = length(raw)
            }
            append_block_line(raw, 0, 1)
            return
        }
        prefix = raw
        sub(/[^ ].*$/, "", prefix)
        indent = length(prefix)
        if (block_content_indent < 0 && indent > block_base_indent) {
            if (block_leading_blank_max > indent) {
                fail("invalid block scalar indentation on line " source_line)
            }
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

    if (raw ~ /^[[:space:]]*#/) {
        close_plain_contexts()
        parser_pending_comment_add(raw, source_line)
        return
    }
    if (raw ~ /^[[:space:]]*$/) {
        parser_flush_pending_foot()
        return
    }

    multiline_scalar_delimiter = !index(raw, "\n") && raw ~ /["']/ ? multiline_scalar_quote(raw) : ""
    if (multiline_scalar_delimiter != "") {
        multiline_scalar_active = 1
        multiline_scalar_line = source_line
        multiline_scalar_text = raw
        multiline_scalar_min_indent = flow_continuation_indent(raw)
        return
    }

    if (flow_balance(raw) > 0) {
        if (raw ~ /,#[^[:space:]]/) {
            fail("comments in flow collections require separation on line " source_line)
        }
        multiline_flow_active = 1
        multiline_flow_line = source_line
        multiline_flow_text = start_flow_line(raw)
        flow_position_start(multiline_flow_text, source_line)
        multiline_flow_depth = flow_balance(multiline_flow_text)
        multiline_flow_min_indent = flow_continuation_indent(raw)
        multiline_flow_root = flow_opening(raw)
        multiline_flow_comment_break = 0
        return
    }

    if (raw ~ /^ *-[ ]*\t-([[:space:]]|$)/ ||
        raw ~ /^ *\?[ ]*\t-([[:space:]]|$)/ ||
        raw ~ /^ *:[ ]*\t-([[:space:]]|$)/) {
        fail("tabs cannot separate block collection indicators on line " source_line)
    }

    prefix = raw
    sub(/[^ \t].*$/, "", prefix)
    if (index(prefix, "\t")) {
        candidate = substr(raw, length(prefix) + 1)
        tab_position = index(raw, "\t")
        if (find_mapping_separator(candidate, 1)) {
            fail("tabs cannot be used for mapping indentation on line " source_line)
        }
        if (substr(candidate, 1, 1) == "[" || substr(candidate, 1, 1) == "{") {
            raw = candidate
        } else {
            raw = substr(raw, 1, tab_position - 1) candidate
        }
    }

    root = (document_index in document_root) ? document_root[document_index] : 0
    candidate = strip_inline_comment(trim(raw))
    if (!document_ended && root && node_kind[root] == "scalar" && node_plain_continuable[root] && !node_plain_closed[root] &&
        !(raw !~ /^[[:space:]]/ && (candidate == "---" || candidate ~ /^---[[:space:]]/ || candidate == "...")) &&
        (raw ~ /^[[:space:]]/ || !find_mapping_separator(candidate, 1))) {
        append_plain_scalar(root, raw, source_line)
        return
    }

    indent = indentation(raw, source_line)
    text = substr(raw, indent + 1)
    comment_at = presentation_comment_position(text)
    if (comment_at) {
        source_line_comment[source_line] = trim(substr(text, comment_at + 1))
    }
    clean = strip_inline_comment(text)
    if (indent == 0 && (clean == "---" || clean == "...")) parser_flush_pending_foot()

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
        if (marker_content ~ /^[!&]/ && find_mapping_separator(marker_content, 1)) {
            fail("node properties cannot introduce a mapping on a document marker line " source_line)
        }
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
        parser_last_content_node = 0
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
    if (parent && node_kind[parent] == "scalar" && node_plain_continuable[parent] &&
        !node_plain_closed[parent] && indent > node_plain_base_indent[parent]) {
        append_plain_scalar(parent, text, source_line)
        return
    }
    if (parent && node_kind[parent] == "pending" &&
        trim(text) ~ /^[|>]([-+]?[1-9]?|[1-9][-+]?)$/) {
        node_kind[parent] = "scalar"
        node_value[parent] = ""
        node_type[parent] = "string"
        start_block(parent, trim(text), node_indent[parent], source_line)
        return
    }
    if (parent && node_kind[parent] == "pending" &&
        text != "-" && text !~ /^-[[:space:]]/ &&
        text != "?" && text !~ /^\?[[:space:]]/ &&
        text != ":" && text !~ /^:[[:space:]]/ &&
        !find_mapping_separator(text, 1)) {
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
        if (key_text ~ /^[|>]([-+]?[1-9]?|[1-9][-+]?)$/) {
            explicit_key[indent] = ""
            explicit_key_valid[indent] = 1
            explicit_key_last_line[indent] = source_line
            explicit_block_node = new_node("scalar", source_line, "", "string", "")
            explicit_block_indent = indent
            start_block(explicit_block_node, key_text, indent, source_line)
            return
        }
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

    separator = find_mapping_separator(clean, 1)
    if (separator) {
        parse_mapping_line(clean, indent, source_line)
        return
    }

    if ((indent != 0 && substr(trim(text), 1, 1) != "[" && substr(trim(text), 1, 1) != "{") ||
        (document_index in document_root)) {
        fail("unknown syntax on line " source_line)
    }
    root = parse_value(text, source_line, indent, 1, indent + 1)
    node_column[root] = indent + 1
    document_root[document_index] = root
    document_file_index[document_index] = current_input_file_index
    document_filename[document_index] = current_input_filename
    document_has_content[document_index] = 1
    parser_record_content(root, 0)
    if (block_active && block_node == root && indent == 0) {
        block_base_indent = -1
    }
    if (node_kind[root] == "scalar" && is_plain_scalar_source(text, source_line)) {
        node_plain_continuable[root] = 1
        node_plain_base_indent[root] = indent
        node_plain_closed[root] = strip_inline_comment(text) != trim(text)
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
    if (!index(value, "[") && !index(value, "{")) {
        return 0
    }
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

