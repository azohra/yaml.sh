function presentation_comment_position(value,    i, char, previous, quote, escaped, braces, brackets) {
    if (!index(value, "#")) {
        return 0
    }
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

function presentation_scalar_text(node, original,    quote, value, properties, remainder, space, token, rendered) {
    value = node_value[node]
    original = trim(original)
    properties = ""
    remainder = original
    while (substr(remainder, 1, 1) == "&" || substr(remainder, 1, 1) == "!") {
        space = match(remainder, /[[:space:]]/)
        if (!space) {
            break
        }
        token = substr(remainder, 1, space - 1)
        if (properties != "") {
            properties = properties " "
        }
        properties = properties token
        remainder = trim(substr(remainder, space + 1))
    }
    original = remainder
    if (node_type[node] != "string") {
        rendered = yaml_scalar_text(node)
        return properties == "" ? rendered : properties " " rendered
    }
    quote = sprintf("%c", 39)
    if (node_style[node] == "single") {
        gsub(quote, quote quote, value)
        rendered = quote value quote
    } else if (node_style[node] == "double") {
        rendered = json_quote(value)
    } else if (node_style[node] == "plain") {
        rendered = value
    } else if (substr(original, 1, 1) == quote && substr(original, length(original), 1) == quote) {
        gsub(quote, quote quote, value)
        rendered = quote value quote
    } else if (substr(original, 1, 1) == "\"") {
        rendered = json_quote(value)
    } else if (presentation_plain_safe(value)) {
        rendered = value
    } else {
        rendered = json_quote(value)
    }
    return properties == "" ? rendered : properties " " rendered
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

function presentation_has_flow_collection(value) {
    return (index(value, "[") && index(value, "]")) || (index(value, "{") && index(value, "}"))
}

function presentation_flow_owner(target,    current, parent, owner, line) {
    current = target
    if ((current in expression_missing_parent) && !expression_placeholder_attached[current]) {
        current = expression_missing_parent[current]
    }
    line = node_line[current]
    while (current) {
        if (node_style[current] == "flow") {
            owner = current
        }
        if (!(current in node_parent)) {
            break
        }
        parent = node_parent[current]
        if (!parent || (line && node_line[parent] != line && node_style[parent] != "flow")) {
            break
        }
        current = parent
    }
    return owner
}

function presentation_queue_comment_before(line, value, indent,    item) {
    item = ++presentation_comment_before_count[line]
    presentation_comment_before_value[line, item] = value
    presentation_comment_before_indent[line, item] = indent
}

function presentation_queue_comment_after(line, value, indent,    item) {
    item = ++presentation_comment_after_count[line]
    presentation_comment_after_value[line, item] = value
    presentation_comment_after_indent[line, item] = indent
}

function presentation_track_comment(node, property, as_key, value,    source, start, end, line, indent, parent, i) {
    if (!inplace_mode || !presentation_possible) return 0
    source = (node in node_origin) ? node_origin[node] : node
    if (presentation_flow_owner(source)) return 0

    if (as_key) {
        start = property == "head_comment" ? node_key_head_comment_start[source] : node_key_foot_comment_start[source]
        end = property == "head_comment" ? node_key_head_comment_end[source] : node_key_foot_comment_end[source]
    } else {
        start = property == "head_comment" ? node_head_comment_start[source] : node_foot_comment_start[source]
        end = property == "head_comment" ? node_head_comment_end[source] : node_foot_comment_end[source]
    }
    if (start) {
        if (!end) end = start
        for (i = start; i <= end; i++) {
            if (trim(raw_input_line[i]) !~ /^#/ || i in presentation_line_node || i in presentation_deleted_line) return 0
        }
        indent = indentation(raw_input_line[start], start)
        for (i = start; i <= end; i++) presentation_deleted_line[i] = 1
        if (value != "") presentation_queue_comment_before(start, value, indent)
        return 1
    }

    line = as_key && node_key_line[source] ? node_key_line[source] : node_line[source]
    if (line < 1) return 0
    indent = indentation(raw_input_line[line], line)
    if (as_key && property == "head_comment") {
        presentation_queue_comment_before(line, value, indent)
        return 1
    }
    if (property == "foot_comment") {
        line = presentation_span_end(source)
        presentation_queue_comment_after(line, value, indent)
        return 1
    }
    parent = (source in node_parent) ? node_parent[source] : 0
    if (!parent) {
        presentation_queue_comment_before(line, value, indent)
    } else if (node_kind[parent] == "sequence") {
        presentation_queue_comment_before(line, value, indent)
    } else if (node_kind[source] == "mapping" || node_kind[source] == "sequence") {
        presentation_queue_comment_after(line, value, indent + yaml_indent)
    } else {
        presentation_queue_comment_after(presentation_span_end(source), value, indent)
    }
    return 1
}

function presentation_track_owned_span(node,    line, end, i) {
    line = node_line[node]
    if (line < 1 || ((line in presentation_line_node) && presentation_line_node[line] != node)) {
        presentation_possible = 0
        return 0
    }
    end = line
    if (line in source_multiline_flow_end) {
        end = source_multiline_flow_end[line]
        for (i = line; i < end; i++) {
            if (strip_flow_line_comment(raw_input_line[i]) != trim(raw_input_line[i])) {
                presentation_possible = 0
                return 0
            }
        }
    } else if (line in source_multiline_scalar_end) {
        end = source_multiline_scalar_end[line]
    } else if (node_style[node] == "literal" || node_style[node] == "folded") {
        end = presentation_span_end(node)
    }
    presentation_line_node[line] = node
    presentation_line_end[line] = end
    return 1
}

function presentation_track_sequence_reorder(target, source,    parent, header, raw, text, target_end, serial, i, j, child, origin, found, previous_end) {
    if (node_kind[target] != "sequence" || node_kind[source] != "sequence" ||
        sequence_count[target] == 0 || sequence_count[target] != sequence_count[source]) {
        return 0
    }
    parent = (target in node_parent) ? node_parent[target] : 0
    header = node_line[target]
    if (!parent || node_kind[parent] != "mapping" || header < 1 || header in presentation_line_node ||
        header in presentation_deleted_line || header in presentation_reorder_count) {
        return 0
    }
    raw = raw_input_line[header]
    text = substr(raw, indentation(raw, header) + 1)
    if (!find_mapping_separator(text, 1) || presentation_has_flow_collection(text)) {
        return 0
    }

    serial = ++presentation_reorder_serial
    previous_end = header
    for (i = 1; i <= sequence_count[target]; i++) {
        child = sequence_child[target, i]
        if (node_line[child] <= header) {
            return 0
        }
        presentation_original_start[serial, child] = presentation_attached_start(child, previous_end + 1)
        previous_end = presentation_span_end(child)
    }
    target_end = presentation_span_end(target)
    for (i = 1; i <= sequence_count[source]; i++) {
        child = sequence_child[source, i]
        origin = node_origin[child]
        found = 0
        for (j = 1; j <= sequence_count[target]; j++) {
            if (sequence_child[target, j] == origin && !(serial SUBSEP origin in presentation_reorder_seen)) {
                found = j
                presentation_reorder_seen[serial, origin] = 1
                break
            }
        }
        if (!found) {
            return 0
        }
        presentation_reorder_start[header, i] = presentation_original_start[serial, origin]
        if (found < sequence_count[target]) {
            presentation_reorder_end[header, i] = presentation_original_start[serial, sequence_child[target, found + 1]] - 1
        } else {
            presentation_reorder_end[header, i] = target_end
        }
    }
    presentation_reorder_count[header] = sequence_count[source]
    for (i = header + 1; i <= target_end; i++) {
        presentation_deleted_line[i] = 1
        presentation_reorder_owned_line[i] = header
    }
    return 1
}

function presentation_track_sequence_append(target, source,    parent, header, first, after, raw, indent, i, child, origin, item) {
    if (node_kind[target] != "sequence" || node_kind[source] != "sequence" ||
        sequence_count[target] == 0 || sequence_count[source] <= sequence_count[target]) {
        return 0
    }
    parent = (target in node_parent) ? node_parent[target] : 0
    header = node_line[target]
    if (!parent || node_kind[parent] != "mapping" || header < 1 || header in presentation_line_node ||
        header in presentation_deleted_line || header in presentation_reorder_count) {
        return 0
    }
    raw = raw_input_line[header]
    if (presentation_has_flow_collection(raw)) {
        return 0
    }
    for (i = 1; i <= sequence_count[target]; i++) {
        child = sequence_child[source, i]
        origin = node_origin[child]
        if (origin != sequence_child[target, i]) {
            return 0
        }
    }
    first = node_line[sequence_child[target, 1]]
    if (first <= header) {
        return 0
    }
    raw = raw_input_line[first]
    indent = indentation(raw, first)
    if (substr(trim(raw), 1, 1) != "-") {
        return 0
    }
    after = presentation_span_end(target)
    for (i = sequence_count[target] + 1; i <= sequence_count[source]; i++) {
        item = ++presentation_sequence_insert_count[after]
        presentation_sequence_insert_node[after, item] = sequence_child[source, i]
        presentation_sequence_insert_indent[after, item] = indent
    }
    return 1
}

function presentation_track_mapping_reorder(target, source,    parent, header, raw, text, target_end, serial, i, j, child, origin, found, previous_end, key) {
    if (node_kind[target] != "mapping" || node_kind[source] != "mapping" ||
        mapping_count[target] == 0 || mapping_count[target] != mapping_count[source]) {
        return 0
    }
    parent = (target in node_parent) ? node_parent[target] : 0
    header = node_line[target]
    if (!parent || node_kind[parent] != "mapping" || header < 1 || header in presentation_line_node ||
        header in presentation_deleted_line || header in presentation_reorder_count) {
        return 0
    }
    raw = raw_input_line[header]
    text = substr(raw, indentation(raw, header) + 1)
    if (!find_mapping_separator(text, 1) || presentation_has_flow_collection(text)) {
        return 0
    }

    serial = ++presentation_reorder_serial
    previous_end = header
    for (i = 1; i <= mapping_count[target]; i++) {
        child = mapping_child[target, i]
        if (node_line[child] <= header) {
            return 0
        }
        presentation_original_start[serial, child] = presentation_attached_start(child, previous_end + 1)
        previous_end = presentation_span_end(child)
    }
    target_end = presentation_span_end(target)
    for (i = 1; i <= mapping_count[source]; i++) {
        child = mapping_child[source, i]
        origin = node_origin[child]
        key = mapping_key[source, i]
        found = 0
        for (j = 1; j <= mapping_count[target]; j++) {
            if (mapping_key[target, j] == key && mapping_child[target, j] == origin &&
                !(serial SUBSEP origin in presentation_reorder_seen)) {
                found = j
                presentation_reorder_seen[serial, origin] = 1
                break
            }
        }
        if (!found) {
            return 0
        }
        presentation_reorder_start[header, i] = presentation_original_start[serial, origin]
        if (found < mapping_count[target]) {
            presentation_reorder_end[header, i] = presentation_original_start[serial, mapping_child[target, found + 1]] - 1
        } else {
            presentation_reorder_end[header, i] = target_end
        }
    }
    presentation_reorder_count[header] = mapping_count[source]
    for (i = header + 1; i <= target_end; i++) {
        presentation_deleted_line[i] = 1
        presentation_reorder_owned_line[i] = header
    }
    return 1
}

function presentation_track_mapping_append(target, source,    first, after, raw, indent, i, child, origin, item, key) {
    if (node_kind[target] != "mapping" || node_kind[source] != "mapping" ||
        mapping_count[target] == 0 || mapping_count[source] <= mapping_count[target]) {
        return 0
    }
    for (i = 1; i <= mapping_count[target]; i++) {
        if (mapping_key[source, i] != mapping_key[target, i] || mapping_merge[source, i] != mapping_merge[target, i]) {
            return 0
        }
        child = mapping_child[source, i]
        origin = node_origin[child]
        if (origin != mapping_child[target, i]) {
            return 0
        }
    }
    first = node_line[mapping_child[target, 1]]
    if (first < 1) {
        return 0
    }
    raw = raw_input_line[first]
    if (presentation_has_flow_collection(raw)) {
        return 0
    }
    indent = indentation(raw, first)
    after = presentation_span_end(target)
    for (i = mapping_count[target] + 1; i <= mapping_count[source]; i++) {
        item = ++presentation_insert_count[after]
        key = mapping_key[source, i]
        presentation_insert_node[after, item] = mapping_child[source, i]
        presentation_insert_key[after, item] = key
        presentation_insert_indent[after, item] = indent
    }
    return 1
}

function presentation_track_replace(target, source,    line, raw, resolved_source, flow_owner) {
    if (!inplace_mode || !presentation_possible) {
        return
    }
    resolved_source = resolve_alias(source)
    flow_owner = presentation_flow_owner(target)
    if (flow_owner) {
        presentation_track_owned_span(flow_owner)
        return
    }
    if (node_kind[target] == "sequence" && node_kind[resolved_source] == "sequence") {
        if (presentation_track_sequence_reorder(target, resolved_source)) {
            return
        }
        if (presentation_track_sequence_append(target, resolved_source)) {
            return
        }
        presentation_possible = 0
        return
    }
    if (node_kind[target] == "mapping" && node_kind[resolved_source] == "mapping") {
        if (presentation_track_mapping_reorder(target, resolved_source)) {
            return
        }
        if (presentation_track_mapping_append(target, resolved_source)) {
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
    if (node_kind[target] == "scalar" && node_kind[resolved_source] == "scalar" &&
        (node_style[target] == "literal" || node_style[target] == "folded" ||
         line in source_multiline_scalar_end)) {
        presentation_track_owned_span(target)
        return
    }
    if (line < 1 || node_kind[target] != "scalar" || node_kind[resolved_source] != "scalar" ||
        raw ~ /(^|:[[:space:]]*)[|>][+-]?[[:space:]]*(#|$)/ || presentation_has_flow_collection(raw) || raw ~ /:[[:space:]]*[!&]/) {
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
    if (presentation_has_flow_collection(raw)) {
        presentation_possible = 0
        return
    }
    indent = indentation(raw, first_line)
    i = ++presentation_insert_count[after]
    presentation_insert_node[after, i] = target
    presentation_insert_key[after, i] = key
    presentation_insert_indent[after, i] = indent
}

function presentation_span_end(target,    start, start_indent, line, raw, raw_indent, end, text, lookahead, following, following_indent) {
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
        text = trim(raw)
        if (node_kind[target] == "sequence" && raw_indent == start_indent) {
            if (text == "-" || text ~ /^-[[:space:]]/) {
                end = line
                continue
            }
            if (text ~ /^#/) {
                lookahead = line + 1
                while (lookahead <= NR && (trim(raw_input_line[lookahead]) == "" || trim(raw_input_line[lookahead]) ~ /^#/)) {
                    lookahead++
                }
                if (lookahead <= NR) {
                    following = raw_input_line[lookahead]
                    following_indent = indentation(following, lookahead)
                    following = trim(following)
                    if (following_indent == start_indent && (following == "-" || following ~ /^-[[:space:]]/)) {
                        end = line
                        continue
                    }
                }
            }
        }
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

function presentation_track_delete(target,    parent, line, end, raw, indent, text, i, sibling, flow_owner, lower, previous) {
    if (!inplace_mode || !presentation_possible) {
        return
    }
    flow_owner = presentation_flow_owner(target)
    if (flow_owner) {
        presentation_track_owned_span(flow_owner)
        return
    }
    parent = (target in node_parent) ? node_parent[target] : 0
    line = node_line[target]
    if (!parent || line < 1 || line in presentation_line_node) {
        presentation_possible = 0
        return
    }
    raw = raw_input_line[line]
    indent = indentation(raw, line)
    text = substr(raw, indent + 1)
    if (presentation_has_flow_collection(text)) {
        presentation_possible = 0
        return
    }
    if (node_kind[parent] == "mapping") {
        lower = node_line[parent] + 1
        for (i = 1; i <= mapping_count[parent]; i++) {
            sibling = mapping_child[parent, i]
            if (sibling != target && node_line[sibling] == line) {
                presentation_possible = 0
                return
            }
            if (sibling == target && i > 1) {
                previous = mapping_child[parent, i - 1]
                lower = presentation_span_end(previous) + 1
            }
        }
    } else if (node_kind[parent] == "sequence") {
        lower = node_line[parent] + 1
        for (i = 1; i <= sequence_count[parent]; i++) {
            sibling = sequence_child[parent, i]
            if (sibling != target && node_line[sibling] == line) {
                presentation_possible = 0
                return
            }
            if (sibling == target && i > 1) {
                previous = sequence_child[parent, i - 1]
                lower = presentation_span_end(previous) + 1
            }
        }
    } else {
        presentation_possible = 0
        return
    }
    end = presentation_span_end(target)
    line = presentation_attached_start(target, lower)
    for (i = line; i <= end; i++) {
        presentation_deleted_line[i] = 1
    }
}

function emit_presented_line(line, node,    raw, indent, text, separator, rest, prefix, leading, comment_at, token, suffix, body, trailing, rendered, content_indent, end, span_text, source_line) {
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
    if (node_line_comment_modified[node]) {
        suffix = node_line_comment[node] == "" ? "" : " # " node_line_comment[node]
    }
    end = presentation_line_end[line]
    if (end > line && suffix == "") {
        span_text = raw
        for (source_line = line + 1; source_line <= end; source_line++) {
            span_text = span_text "\n" raw_input_line[source_line]
        }
        comment_at = presentation_comment_position(span_text)
        if (comment_at && !index(substr(span_text, comment_at), "\n")) {
            suffix = " " substr(span_text, comment_at)
        }
    }
    if (node_kind[node] == "mapping" || node_kind[node] == "sequence") {
        rendered = yaml_inline_node(node)
        if (rendered == "") {
            presentation_possible = 0
            return
        }
        print prefix leading rendered suffix
        return
    }
    if (node_kind[node] == "scalar" && (node_style[node] == "literal" || node_style[node] == "folded")) {
        rendered = yaml_properties(node)
        if (rendered != "") {
            rendered = rendered " "
        }
        print prefix leading rendered yaml_block_indicator(node) suffix
        content_indent = indent + yaml_indent
        if (end > line && trim(raw_input_line[line + 1]) != "") {
            content_indent = indentation(raw_input_line[line + 1], line + 1)
        }
        emit_yaml_block_scalar(node, content_indent)
        return
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
    emit_yaml_collection(node, indent + yaml_indent)
}

function emit_presented_sequence_insert(node, indent,    inline, properties) {
    printf "%s-", yaml_spaces(indent)
    if (node_kind[node] == "scalar" && (node_style[node] == "literal" || node_style[node] == "folded")) {
        properties = yaml_properties(node)
        printf " %s%s%s\n", (properties == "" ? "" : properties " "), yaml_block_indicator(node), yaml_line_comment(node)
        emit_yaml_block_scalar(node, indent + yaml_indent)
        return
    }
    inline = yaml_inline_node(node)
    if (inline != "") {
        printf " %s%s\n", inline, yaml_line_comment(node)
        return
    }
    properties = yaml_properties(node)
    if (properties != "") {
        printf " %s", properties
    }
    printf "%s\n", yaml_line_comment(node)
    emit_yaml_collection(node, indent + yaml_indent)
}

function emit_presented_reorder(line,    item, source_line, start, end, replacement_end) {
    for (item = 1; item <= presentation_reorder_count[line]; item++) {
        start = presentation_reorder_start[line, item]
        end = presentation_reorder_end[line, item]
        for (source_line = start; source_line <= end; source_line++) {
            if (source_line in presentation_line_node) {
                emit_presented_line(source_line, presentation_line_node[source_line])
                replacement_end = presentation_line_end[source_line]
                if (replacement_end > source_line) {
                    source_line = replacement_end
                }
            } else {
                print raw_input_line[source_line]
            }
        }
    }
}

function emit_presented_comment(value, indent,    count, i, lines, separator) {
    count = split(value, lines, /\n/)
    for (i = 1; i <= count; i++) {
        separator = lines[i] == "" ? "" : " "
        printf "%s#%s%s\n", yaml_spaces(indent), separator, lines[i]
        delete lines[i]
    }
}

function emit_preserved_input(start_line, end_line,    line, i, replacement_end) {
    if (!start_line) {
        start_line = 1
    }
    if (!end_line) {
        end_line = NR
    }
    for (line = start_line; line <= end_line; line++) {
        for (i = 1; i <= presentation_comment_before_count[line]; i++) {
            emit_presented_comment(presentation_comment_before_value[line, i], presentation_comment_before_indent[line, i])
        }
        if (line in presentation_deleted_line) {
        } else if (line in presentation_line_node) {
            emit_presented_line(line, presentation_line_node[line])
            replacement_end = presentation_line_end[line]
            if (replacement_end > line) {
                line = replacement_end
            }
        } else {
            print raw_input_line[line]
        }
        if (line in presentation_reorder_count) {
            emit_presented_reorder(line)
        }
        for (i = 1; i <= presentation_sequence_insert_count[line]; i++) {
            emit_presented_sequence_insert(presentation_sequence_insert_node[line, i], presentation_sequence_insert_indent[line, i])
        }
        for (i = 1; i <= presentation_insert_count[line]; i++) {
            emit_presented_insert(presentation_insert_key[line, i], presentation_insert_node[line, i], presentation_insert_indent[line, i])
        }
        for (i = 1; i <= presentation_comment_after_count[line]; i++) {
            emit_presented_comment(presentation_comment_after_value[line, i], presentation_comment_after_indent[line, i])
        }
    }
}

function source_edit_add(kind, start, end,    edit) {
    edit = ++source_edit_count
    source_edit_kind[edit] = kind
    source_edit_start[edit] = start
    source_edit_end[edit] = end
}

function source_edit_compile(start_line, end_line, file,    line, run_start, run_end, replacement_end, i, last_end, comment_replace) {
    if (!presentation_possible) {
        source_edit_file_count[file] = 0
        return 0
    }
    if (!start_line) {
        start_line = 1
    }
    if (!end_line) {
        end_line = NR
    }
    source_edit_count = 0
    for (line = start_line; line <= end_line; line++) {
        if (line in presentation_line_node) {
            replacement_end = presentation_line_end[line]
            if (!replacement_end) {
                replacement_end = line
            }
            if (line in presentation_reorder_owned_line) {
                for (i = line; i <= replacement_end; i++) {
                    if (presentation_reorder_owned_line[i] != presentation_reorder_owned_line[line]) {
                        presentation_possible = 0
                        source_edit_file_count[file] = 0
                        return 0
                    }
                }
                source_edit_add("nested-replace", line, replacement_end)
                line = replacement_end
                continue
            }
            for (i = line; i <= replacement_end; i++) {
                if ((i != line && i in presentation_line_node) ||
                    i in presentation_deleted_line || i in presentation_reorder_count ||
                    ((presentation_sequence_insert_count[i] || presentation_insert_count[i]) && i != replacement_end)) {
                    presentation_possible = 0
                    source_edit_file_count[file] = 0
                    return 0
                }
            }
            source_edit_add("replace", line, replacement_end)
            line = replacement_end
            continue
        }
        if (line in presentation_deleted_line) {
            if (line in presentation_reorder_owned_line) {
                continue
            }
            run_start = line
            run_end = line
            while (run_end + 1 <= end_line && (run_end + 1) in presentation_deleted_line &&
                !((run_end + 1) in presentation_reorder_owned_line)) {
                run_end++
            }
            comment_replace = 0
            for (i = run_start; i <= run_end; i++) {
                if (presentation_comment_before_count[i] || presentation_comment_after_count[i] ||
                    presentation_sequence_insert_count[i] || presentation_insert_count[i]) comment_replace = 1
            }
            source_edit_add(comment_replace ? "replace" : "delete", run_start, run_end)
            line = run_end
            continue
        }
        if (line in presentation_reorder_count) {
            source_edit_add("reorder", line, line)
        }
        if (presentation_sequence_insert_count[line] || presentation_insert_count[line]) {
            source_edit_add("insert", line, line)
        }
        if (presentation_comment_before_count[line] || presentation_comment_after_count[line]) {
            source_edit_add("insert", line, line)
        }
    }
    last_end = 0
    for (i = 1; i <= source_edit_count; i++) {
        if (source_edit_kind[i] != "insert" && source_edit_start[i] <= last_end) {
            presentation_possible = 0
            source_edit_file_count[file] = 0
            return 0
        }
        if (source_edit_kind[i] != "insert") {
            last_end = source_edit_end[i]
        }
    }
    source_edit_file_count[file] = source_edit_count
    return source_edit_count
}

