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
        collection = mapping_key_set(resolved)
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
        } else if (substr(tag, 1, 1) != "!") {
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

function yaml_scalar_text(node,    value, properties, lowered, quote) {
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
    if (node_style[node] == "single") {
        quote = SQ
        gsub(quote, quote quote, value)
        return properties quote value quote
    }
    if (node_style[node] == "plain" && presentation_plain_safe(value)) {
        return properties value
    }
    return properties json_quote(value)
}

function yaml_block_indicator(node,    value, trailing) {
    value = node_value[node]
    trailing = 0
    while (length(value) > trailing && substr(value, length(value) - trailing, 1) == "\n") {
        trailing++
    }
    return (node_style[node] == "folded" ? ">" : "|") (trailing == 0 ? "-" : (trailing == 1 ? "" : "+"))
}

function emit_yaml_block_scalar(node, indent,    value, position, line, folded) {
    value = node_value[node]
    folded = node_style[node] == "folded"
    while ((position = index(value, "\n"))) {
        line = substr(value, 1, position - 1)
        print yaml_spaces(indent) line
        if (folded) {
            print ""
        }
        value = substr(value, position + 1)
    }
    if (value != "") {
        print yaml_spaces(indent) value
    }
}

function yaml_flow_node(node,    result, i, key) {
    if (node_kind[node] == "scalar" || node_kind[node] == "alias") {
        return yaml_scalar_text(node)
    }
    if (node_kind[node] == "sequence") {
        result = "["
        for (i = 1; i <= sequence_count[node]; i++) {
            if (i > 1) result = result ", "
            result = result yaml_flow_node(sequence_child[node, i])
        }
        return result "]"
    }
    result = "{"
    for (i = 1; i <= mapping_count[node]; i++) {
        if (i > 1) result = result ", "
        key = mapping_key[node, i]
        result = result json_quote(key) ": " yaml_flow_node(mapping_child[node, i])
    }
    return result "}"
}

function yaml_line_comment(node) {
    return (node in node_line_comment) && node_line_comment[node] != "" ? " # " node_line_comment[node] : ""
}

function yaml_mapping_line_comment(node) {
    return (node in node_key_line_comment) && node_key_line_comment[node] != "" ? " # " node_key_line_comment[node] : yaml_line_comment(node)
}

function emit_yaml_comment(value, indent,    count, i, lines, separator) {
    count = split(value, lines, /\n/)
    for (i = 1; i <= count; i++) {
        separator = lines[i] == "" ? "" : " "
        printf "%s#%s%s\n", yaml_spaces(indent), separator, lines[i]
        delete lines[i]
    }
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
    if (node_style[node] == "flow") {
        return properties yaml_flow_node(node)
    }
    return ""
}

function emit_yaml_collection(node, indent,    i, child, inline, properties, key) {
    if (node_kind[node] == "mapping") {
        for (i = 1; i <= mapping_count[node]; i++) {
            key = mapping_key[node, i]
            child = mapping_child[node, i]
            emit_yaml_comment(node_key_head_comment[child], indent)
            if (mapping_merge[node, i]) {
                printf "%s<<:", yaml_spaces(indent)
            } else {
                printf "%s%s:", yaml_spaces(indent), json_quote(key)
            }
            if (node_kind[child] == "scalar" && (node_style[child] == "literal" || node_style[child] == "folded")) {
                properties = yaml_properties(child)
                printf " %s%s%s\n", (properties == "" ? "" : properties " "), yaml_block_indicator(child), yaml_mapping_line_comment(child)
                emit_yaml_block_scalar(child, indent + yaml_indent)
                emit_yaml_comment(node_foot_comment[child], indent)
                emit_yaml_comment(node_head_comment[child], indent)
                emit_yaml_comment(node_key_foot_comment[child], indent)
                continue
            }
            inline = yaml_inline_node(child)
            if (inline != "") {
                printf " %s%s\n", inline, yaml_mapping_line_comment(child)
            } else {
                properties = yaml_properties(child)
                if (properties != "") {
                    printf " %s", properties
                }
                printf "%s\n", yaml_mapping_line_comment(child)
                emit_yaml_collection(child, indent + yaml_indent)
            }
            emit_yaml_comment(node_foot_comment[child], indent)
            emit_yaml_comment(node_head_comment[child], indent)
            emit_yaml_comment(node_key_foot_comment[child], indent)
        }
        return
    }
    for (i = 1; i <= sequence_count[node]; i++) {
        child = sequence_child[node, i]
        emit_yaml_comment(node_head_comment[child], indent)
        printf "%s-", yaml_spaces(indent)
        if (node_kind[child] == "scalar" && (node_style[child] == "literal" || node_style[child] == "folded")) {
            properties = yaml_properties(child)
            printf " %s%s%s\n", (properties == "" ? "" : properties " "), yaml_block_indicator(child), yaml_line_comment(child)
            emit_yaml_block_scalar(child, indent + yaml_indent)
            emit_yaml_comment(node_foot_comment[child], indent)
            continue
        }
        inline = yaml_inline_node(child)
        if (inline != "") {
            printf " %s%s\n", inline, yaml_line_comment(child)
        } else {
            properties = yaml_properties(child)
            if (properties != "") {
                printf " %s", properties
            }
            printf "%s\n", yaml_line_comment(child)
            emit_yaml_collection(child, indent + yaml_indent)
        }
        emit_yaml_comment(node_foot_comment[child], indent)
    }
}

function emit_yaml(node,    inline, properties) {
    emit_yaml_comment(node_head_comment[node], 0)
    if (node_kind[node] == "scalar" && (node_style[node] == "literal" || node_style[node] == "folded")) {
        properties = yaml_properties(node)
        print (properties == "" ? "" : properties " ") yaml_block_indicator(node) yaml_line_comment(node)
        emit_yaml_block_scalar(node, yaml_indent)
        emit_yaml_comment(node_foot_comment[node], 0)
        return
    }
    inline = yaml_inline_node(node)
    if (inline != "") {
        print inline yaml_line_comment(node)
        emit_yaml_comment(node_foot_comment[node], 0)
        return
    }
    properties = yaml_properties(node)
    if (properties != "") {
        print properties
    }
    emit_yaml_collection(node, 0)
    emit_yaml_comment(node_foot_comment[node], 0)
}

