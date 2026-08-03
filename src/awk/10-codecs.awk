function codec_initialize(    i, char) {
    codec_hex = "0123456789ABCDEF"
    codec_base64_alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    codec_toml_nul_marker = SUBSEP "YSH_TOML_NUL" SUBSEP
    for (i = 1; i <= 255; i++) {
        char = sprintf("%c", i)
        codec_byte_value[char] = i
    }
    for (i = 1; i <= length(codec_base64_alphabet); i++) {
        codec_base64_value[substr(codec_base64_alphabet, i, 1)] = i - 1
    }
    codec_random_state = (shuffle_seed + 0) % 2147483647
    if (codec_random_state <= 0) codec_random_state = 1
}

function codec_byte(char) {
    return codec_byte_value[char] + 0
}

function codec_base64_encode(value,    result, i, first, second, third, remaining) {
    result = ""
    for (i = 1; i <= length(value); i += 3) {
        remaining = length(value) - i + 1
        first = codec_byte(substr(value, i, 1))
        second = remaining > 1 ? codec_byte(substr(value, i + 1, 1)) : 0
        third = remaining > 2 ? codec_byte(substr(value, i + 2, 1)) : 0
        result = result substr(codec_base64_alphabet, int(first / 4) + 1, 1)
        result = result substr(codec_base64_alphabet, ((first % 4) * 16 + int(second / 16)) + 1, 1)
        result = result (remaining > 1 ? substr(codec_base64_alphabet, ((second % 16) * 4 + int(third / 64)) + 1, 1) : "=")
        result = result (remaining > 2 ? substr(codec_base64_alphabet, (third % 64) + 1, 1) : "=")
    }
    return result
}

function codec_base64_decode(value,    result, clean, i, first, second, third, fourth, char, padding, byte) {
    clean = value
    gsub(/[[:space:]]/, "", clean)
    if (length(clean) % 4 != 0) fail("invalid base64 length")
    result = ""
    for (i = 1; i <= length(clean); i += 4) {
        padding = 0
        char = substr(clean, i, 1)
        if (!(char in codec_base64_value)) fail("invalid base64 character")
        first = codec_base64_value[char]
        char = substr(clean, i + 1, 1)
        if (!(char in codec_base64_value)) fail("invalid base64 character")
        second = codec_base64_value[char]
        char = substr(clean, i + 2, 1)
        if (char == "=") {
            third = 0
            padding = 2
        } else {
            if (!(char in codec_base64_value)) fail("invalid base64 character")
            third = codec_base64_value[char]
        }
        char = substr(clean, i + 3, 1)
        if (char == "=") {
            fourth = 0
            if (!padding) padding = 1
        } else {
            if (padding || !(char in codec_base64_value)) fail("invalid base64 padding")
            fourth = codec_base64_value[char]
        }
        if (padding && i + 3 != length(clean)) fail("base64 padding must end the input")
        if (padding == 2 && second % 16) fail("invalid base64 padding bits")
        if (padding == 1 && third % 4) fail("invalid base64 padding bits")
        byte = first * 4 + int(second / 16)
        if (!byte) fail("decoded base64 contains a NUL byte")
        result = result sprintf("%c", byte)
        if (padding < 2) {
            byte = (second % 16) * 16 + int(third / 4)
            if (!byte) fail("decoded base64 contains a NUL byte")
            result = result sprintf("%c", byte)
        }
        if (!padding) {
            byte = (third % 4) * 64 + fourth
            if (!byte) fail("decoded base64 contains a NUL byte")
            result = result sprintf("%c", byte)
        }
    }
    return result
}

function codec_uri_encode(value,    result, i, char, byte) {
    result = ""
    for (i = 1; i <= length(value); i++) {
        char = substr(value, i, 1)
        if (char ~ /^[A-Za-z0-9_.~-]$/) {
            result = result char
        } else if (char == " ") {
            result = result "+"
        } else {
            byte = codec_byte(char)
            result = result "%" substr(codec_hex, int(byte / 16) + 1, 1) substr(codec_hex, (byte % 16) + 1, 1)
        }
    }
    return result
}

function codec_uri_decode(value,    result, i, char, digits, byte) {
    result = ""
    for (i = 1; i <= length(value); i++) {
        char = substr(value, i, 1)
        if (char == "+") {
            result = result " "
        } else if (char == "%") {
            digits = substr(value, i + 1, 2)
            if (length(digits) != 2 || digits !~ /^[0-9A-Fa-f][0-9A-Fa-f]$/) fail("invalid URI escape")
            byte = base_integer(digits, 16) + 0
            if (!byte) fail("decoded URI contains a NUL byte")
            result = result sprintf("%c", byte)
            i += 2
        } else {
            result = result char
        }
    }
    return result
}

function codec_shell_encode(value,    quote, result, quoted, i, char) {
    quote = sprintf("%c", 39)
    result = ""
    for (i = 1; i <= length(value); i++) {
        char = substr(value, i, 1)
        if (char == quote) {
            if (quoted) {
                result = result quote
                quoted = 0
            }
            result = result "\\" quote
        } else if (quoted) {
            result = result char
        } else if (char ~ /^[A-Za-z0-9_.,:+=\/@%-]$/) {
            result = result char
        } else {
            result = result quote char
            quoted = 1
        }
    }
    if (quoted) result = result quote
    return result
}

function codec_props_scalar(value,    escaped) {
    escaped = value
    gsub(/\\/, "\\\\", escaped)
    gsub(/\n/, "\\n", escaped)
    gsub(/\r/, "\\r", escaped)
    gsub(/\t/, "\\t", escaped)
    if (escaped ~ /^[[:space:]]/ || escaped ~ /[[:space:]]$/) escaped = json_quote(value)
    return escaped
}

function codec_props_walk(node, path,    resolved, result, i, child, next_path, key) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] == "scalar") {
        if (path == "") fail("properties encoding requires a mapping or sequence root")
        return path " = " codec_props_scalar(node_type[resolved] == "null" ? "null" : node_value[resolved]) "\n"
    }
    result = ""
    if (node_kind[resolved] == "sequence") {
        for (i = 1; i <= sequence_count[resolved]; i++) {
            next_path = path == "" ? (i - 1) : path "." (i - 1)
            result = result codec_props_walk(sequence_child[resolved, i], next_path)
        }
        return result
    }
    for (i = 1; i <= mapping_count[resolved]; i++) {
        if (mapping_merge[resolved, i]) continue
        key = mapping_key[resolved, i]
        if (index(key, "\n") || index(key, "\r") || index(key, "=")) fail("property keys cannot contain newlines or equals signs")
        next_path = path == "" ? key : path "." key
        child = mapping_child[resolved, i]
        result = result codec_props_walk(child, next_path)
    }
    return result
}

function codec_props_assign(root, path, value,    count, parts, current, i, index_value, child, wanted_kind) {
    count = split(path, parts, /\./)
    if (!count || parts[1] == "") fail("property key cannot be empty")
    current = root
    for (i = 1; i <= count; i++) {
        if (node_kind[current] == "mapping") {
            child = mapping_lookup(current, parts[i])
            if (i == count) {
                if (child) fail("duplicate property key: " path)
                add_mapping(current, parts[i], expression_scalar(value, "string"), 0, 0)
                break
            }
            wanted_kind = parts[i + 1] ~ /^(0|[1-9][0-9]*)$/ ? "sequence" : "mapping"
            if (!child) {
                child = new_node(wanted_kind, 0, "", "", "")
                add_mapping(current, parts[i], child, 0, 0)
            } else if (node_kind[child] != wanted_kind) fail("conflicting property path: " path)
            current = child
        } else if (node_kind[current] == "sequence") {
            if (parts[i] !~ /^(0|[1-9][0-9]*)$/) fail("property array segment must be a non-negative integer: " path)
            index_value = parts[i] + 1
            while (sequence_count[current] < index_value) add_sequence(current, expression_null(), 0)
            child = sequence_child[current, index_value]
            if (i == count) {
                if (node_type[child] != "null" || node_kind[child] != "scalar") fail("duplicate property key: " path)
                child = expression_scalar(value, "string")
                sequence_child[current, index_value] = child
                node_parent[child] = current
                node_parent_edge[child] = "index " (index_value - 1)
                break
            }
            wanted_kind = parts[i + 1] ~ /^(0|[1-9][0-9]*)$/ ? "sequence" : "mapping"
            if (node_kind[child] == "scalar" && node_type[child] == "null") {
                child = new_node(wanted_kind, 0, "", "", "")
                sequence_child[current, index_value] = child
                node_parent[child] = current
                node_parent_edge[child] = "index " (index_value - 1)
            } else if (node_kind[child] != wanted_kind) fail("conflicting property path: " path)
            current = child
        } else fail("conflicting property path: " path)
    }
    for (i = 1; i <= count; i++) delete parts[i]
}

function codec_props_decode(value,    root, remaining, newline, line, separator, key, item) {
    root = new_node("mapping", 0, "", "", "")
    remaining = value
    while (remaining != "") {
        newline = index(remaining, "\n")
        if (newline) {
            line = substr(remaining, 1, newline - 1)
            remaining = substr(remaining, newline + 1)
        } else {
            line = remaining
            remaining = ""
        }
        sub(/\r$/, "", line)
        if (line ~ /^[[:space:]]*$/ || line ~ /^[[:space:]]*[#!]/) continue
        separator = index(line, "=")
        if (!separator) separator = index(line, ":")
        if (!separator) {
            if (!match(line, /[[:space:]]/)) fail("property entry requires a separator")
            separator = RSTART
        }
        key = trim(substr(line, 1, separator - 1))
        item = trim(substr(line, separator + 1))
        codec_props_assign(root, key, item)
    }
    return root
}

function codec_delimited_cell(node, separator,    resolved, value, quote, escaped) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] != "scalar") fail("CSV and TSV encoding requires scalar cells")
    value = node_type[resolved] == "null" ? "null" : node_value[resolved]
    quote = sprintf("%c", 34)
    if (index(value, separator) || index(value, quote) || index(value, "\n") || index(value, "\r") ||
        value ~ /^[[:space:]]/ || value ~ /[[:space:]]$/) {
        escaped = value
        gsub(quote, quote quote, escaped)
        return quote escaped quote
    }
    return value
}

function codec_delimited_row(node, separator,    resolved, result, i) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] != "sequence") fail("CSV and TSV rows must be arrays")
    result = ""
    for (i = 1; i <= sequence_count[resolved]; i++) {
        if (i > 1) result = result separator
        result = result codec_delimited_cell(sequence_child[resolved, i], separator)
    }
    return result
}

function codec_delimited_encode(node, separator,    resolved, first, result, i, j, row, child, key) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] != "sequence") fail("CSV and TSV encoding requires an array")
    if (!sequence_count[resolved]) return ""
    first = resolve_alias(sequence_child[resolved, 1])
    if (node_kind[first] == "scalar") return codec_delimited_row(resolved, separator)
    result = ""
    if (node_kind[first] == "mapping") {
        for (j = 1; j <= mapping_count[first]; j++) {
            if (mapping_merge[first, j]) continue
            if (result != "") result = result separator
            result = result codec_delimited_cell(expression_scalar(mapping_key[first, j], "string"), separator)
        }
        for (i = 1; i <= sequence_count[resolved]; i++) {
            row = resolve_alias(sequence_child[resolved, i])
            if (node_kind[row] != "mapping") fail("CSV and TSV object rows must be homogeneous")
            result = result "\n"
            child = 0
            for (j = 1; j <= mapping_count[first]; j++) {
                if (mapping_merge[first, j]) continue
                if (child++) result = result separator
                key = mapping_key[first, j]
                row = resolve_alias(sequence_child[resolved, i])
                result = result codec_delimited_cell(mapping_lookup(row, key) ? mapping_lookup(row, key) : expression_scalar("", "string"), separator)
            }
        }
        return result
    }
    for (i = 1; i <= sequence_count[resolved]; i++) {
        if (i > 1) result = result "\n"
        result = result codec_delimited_row(sequence_child[resolved, i], separator)
    }
    return result
}

function codec_delimited_finish_field(row, column, value) {
    codec_delimited_field[row, column] = value
}

function codec_delimited_decode(value, separator,    row, column, field, quoted, after_quote, i, char, next_char, rows, columns, root, item, header, type, j, child) {
    row = 1
    column = 1
    field = ""
    for (i = 1; i <= length(value) + 1; i++) {
        char = i <= length(value) ? substr(value, i, 1) : "\n"
        next_char = i < length(value) ? substr(value, i + 1, 1) : ""
        if (quoted) {
            if (char == "\"" && next_char == "\"") {
                field = field "\""
                i++
            } else if (char == "\"") {
                quoted = 0
                after_quote = 1
            } else field = field char
            continue
        }
        if (!after_quote && field == "" && char == "\"") {
            quoted = 1
            continue
        }
        if (after_quote && char != separator && char != "\n" && char != "\r") fail("unexpected character after quoted CSV field")
        if (char == separator) {
            codec_delimited_finish_field(row, column++, field)
            field = ""
            after_quote = 0
        } else if (char == "\n" || char == "\r") {
            if (char == "\r" && next_char == "\n") i++
            codec_delimited_finish_field(row, column, field)
            codec_delimited_columns[row] = column
            rows = row++
            column = 1
            field = ""
            after_quote = 0
        } else {
            if (char == "\"") fail("quote inside unquoted CSV field")
            field = field char
        }
    }
    if (quoted) fail("unterminated quoted CSV field")
    if (rows > 1 && codec_delimited_columns[rows] == 1 && codec_delimited_field[rows, 1] == "" && substr(value, length(value), 1) ~ /[\r\n]/) rows--
    root = new_node("sequence", 0, "", "", "")
    if (!rows) return root
    columns = codec_delimited_columns[1]
    for (j = 1; j <= columns; j++) {
        header = codec_delimited_field[1, j]
        if (header == "") fail("CSV and TSV headers cannot be empty")
        codec_delimited_header[j] = header
    }
    for (i = 2; i <= rows; i++) {
        if (codec_delimited_columns[i] > columns) fail("CSV and TSV rows cannot have more fields than the header")
        item = new_node("mapping", 0, "", "", "")
        for (j = 1; j <= columns; j++) {
            field = j <= codec_delimited_columns[i] ? codec_delimited_field[i, j] : ""
            type = scalar_type(field, "", field)
            child = expression_scalar(field, type)
            add_mapping(item, codec_delimited_header[j], child, 0, 0)
        }
        add_sequence(root, item, 0)
    }
    for (i = 1; i <= rows; i++) {
        for (j = 1; j <= codec_delimited_columns[i]; j++) delete codec_delimited_field[i, j]
        delete codec_delimited_columns[i]
    }
    for (j = 1; j <= columns; j++) delete codec_delimited_header[j]
    return root
}

function codec_strip_comment(value, marker,    result, i, char, quote, escaped, triple, next_three, quote_count) {
    result = ""
    quote = ""
    for (i = 1; i <= length(value); i++) {
        char = substr(value, i, 1)
        next_three = substr(value, i, 3)
        if (quote != "") {
            if (triple && next_three == quote quote quote) {
                quote_count = 3
                while (quote_count < 5 && substr(value, i + quote_count, 1) == quote) quote_count++
                result = result substr(value, i, quote_count)
                i += quote_count - 1
                quote = ""
                triple = 0
            } else {
                result = result char
                if (quote == "\"" && char == "\\" && !escaped) escaped = 1
                else {
                    if (!triple && char == quote && !escaped) quote = ""
                    escaped = 0
                }
            }
        } else if (next_three == "\"\"\"" || next_three == "'''") {
            quote = char
            triple = 1
            result = result next_three
            i += 2
        } else if (char == "\"" || char == "'") {
            quote = char
            result = result char
        } else if (index(marker, char)) {
            while (i <= length(value) && substr(value, i, 1) != "\n") i++
            if (i <= length(value)) result = result "\n"
        } else {
            result = result char
        }
    }
    return trim_right_horizontal(result)
}

function codec_toml_complete(value,    i, char, next_three, quote, triple, escaped, brackets, braces, quote_count) {
    for (i = 1; i <= length(value); i++) {
        char = substr(value, i, 1)
        next_three = substr(value, i, 3)
        if (quote != "") {
            if (triple) {
                if (next_three == quote quote quote) {
                    quote_count = 3
                    while (quote_count < 5 && substr(value, i + quote_count, 1) == quote) quote_count++
                    quote = ""
                    triple = 0
                    i += quote_count - 1
                } else if (quote == "\"" && char == "\\") {
                    i++
                }
            } else if (quote == "\"" && char == "\\" && !escaped) {
                escaped = 1
            } else {
                if (char == quote && !escaped) quote = ""
                escaped = 0
            }
            continue
        }
        if (next_three == "\"\"\"" || next_three == "'''" ) {
            quote = char
            triple = 1
            i += 2
        } else if (char == "\"" || char == "'") quote = char
        else if (char == "#") {
            while (i <= length(value) && substr(value, i, 1) != "\n") i++
        }
        else if (char == "[") brackets++
        else if (char == "]") brackets--
        else if (char == "{") braces++
        else if (char == "}") braces--
        if (brackets < 0 || braces < 0) return 0
    }
    return quote == "" && brackets == 0 && braces == 0
}

function codec_toml_next_statement(    newline, line, clean, statement, separator, complete) {
    statement = ""
    separator = ""
    while (codec_toml_remaining != "") {
        newline = index(codec_toml_remaining, "\n")
        if (newline) {
            line = substr(codec_toml_remaining, 1, newline - 1)
            codec_toml_remaining = substr(codec_toml_remaining, newline + 1)
        } else {
            line = codec_toml_remaining
            codec_toml_remaining = ""
        }
        sub(/\r$/, "", line)
        # Only strip comments once the whole statement is understood.  A # in a
        # multiline string is data, and line-at-a-time stripping loses that fact.
        clean = line
        if (statement == "" && trim(clean) == "") continue
        statement = statement separator clean
        separator = "\n"
        if (codec_toml_complete(statement)) {
            complete = trim(codec_strip_comment(statement, "#"))
            if (complete != "") return complete
            statement = ""
            separator = ""
        }
    }
    if (statement != "") fail("unterminated TOML statement")
    return ""
}

function codec_toml_find_equals(value, start,    i, char, quote, escaped) {
    quote = ""
    for (i = start; i <= length(value); i++) {
        char = substr(value, i, 1)
        if (quote != "") {
            if (quote == "\"" && char == "\\" && !escaped) escaped = 1
            else {
                if (char == quote && !escaped) quote = ""
                escaped = 0
            }
        } else if (char == "\"" || char == "'") quote = char
        else if (char == "=") return i
    }
    return 0
}

function codec_toml_inline_has_newline(value, start,    i, char, next_three, quote, triple, escaped, depth, brackets, quote_count) {
    depth = 0
    for (i = start; i <= length(value); i++) {
        char = substr(value, i, 1)
        next_three = substr(value, i, 3)
        if (quote != "") {
            if (triple && next_three == quote quote quote) {
                quote_count = 3
                while (quote_count < 5 && substr(value, i + quote_count, 1) == quote) quote_count++
                quote = ""
                triple = 0
                i += quote_count - 1
            } else if (!triple && char == quote && !escaped) quote = ""
            else if (quote == "\"" && char == "\\" && !escaped) escaped = 1
            else escaped = 0
            continue
        }
        if (next_three == "\"\"\"" || next_three == "'''") {
            quote = char
            triple = 1
            i += 2
        } else if (char == "\"" || char == "'") quote = char
        else if (char == "{") depth++
        else if (char == "}" && --depth == 0) return 0
        else if (char == "[") brackets++
        else if (char == "]") brackets--
        else if ((char == "\n" || char == "\r") && brackets == 0) return 1
    }
    return 0
}

function codec_toml_skip_space() {
    while (codec_toml_position <= length(codec_toml_source) && substr(codec_toml_source, codec_toml_position, 1) ~ /[ \t\r\n]/) codec_toml_position++
}

function codec_toml_hex_value(char) {
    char = toupper(char)
    return char ~ /[0-9]/ ? char + 0 : index("ABCDEF", char) + 9
}

function codec_toml_string(quote, triple,    result, char, escaped, digits, codepoint, count, quote_count, extra) {
    result = ""
    codec_toml_position += triple ? 3 : 1
    if (triple && substr(codec_toml_source, codec_toml_position, 2) == "\r\n") codec_toml_position += 2
    else if (triple && substr(codec_toml_source, codec_toml_position, 1) == "\n") codec_toml_position++
    while (codec_toml_position <= length(codec_toml_source)) {
        if (triple && substr(codec_toml_source, codec_toml_position, 3) == quote quote quote) {
            quote_count = 3
            while (quote_count < 5 && substr(codec_toml_source, codec_toml_position + quote_count, 1) == quote) quote_count++
            extra = quote_count - 3
            while (extra > 0) {
                result = result quote
                extra--
            }
            codec_toml_position += quote_count
            return result
        }
        char = substr(codec_toml_source, codec_toml_position++, 1)
        if (!triple && char == quote) return result
        if (!triple && (char == "\n" || char == "\r")) fail("newline in single-line TOML string")
        if (quote == "'" || char != "\\") {
            result = result char
            continue
        }
        char = substr(codec_toml_source, codec_toml_position++, 1)
        if (triple && char ~ /[ \t]/) {
            while (substr(codec_toml_source, codec_toml_position, 1) ~ /[ \t]/) codec_toml_position++
            char = substr(codec_toml_source, codec_toml_position++, 1)
            if (char != "\n" && !(char == "\r" && substr(codec_toml_source, codec_toml_position, 1) == "\n")) fail("invalid TOML string escape")
            if (char == "\r") codec_toml_position++
            while (substr(codec_toml_source, codec_toml_position, 1) ~ /[ \t\r\n]/) codec_toml_position++
        } else if (triple && char == "\r" && substr(codec_toml_source, codec_toml_position, 1) == "\n") {
            codec_toml_position++
            while (substr(codec_toml_source, codec_toml_position, 1) ~ /[ \t\r\n]/) codec_toml_position++
        } else if (triple && char == "\n") {
            while (substr(codec_toml_source, codec_toml_position, 1) ~ /[ \t\r\n]/) codec_toml_position++
        } else if (char == "n") result = result "\n"
        else if (char == "r") result = result "\r"
        else if (char == "t") result = result "\t"
        else if (char == "b") result = result sprintf("%c", 8)
        else if (char == "f") result = result sprintf("%c", 12)
        else if (char == "\"") result = result "\""
        else if (char == "\\") result = result "\\"
        else if (char == "u" || char == "U") {
            count = char == "u" ? 4 : 8
            digits = substr(codec_toml_source, codec_toml_position, count)
            if (length(digits) != count || digits !~ /^[0-9A-Fa-f]+$/) fail("invalid TOML Unicode escape")
            codepoint = 0
            for (escaped = 1; escaped <= count; escaped++) codepoint = codepoint * 16 + codec_toml_hex_value(substr(digits, escaped, 1))
            if (codepoint > 1114111 || (codepoint >= 55296 && codepoint <= 57343)) fail("invalid TOML Unicode code point")
            result = result (codepoint == 0 ? codec_toml_nul_marker : unicode_utf8(codepoint))
            codec_toml_position += count
        } else fail("invalid TOML string escape")
    }
    fail("unterminated TOML string")
}

function codec_toml_key_parts(value, parts,    position, count, char, quote, start, key, saved_source, saved_position) {
    position = 1
    count = 0
    while (position <= length(value)) {
        while (substr(value, position, 1) ~ /[ \t]/) position++
        char = substr(value, position, 1)
        if (char == "\"" || char == "'") {
            saved_source = codec_toml_source
            saved_position = codec_toml_position
            codec_toml_source = value
            codec_toml_position = position
            key = codec_toml_string(char, 0)
            position = codec_toml_position
            codec_toml_source = saved_source
            codec_toml_position = saved_position
        } else {
            start = position
            while (substr(value, position, 1) ~ /[A-Za-z0-9_-]/) position++
            key = substr(value, start, position - start)
            if (key == "") fail("invalid TOML key")
        }
        parts[++count] = key
        while (substr(value, position, 1) ~ /[ \t]/) position++
        if (position > length(value)) break
        if (substr(value, position, 1) != ".") fail("invalid TOML dotted key")
        position++
        while (substr(value, position, 1) ~ /[ \t]/) position++
        if (position > length(value)) fail("invalid TOML dotted key")
    }
    return count
}

function codec_toml_base_number(value, base,    result, i, char, digit) {
    result = 0
    for (i = 1; i <= length(value); i++) {
        char = substr(value, i, 1)
        digit = char ~ /[0-9]/ ? char + 0 : index("abcdef", tolower(char)) + 9
        if (digit < 0 || digit >= base) fail("invalid TOML integer")
        result = result * base + digit
    }
    return result
}

function codec_toml_date_valid(value,    year, month, day, days, leap) {
    if (value !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) return 0
    year = substr(value, 1, 4) + 0
    month = substr(value, 6, 2) + 0
    day = substr(value, 9, 2) + 0
    if (month < 1 || month > 12 || day < 1) return 0
    days = (month == 2 ? 28 : ((month == 4 || month == 6 || month == 9 || month == 11) ? 30 : 31))
    leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    if (month == 2 && leap) days = 29
    return day <= days
}

function codec_toml_time_valid(value, offset,    core, fraction, hour, minute, second, sign_at, offset_hour, offset_minute) {
    core = value
    offset = ""
    if (substr(core, length(core), 1) ~ /[Zz]/) {
        offset = substr(core, length(core), 1)
        core = substr(core, 1, length(core) - 1)
    } else {
        sign_at = 0
        for (offset_hour = 9; offset_hour <= length(core); offset_hour++) {
            if (substr(core, offset_hour, 1) == "+" || substr(core, offset_hour, 1) == "-") sign_at = offset_hour
        }
        if (sign_at) {
            offset = substr(core, sign_at)
            core = substr(core, 1, sign_at - 1)
            if (offset !~ /^[+-][0-9][0-9]:[0-9][0-9]$/) return 0
            offset_hour = substr(offset, 2, 2) + 0
            offset_minute = substr(offset, 5, 2) + 0
            if (offset_hour > 23 || offset_minute > 59) return 0
        }
    }
    if (core !~ /^[0-9][0-9]:[0-9][0-9]:[0-9][0-9](\.[0-9]+)?$/) return 0
    hour = substr(core, 1, 2) + 0
    minute = substr(core, 4, 2) + 0
    second = substr(core, 7, 2) + 0
    return hour <= 23 && minute <= 59 && second <= 60
}

function codec_toml_datetime(value,    date, time, separator, node, tagged) {
    codec_toml_datetime_tag = ""
    if (length(value) == 10 && codec_toml_date_valid(value)) codec_toml_datetime_tag = "date-local"
    else if (substr(value, 3, 1) == ":" && codec_toml_time_valid(value)) codec_toml_datetime_tag = "time-local"
    else if (length(value) > 18 && (substr(value, 11, 1) == "T" || substr(value, 11, 1) == "t" || substr(value, 11, 1) == " ")) {
        date = substr(value, 1, 10)
        time = substr(value, 12)
        if (codec_toml_date_valid(date) && codec_toml_time_valid(time)) {
            codec_toml_datetime_tag = time ~ /([Zz]|[+-][0-9][0-9]:[0-9][0-9])$/ ? "datetime" : "datetime-local"
        }
    }
    if (codec_toml_datetime_tag == "") return 0
    tagged = value
    if (substr(tagged, 11, 1) == "t" || substr(tagged, 11, 1) == " ") tagged = substr(tagged, 1, 10) "T" substr(tagged, 12)
    if (substr(tagged, length(tagged), 1) == "z") tagged = substr(tagged, 1, length(tagged) - 1) "Z"
    node = expression_scalar(tagged, "string")
    node_tag[node] = "!toml/" codec_toml_datetime_tag
    return node
}

function codec_toml_assign_path(root, parts, count, value, array_table,    current, i, key, child, sequence, item) {
    if (count < 1) fail("TOML key cannot be empty")
    current = root
    for (i = 1; i < count; i++) {
        key = parts[i]
        child = mapping_lookup(current, key)
        if (!child) {
            child = new_node("mapping", 0, "", "", "")
            add_mapping(current, key, child, 0, 0)
            if (value) toml_dotted_table[child] = 1
            else toml_implicit_table[child] = 1
        } else {
            child = resolve_alias(child)
            if (toml_inline_table[child]) fail("TOML inline tables cannot be extended")
            if (node_kind[child] == "sequence" && toml_array_table[child] && !value && sequence_count[child]) child = resolve_alias(sequence_child[child, sequence_count[child]])
            if (node_kind[child] != "mapping") fail("TOML dotted key traverses a non-table")
            if (value && toml_explicit_table[child]) fail("TOML dotted key cannot extend an explicitly defined table")
        }
        current = child
    }
    key = parts[count]
    if (array_table) {
        sequence = mapping_lookup(current, key)
        if (!sequence) {
            sequence = new_node("sequence", 0, "", "", "")
            add_mapping(current, key, sequence, 0, 0)
            toml_array_table[sequence] = 1
        } else if (node_kind[resolve_alias(sequence)] != "sequence" || !toml_array_table[resolve_alias(sequence)]) fail("TOML array table conflicts with an existing value")
        item = new_node("mapping", 0, "", "", "")
        add_sequence(sequence, item, 0)
        return item
    }
    if (value) {
        if (mapping_lookup(current, key)) fail("duplicate TOML key: " key)
        add_mapping(current, key, value, 0, 0)
        if (node_kind[resolve_alias(value)] == "mapping") toml_inline_table[resolve_alias(value)] = 1
        return value
    }
    child = mapping_lookup(current, key)
    if (!child) {
        child = new_node("mapping", 0, "", "", "")
        add_mapping(current, key, child, 0, 0)
        toml_explicit_table[child] = 1
    } else if (node_kind[resolve_alias(child)] != "mapping") fail("TOML table conflicts with an existing value")
    else {
        child = resolve_alias(child)
        if (toml_explicit_table[child] || toml_dotted_table[child] || toml_inline_table[child]) fail("TOML table is defined more than once")
        toml_explicit_table[child] = 1
        delete toml_implicit_table[child]
    }
    return resolve_alias(child)
}

function codec_toml_value(    char, triple, node, key_text, key_count, key_parts, child, token, start, base, sign, normalized, date_node) {
    codec_toml_skip_space()
    char = substr(codec_toml_source, codec_toml_position, 1)
    triple = substr(codec_toml_source, codec_toml_position, 3) == char char char
    if (char == "\"" || char == "'") return expression_scalar(codec_toml_string(char, triple), "string")
    if (char == "[") {
        codec_toml_position++
        node = new_node("sequence", 0, "", "", "")
        codec_toml_skip_space()
        if (substr(codec_toml_source, codec_toml_position, 1) == "]") {
            codec_toml_position++
            return node
        }
        while (1) {
            add_sequence(node, codec_toml_value(), 0)
            codec_toml_skip_space()
            char = substr(codec_toml_source, codec_toml_position++, 1)
            if (char == "]") return node
            if (char != ",") fail("expected comma or closing bracket in TOML array")
            codec_toml_skip_space()
            if (substr(codec_toml_source, codec_toml_position, 1) == "]") {
                codec_toml_position++
                return node
            }
        }
    }
    if (char == "{") {
        if (codec_toml_inline_has_newline(codec_toml_source, codec_toml_position)) fail("TOML 1.0 inline tables cannot contain separator newlines")
        codec_toml_position++
        node = new_node("mapping", 0, "", "", "")
        codec_toml_skip_space()
        if (substr(codec_toml_source, codec_toml_position, 1) == "}") {
            codec_toml_position++
            return node
        }
        while (1) {
            start = codec_toml_position
            codec_toml_position = codec_toml_find_equals(codec_toml_source, start)
            if (!codec_toml_position) fail("TOML inline table entry requires =")
            key_text = trim(substr(codec_toml_source, start, codec_toml_position - start))
            codec_toml_position++
            key_count = codec_toml_key_parts(key_text, key_parts)
            child = codec_toml_value()
            codec_toml_assign_path(node, key_parts, key_count, child, 0)
            codec_toml_skip_space()
            char = substr(codec_toml_source, codec_toml_position++, 1)
            if (char == "}") return node
            if (char != ",") fail("expected comma or closing brace in TOML inline table")
        }
    }
    start = codec_toml_position
    while (codec_toml_position <= length(codec_toml_source)) {
        char = substr(codec_toml_source, codec_toml_position, 1)
        if (char == "," || char == "]" || char == "}") break
        codec_toml_position++
    }
    token = trim(substr(codec_toml_source, start, codec_toml_position - start))
    if (token == "true" || token == "false") return expression_scalar(token, "bool")
    if (index(token, "_")) {
        if (token ~ /^0x/ && token !~ /^0x[0-9A-Fa-f]+(_[0-9A-Fa-f]+)*$/) fail("invalid underscore in TOML hexadecimal integer")
        if (token ~ /^0o/ && token !~ /^0o[0-7]+(_[0-7]+)*$/) fail("invalid underscore in TOML octal integer")
        if (token ~ /^0b/ && token !~ /^0b[01]+(_[01]+)*$/) fail("invalid underscore in TOML binary integer")
        if (token !~ /^0[xob]/ && token !~ /^[+-]?(0|[1-9][0-9]*(_[0-9]+)*)(\.[0-9]+(_[0-9]+)*)?([eE][+-]?[0-9]+(_[0-9]+)*)?$/) fail("invalid underscore in TOML number")
    }
    normalized = token
    gsub(/_/, "", normalized)
    sign = 1
    if (substr(normalized, 1, 1) == "-") {
        sign = -1
        normalized = substr(normalized, 2)
    } else if (substr(normalized, 1, 1) == "+") normalized = substr(normalized, 2)
    if (sign != 1 || substr(token, 1, 1) == "+") {
        if (normalized ~ /^0[xob]/) fail("TOML base-prefixed integers cannot have a sign")
    }
    if (normalized ~ /^0x[0-9A-Fa-f]+$/) return expression_scalar((sign * codec_toml_base_number(substr(normalized, 3), 16)) "", "int")
    if (normalized ~ /^0o[0-7]+$/) return expression_scalar((sign * codec_toml_base_number(substr(normalized, 3), 8)) "", "int")
    if (normalized ~ /^0b[01]+$/) return expression_scalar((sign * codec_toml_base_number(substr(normalized, 3), 2)) "", "int")
    normalized = (sign < 0 ? "-" : "") normalized
    if (normalized ~ /^-?(0|[1-9][0-9]*)$/) return expression_scalar((normalized + 0 == 0 ? "0" : normalized), "int")
    if (normalized ~ /^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$/) return expression_scalar(normalized, normalized ~ /[.eE]/ ? "float" : "int")
    if (normalized == "inf" || normalized == "-inf" || normalized == "nan" || normalized == "-nan") {
        node = expression_scalar(normalized ~ /nan$/ ? "nan" : normalized, "string")
        node_tag[node] = "!toml/float"
        return node
    }
    date_node = codec_toml_datetime(token)
    if (date_node) return date_node
    fail("invalid TOML value: " token)
}

function codec_toml_decode(value,    root, current, statement, body, array_table, count, parts, equals, key_text, child, i, byte) {
    if (max_input_bytes > 0 && length(value) > max_input_bytes) fail("embedded TOML size limit exceeded (max " max_input_bytes " bytes)")
    for (i = 1; i <= length(value); i++) {
        byte = codec_byte(substr(value, i, 1))
        if ((byte < 32 && byte != 9 && byte != 10 && !(byte == 13 && codec_byte(substr(value, i + 1, 1)) == 10)) || byte == 127) {
            fail("TOML contains a forbidden control character")
        }
    }
    root = new_node("mapping", 0, "", "", "")
    current = root
    codec_toml_remaining = value
    while ((statement = codec_toml_next_statement()) != "") {
        if (substr(statement, 1, 2) == "[[" && substr(statement, length(statement) - 1) == "]]" ) {
            if (index(statement, "\n")) fail("TOML table headers must stay on one line")
            array_table = 1
            body = trim(substr(statement, 3, length(statement) - 4))
            count = codec_toml_key_parts(body, parts)
            current = codec_toml_assign_path(root, parts, count, 0, 1)
        } else if (substr(statement, 1, 1) == "[" && substr(statement, length(statement), 1) == "]") {
            if (index(statement, "\n")) fail("TOML table headers must stay on one line")
            array_table = 0
            body = trim(substr(statement, 2, length(statement) - 2))
            count = codec_toml_key_parts(body, parts)
            current = codec_toml_assign_path(root, parts, count, 0, 0)
        } else {
            codec_toml_source = statement
            codec_toml_position = 1
            equals = codec_toml_find_equals(codec_toml_source, codec_toml_position)
            if (!equals) fail("TOML assignment requires =")
            key_text = trim(substr(codec_toml_source, 1, equals - 1))
            count = codec_toml_key_parts(key_text, parts)
            codec_toml_position = equals + 1
            child = codec_toml_value()
            codec_toml_skip_space()
            if (codec_toml_position <= length(codec_toml_source)) fail("trailing content after TOML value")
            codec_toml_assign_path(current, parts, count, child, 0)
        }
    }
    return root
}

function codec_toml_key(value) {
    return value ~ /^[A-Za-z0-9_-]+$/ ? value : json_quote(value)
}

function codec_toml_escape(value,    result) {
    result = json_escape(value)
    gsub(/\//, "/", result)
    return result
}

function codec_toml_inline(node,    resolved, result, i, key) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] == "scalar") {
        if (substr(node_tag[resolved], 1, 6) == "!toml/") return node_value[resolved]
        if (node_type[resolved] == "string") return "\"" codec_toml_escape(node_value[resolved]) "\""
        if (node_type[resolved] == "null") fail("TOML has no null value")
        return node_value[resolved]
    }
    if (node_kind[resolved] == "sequence") {
        result = "["
        for (i = 1; i <= sequence_count[resolved]; i++) result = result (i > 1 ? ", " : "") codec_toml_inline(sequence_child[resolved, i])
        return result "]"
    }
    result = "{"
    for (i = 1; i <= mapping_count[resolved]; i++) {
        key = mapping_key[resolved, i]
        result = result (i > 1 ? ", " : "") codec_toml_key(key) " = " codec_toml_inline(mapping_child[resolved, i])
    }
    return result "}"
}

function codec_toml_array_tables(node,    resolved, i) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] != "sequence" || !sequence_count[resolved]) return 0
    for (i = 1; i <= sequence_count[resolved]; i++) if (node_kind[resolve_alias(sequence_child[resolved, i])] != "mapping") return 0
    return 1
}

function codec_toml_emit_table(node, path, header,    resolved, result, i, key, child, nested, child_path, j) {
    resolved = resolve_alias(node)
    result = header == "" ? "" : header "\n"
    for (i = 1; i <= mapping_count[resolved]; i++) {
        key = mapping_key[resolved, i]
        child = resolve_alias(mapping_child[resolved, i])
        if (node_kind[child] != "mapping" && !codec_toml_array_tables(child)) result = result codec_toml_key(key) " = " codec_toml_inline(child) "\n"
    }
    for (i = 1; i <= mapping_count[resolved]; i++) {
        key = mapping_key[resolved, i]
        child = resolve_alias(mapping_child[resolved, i])
        child_path = path == "" ? codec_toml_key(key) : path "." codec_toml_key(key)
        if (node_kind[child] == "mapping") {
            if (result != "" && substr(result, length(result), 1) != "\n") result = result "\n"
            result = result "\n" codec_toml_emit_table(child, child_path, "[" child_path "]")
        } else if (codec_toml_array_tables(child)) {
            for (j = 1; j <= sequence_count[child]; j++) result = result "\n" codec_toml_emit_table(sequence_child[child, j], child_path, "[[" child_path "]]" )
        }
    }
    return result
}

function codec_toml_encode(node,    resolved, result) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] != "mapping") fail("TOML encoding requires a mapping root")
    result = codec_toml_emit_table(resolved, "", "")
    sub(/^\n+/, "", result)
    return result
}

function codec_toml_test_json(node,    resolved, result, type, i) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] == "scalar") {
        if (substr(node_tag[resolved], 1, 6) == "!toml/") type = substr(node_tag[resolved], 7)
        else if (node_type[resolved] == "int") type = "integer"
        else if (node_type[resolved] == "bool") type = "bool"
        else type = node_type[resolved] == "float" ? "float" : "string"
        return "{\"type\":" json_quote(type) ",\"value\":" json_quote(node_value[resolved]) "}"
    }
    if (node_kind[resolved] == "sequence") {
        result = "["
        for (i = 1; i <= sequence_count[resolved]; i++) result = result (i > 1 ? "," : "") codec_toml_test_json(sequence_child[resolved, i])
        return result "]"
    }
    result = "{"
    for (i = 1; i <= mapping_count[resolved]; i++) {
        result = result (i > 1 ? "," : "") json_quote(mapping_key[resolved, i]) ":" codec_toml_test_json(mapping_child[resolved, i])
    }
    return result "}"
}

function codec_toml_test_decode(node,    resolved, result, type_node, value_node, type, value, i, child) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] == "sequence") {
        result = new_node("sequence", 0, "", "", "")
        for (i = 1; i <= sequence_count[resolved]; i++) add_sequence(result, codec_toml_test_decode(sequence_child[resolved, i]), 0)
        return result
    }
    if (node_kind[resolved] != "mapping") fail("toml-test tagged JSON must contain objects and arrays")
    type_node = mapping_lookup(resolved, "type")
    value_node = mapping_lookup(resolved, "value")
    if (mapping_count[resolved] == 2 && type_node && value_node &&
        node_kind[resolve_alias(type_node)] == "scalar" && node_type[resolve_alias(type_node)] == "string" &&
        node_kind[resolve_alias(value_node)] == "scalar" && node_type[resolve_alias(value_node)] == "string") {
        type = node_value[resolve_alias(type_node)]
        value = node_value[resolve_alias(value_node)]
        if (type == "string") return expression_scalar(value, "string")
        if (type != "integer" && type != "float" && type != "bool" && type != "datetime" &&
            type != "datetime-local" && type != "date-local" && type != "time-local") fail("unknown toml-test scalar type: " type)
        if (type == "float" && value ~ /^[+-]?[0-9]+$/) value = value ".0"
        child = expression_scalar(value, type == "integer" ? "int" : (type == "bool" ? "bool" : "string"))
        node_tag[child] = "!toml/" type
        return child
    }
    result = new_node("mapping", 0, "", "", "")
    for (i = 1; i <= mapping_count[resolved]; i++) {
        add_mapping(result, mapping_key[resolved, i], codec_toml_test_decode(mapping_child[resolved, i]), 0, 0)
    }
    return result
}

function codec_ini_decode(value,    root, current, remaining, newline, line, clean, section, count, parts, separator, key, raw, child) {
    if (max_input_bytes > 0 && length(value) > max_input_bytes) fail("embedded INI size limit exceeded (max " max_input_bytes " bytes)")
    root = new_node("mapping", 0, "", "", "")
    current = root
    remaining = value
    while (remaining != "") {
        newline = index(remaining, "\n")
        if (newline) {
            line = substr(remaining, 1, newline - 1)
            remaining = substr(remaining, newline + 1)
        } else {
            line = remaining
            remaining = ""
        }
        sub(/\r$/, "", line)
        clean = trim(codec_strip_comment(line, "#;"))
        if (clean == "") continue
        if (substr(clean, 1, 1) == "[" && substr(clean, length(clean), 1) == "]") {
            section = trim(substr(clean, 2, length(clean) - 2))
            if (section == "") fail("INI section name cannot be empty")
            count = split(section, parts, /\./)
            current = codec_toml_assign_path(root, parts, count, 0, 0)
            continue
        }
        separator = index(clean, "=")
        if (!separator) separator = index(clean, ":")
        if (!separator) fail("INI assignment requires = or :")
        key = trim(substr(clean, 1, separator - 1))
        raw = trim(substr(clean, separator + 1))
        if (key == "") fail("INI key cannot be empty")
        if ((substr(raw, 1, 1) == "\"" && substr(raw, length(raw), 1) == "\"") ||
            (substr(raw, 1, 1) == "'" && substr(raw, length(raw), 1) == "'")) {
            codec_toml_source = raw
            codec_toml_position = 1
            raw = codec_toml_string(substr(raw, 1, 1), 0)
        }
        child = expression_scalar(raw, "string")
        if (mapping_lookup(current, key)) fail("duplicate INI key: " key)
        add_mapping(current, key, child, 0, 0)
    }
    return root
}

function codec_ini_emit(node, path,    resolved, result, i, key, child, child_path, nested) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] != "mapping") fail("INI encoding requires mappings")
    result = path == "" ? "" : "[" path "]\n"
    nested = ""
    for (i = 1; i <= mapping_count[resolved]; i++) {
        key = mapping_key[resolved, i]
        child = resolve_alias(mapping_child[resolved, i])
        if (node_kind[child] == "mapping") {
            child_path = path == "" ? key : path "." key
            nested = nested (nested == "" ? "" : "\n") codec_ini_emit(child, child_path)
        } else {
            if (node_kind[child] != "scalar") fail("INI encoding supports scalar values and nested sections")
            result = result key " = \"" codec_toml_escape(expression_to_string(child)) "\"\n"
        }
    }
    if (nested != "") result = result (result == "" ? "" : "\n") nested
    return result
}

function codec_ini_encode(node) {
    return codec_ini_emit(resolve_alias(node), "")
}

function codec_xml_name(    start, char) {
    start = codec_xml_position
    while (codec_xml_position <= length(codec_xml_source)) {
        char = substr(codec_xml_source, codec_xml_position, 1)
        if (char !~ /[A-Za-z0-9_.:-]/) break
        codec_xml_position++
    }
    if (codec_xml_position == start || substr(codec_xml_source, start, 1) !~ /[A-Za-z_:]/) fail("invalid XML name")
    return substr(codec_xml_source, start, codec_xml_position - start)
}

function codec_xml_skip_space() {
    while (substr(codec_xml_source, codec_xml_position, 1) ~ /[ \t\r\n]/) codec_xml_position++
}

function codec_xml_codepoint_valid(codepoint) {
    return codepoint == 9 || codepoint == 10 || codepoint == 13 ||
        (codepoint >= 32 && codepoint <= 55295) ||
        (codepoint >= 57344 && codepoint <= 65533) ||
        (codepoint >= 65536 && codepoint <= 1114111)
}

function codec_xml_name_valid(name) {
    return name ~ /^[A-Za-z_:][A-Za-z0-9_.:-]*$/
}

function codec_xml_entity(value,    result, i, semi, entity, codepoint, j, digit, base) {
    result = ""
    for (i = 1; i <= length(value); i++) {
        if (substr(value, i, 1) != "&") {
            result = result substr(value, i, 1)
            continue
        }
        semi = index(substr(value, i + 1), ";")
        if (!semi) fail("unterminated XML entity reference")
        entity = substr(value, i + 1, semi - 1)
        if (entity == "amp") result = result "&"
        else if (entity == "lt") result = result "<"
        else if (entity == "gt") result = result ">"
        else if (entity == "quot") result = result "\""
        else if (entity == "apos") result = result "'"
        else if (substr(entity, 1, 1) == "#") {
            base = substr(entity, 2, 1) ~ /[xX]/ ? 16 : 10
            entity = substr(entity, base == 16 ? 3 : 2)
            if (entity == "" || (base == 16 && entity !~ /^[0-9A-Fa-f]+$/) || (base == 10 && entity !~ /^[0-9]+$/)) fail("invalid XML character reference")
            codepoint = 0
            for (j = 1; j <= length(entity); j++) {
                digit = codec_toml_hex_value(substr(entity, j, 1))
                codepoint = codepoint * base + digit
            }
            if (!codec_xml_codepoint_valid(codepoint)) fail("invalid XML character reference")
            result = result unicode_utf8(codepoint)
        } else fail("XML named entities are limited to the five predefined entities")
        i += semi
    }
    return result
}

function codec_xml_skip_misc(    ending) {
    while (1) {
        codec_xml_skip_space()
        if (substr(codec_xml_source, codec_xml_position, 4) == "<!--") {
            ending = index(substr(codec_xml_source, codec_xml_position + 4), "-->")
            if (!ending) fail("unterminated XML comment")
            codec_xml_position += ending + 6
        } else if (substr(codec_xml_source, codec_xml_position, 2) == "<?") {
            ending = index(substr(codec_xml_source, codec_xml_position + 2), "?>")
            if (!ending) fail("unterminated XML processing instruction")
            codec_xml_position += ending + 3
        } else break
    }
}

function codec_xml_add_child(node, key, child,    existing, sequence) {
    existing = mapping_lookup(node, key)
    if (!existing) {
        add_mapping(node, key, child, 0, 0)
        return
    }
    existing = resolve_alias(existing)
    if (node_kind[existing] == "sequence") {
        add_sequence(existing, child, 0)
        return
    }
    sequence = new_node("sequence", 0, "", "", "")
    add_sequence(sequence, expression_clone_node(existing), 0)
    add_sequence(sequence, child, 0)
    expression_replace_node(existing, sequence)
}

function codec_xml_element(    name, attr, quote, start, raw, node, child, child_name, text, closing, ending, has_structure) {
    if (substr(codec_xml_source, codec_xml_position, 1) != "<") fail("expected XML element")
    codec_xml_position++
    name = codec_xml_name()
    node = new_node("mapping", 0, "", "", "")
    codec_xml_skip_space()
    while (substr(codec_xml_source, codec_xml_position, 1) != ">" && substr(codec_xml_source, codec_xml_position, 2) != "/>") {
        attr = codec_xml_name()
        codec_xml_skip_space()
        if (substr(codec_xml_source, codec_xml_position++, 1) != "=") fail("XML attribute requires =")
        codec_xml_skip_space()
        quote = substr(codec_xml_source, codec_xml_position++, 1)
        if (quote != "\"" && quote != "'") fail("XML attribute value must be quoted")
        start = codec_xml_position
        ending = index(substr(codec_xml_source, codec_xml_position), quote)
        if (!ending) fail("unterminated XML attribute")
        raw = substr(codec_xml_source, start, ending - 1)
        codec_xml_position += ending
        if (mapping_lookup(node, "+@" attr)) fail("duplicate XML attribute: " attr)
        add_mapping(node, "+@" attr, expression_scalar(codec_xml_entity(raw), "string"), 0, 0)
        has_structure = 1
        codec_xml_skip_space()
    }
    if (substr(codec_xml_source, codec_xml_position, 2) == "/>") {
        codec_xml_position += 2
        codec_xml_last_name = name
        return has_structure ? node : expression_null()
    }
    codec_xml_position++
    text = ""
    while (1) {
        if (codec_xml_position > length(codec_xml_source)) fail("unterminated XML element: " name)
        if (substr(codec_xml_source, codec_xml_position, 2) == "</") {
            codec_xml_position += 2
            closing = codec_xml_name()
            codec_xml_skip_space()
            if (substr(codec_xml_source, codec_xml_position++, 1) != ">") fail("invalid XML closing tag")
            if (closing != name) fail("XML closing tag " closing " does not match " name)
            break
        }
        if (substr(codec_xml_source, codec_xml_position, 9) == "<![CDATA[") {
            ending = index(substr(codec_xml_source, codec_xml_position + 9), "]]>")
            if (!ending) fail("unterminated XML CDATA section")
            text = text substr(codec_xml_source, codec_xml_position + 9, ending - 1)
            codec_xml_position += ending + 11
            continue
        }
        if (substr(codec_xml_source, codec_xml_position, 4) == "<!--") {
            ending = index(substr(codec_xml_source, codec_xml_position + 4), "-->")
            if (!ending) fail("unterminated XML comment")
            codec_xml_position += ending + 6
            continue
        }
        if (substr(codec_xml_source, codec_xml_position, 1) == "<") {
            child = codec_xml_element()
            child_name = codec_xml_last_name
            codec_xml_add_child(node, child_name, child)
            has_structure = 1
            continue
        }
        start = codec_xml_position
        while (codec_xml_position <= length(codec_xml_source) && substr(codec_xml_source, codec_xml_position, 1) != "<") codec_xml_position++
        text = text codec_xml_entity(substr(codec_xml_source, start, codec_xml_position - start))
    }
    codec_xml_last_name = name
    if (!has_structure) return expression_scalar(text, "string")
    if (trim(text) != "") add_mapping(node, "+content", expression_scalar(text, "string"), 0, 0)
    return node
}

function codec_xml_decode(value,    root, child, name, i, byte) {
    if (max_input_bytes > 0 && length(value) > max_input_bytes) fail("embedded XML size limit exceeded (max " max_input_bytes " bytes)")
    if (toupper(value) ~ /<!DOCTYPE/ || toupper(value) ~ /<!ENTITY/) fail("XML DTDs and entity declarations are disabled")
    for (i = 1; i <= length(value); i++) {
        byte = codec_byte(substr(value, i, 1))
        if (byte < 32 && byte != 9 && byte != 10 && byte != 13) fail("XML contains a forbidden control character")
    }
    codec_xml_source = value
    codec_xml_position = 1
    if (substr(codec_xml_source, 1, 3) == sprintf("%c%c%c", 239, 187, 191)) codec_xml_position = 4
    codec_xml_skip_misc()
    child = codec_xml_element()
    name = codec_xml_last_name
    codec_xml_skip_misc()
    if (codec_xml_position <= length(codec_xml_source)) fail("XML input must contain exactly one root element")
    root = new_node("mapping", 0, "", "", "")
    add_mapping(root, name, child, 0, 0)
    return root
}

function codec_xml_escape(value, attribute,    result) {
    result = value
    gsub(/&/, "\\&amp;", result)
    gsub(/</, "\\&lt;", result)
    gsub(/>/, "\\&gt;", result)
    if (attribute) gsub(/"/, "\\&quot;", result)
    return result
}

function codec_xml_emit_element(name, node,    resolved, result, i, key, child, content, has_children, j) {
    if (!codec_xml_name_valid(name)) fail("invalid XML element name: " name)
    resolved = resolve_alias(node)
    if (node_kind[resolved] == "scalar") {
        if (node_type[resolved] == "null") return "<" name "/>"
        return "<" name ">" codec_xml_escape(expression_to_string(resolved), 0) "</" name ">"
    }
    if (node_kind[resolved] != "mapping") fail("XML elements must be scalar or mapping values")
    result = "<" name
    for (i = 1; i <= mapping_count[resolved]; i++) {
        key = mapping_key[resolved, i]
        child = resolve_alias(mapping_child[resolved, i])
        if (substr(key, 1, 2) == "+@") {
            if (node_kind[child] != "scalar") fail("XML attributes must be scalar")
            if (!codec_xml_name_valid(substr(key, 3))) fail("invalid XML attribute name: " substr(key, 3))
            result = result " " substr(key, 3) "=\"" codec_xml_escape(expression_to_string(child), 1) "\""
        } else if (key == "+content") content = expression_to_string(child)
        else has_children = 1
    }
    if (!has_children && content == "") return result "/>"
    result = result ">" codec_xml_escape(content, 0)
    for (i = 1; i <= mapping_count[resolved]; i++) {
        key = mapping_key[resolved, i]
        if (substr(key, 1, 1) == "+") continue
        child = resolve_alias(mapping_child[resolved, i])
        if (node_kind[child] == "sequence") {
            for (j = 1; j <= sequence_count[child]; j++) result = result codec_xml_emit_element(key, sequence_child[child, j])
        } else result = result codec_xml_emit_element(key, child)
    }
    return result "</" name ">"
}

function codec_xml_encode(node,    resolved, key) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] != "mapping" || mapping_count[resolved] != 1) fail("XML encoding requires a mapping with exactly one root element")
    key = mapping_key[resolved, 1]
    return codec_xml_emit_element(key, mapping_child[resolved, 1]) "\n"
}

function codec_random_next(    high, low, test) {
    high = int(codec_random_state / 127773)
    low = codec_random_state % 127773
    test = 16807 * low - 2836 * high
    codec_random_state = test > 0 ? test : test + 2147483647
    return codec_random_state
}

function codec_json_skip_space(    char) {
    while (codec_json_position <= length(codec_json_source)) {
        char = substr(codec_json_source, codec_json_position, 1)
        if (char != " " && char != "\t" && char != "\r" && char != "\n") break
        codec_json_position++
    }
}

function codec_json_string(    result, char, escaped, digits, codepoint, high, low) {
    if (substr(codec_json_source, codec_json_position, 1) != "\"") fail("JSON string must begin with a quote")
    codec_json_position++
    result = ""
    while (codec_json_position <= length(codec_json_source)) {
        char = substr(codec_json_source, codec_json_position++, 1)
        if (char == "\"") return result
        if (codec_byte(char) < 32) fail("unescaped control character in JSON string")
        if (char != "\\") {
            result = result char
            continue
        }
        if (codec_json_position > length(codec_json_source)) fail("unterminated JSON escape")
        escaped = substr(codec_json_source, codec_json_position++, 1)
        if (escaped == "\"" || escaped == "\\" || escaped == "/") result = result escaped
        else if (escaped == "b") result = result sprintf("%c", 8)
        else if (escaped == "f") result = result sprintf("%c", 12)
        else if (escaped == "n") result = result "\n"
        else if (escaped == "r") result = result "\r"
        else if (escaped == "t") result = result "\t"
        else if (escaped == "u") {
            digits = substr(codec_json_source, codec_json_position, 4)
            if (length(digits) != 4 || digits !~ /^[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]$/) fail("invalid Unicode escape in JSON string")
            codec_json_position += 4
            codepoint = base_integer(digits, 16) + 0
            if (codepoint >= 55296 && codepoint <= 56319) {
                if (substr(codec_json_source, codec_json_position, 2) != "\\u") fail("unpaired high surrogate in JSON string")
                codec_json_position += 2
                digits = substr(codec_json_source, codec_json_position, 4)
                if (length(digits) != 4 || digits !~ /^[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]$/) fail("invalid low surrogate in JSON string")
                codec_json_position += 4
                low = base_integer(digits, 16) + 0
                if (low < 56320 || low > 57343) fail("invalid low surrogate in JSON string")
                high = codepoint
                codepoint = 65536 + (high - 55296) * 1024 + (low - 56320)
            } else if (codepoint >= 56320 && codepoint <= 57343) {
                fail("unpaired low surrogate in JSON string")
            }
            if (!codepoint) {
                if (output_mode != "toml-test-encode") fail("JSON strings cannot contain NUL")
                result = result codec_toml_nul_marker
            } else result = result unicode_utf8(codepoint)
        } else fail("invalid JSON escape")
    }
    fail("unterminated JSON string")
}

function codec_json_value(    char, node, key, value, start, number) {
    codec_json_skip_space()
    char = substr(codec_json_source, codec_json_position, 1)
    if (char == "\"") return expression_scalar(codec_json_string(), "string")
    if (char == "{") {
        codec_json_position++
        node = new_node("mapping", 0, "", "", "")
        codec_json_skip_space()
        if (substr(codec_json_source, codec_json_position, 1) == "}") {
            codec_json_position++
            return node
        }
        while (1) {
            codec_json_skip_space()
            if (substr(codec_json_source, codec_json_position, 1) != "\"") fail("JSON object keys must be strings")
            key = codec_json_string()
            codec_json_skip_space()
            if (substr(codec_json_source, codec_json_position, 1) != ":") fail("expected colon after JSON object key")
            codec_json_position++
            value = codec_json_value()
            add_mapping(node, key, value, 0, 0)
            codec_json_skip_space()
            char = substr(codec_json_source, codec_json_position++, 1)
            if (char == "}") return node
            if (char != ",") fail("expected comma or closing brace in JSON object")
        }
    }
    if (char == "[") {
        codec_json_position++
        node = new_node("sequence", 0, "", "", "")
        codec_json_skip_space()
        if (substr(codec_json_source, codec_json_position, 1) == "]") {
            codec_json_position++
            return node
        }
        while (1) {
            add_sequence(node, codec_json_value(), 0)
            codec_json_skip_space()
            char = substr(codec_json_source, codec_json_position++, 1)
            if (char == "]") return node
            if (char != ",") fail("expected comma or closing bracket in JSON array")
        }
    }
    if (substr(codec_json_source, codec_json_position, 4) == "true") {
        codec_json_position += 4
        return expression_scalar("true", "bool")
    }
    if (substr(codec_json_source, codec_json_position, 5) == "false") {
        codec_json_position += 5
        return expression_scalar("false", "bool")
    }
    if (substr(codec_json_source, codec_json_position, 4) == "null") {
        codec_json_position += 4
        return expression_null()
    }
    start = codec_json_position
    while (codec_json_position <= length(codec_json_source) && substr(codec_json_source, codec_json_position, 1) ~ /^[0-9eE+.-]$/) codec_json_position++
    number = substr(codec_json_source, start, codec_json_position - start)
    if (number == "" || number !~ /^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$/) fail("invalid JSON value")
    return expression_scalar(number, (number ~ /[.eE]/ ? "float" : "int"))
}

function expression_parse_json_text(value,    node) {
    if (max_input_bytes > 0 && length(value) > max_input_bytes) fail("embedded JSON size limit exceeded (max " max_input_bytes " bytes)")
    codec_json_source = value
    codec_json_position = 1
    node = codec_json_value()
    codec_json_skip_space()
    if (codec_json_position <= length(codec_json_source)) fail("trailing content after JSON value")
    return node
}

function codec_yaml_process_line(raw, source_line,    clean, next_char) {
    if (multiline_scalar_active) {
        multiline_scalar_text = multiline_scalar_text "\n" raw
        if (!multiline_quote_is_open(multiline_scalar_text, multiline_scalar_delimiter)) {
            process_line(multiline_scalar_text, multiline_scalar_line)
            multiline_scalar_active = 0
            multiline_scalar_text = ""
        }
        return
    }
    if (multiline_flow_active) {
        if (raw ~ /^[[:space:]]*#/) {
            multiline_flow_comment_break = 1
            flow_pending_comment_add(raw, source_line)
            return
        }
        if (multiline_flow_comment_break) {
            clean = trim(multiline_flow_text)
            clean = substr(clean, length(clean), 1)
            next_char = substr(trim(raw), 1, 1)
            if (clean != "," && next_char != "," && next_char != "}" && next_char != "]") fail("flow entries separated by a comment require a comma")
            multiline_flow_comment_break = 0
        }
        clean = strip_flow_line_comment(raw)
        if (trim(clean) == "") return
        flow_position_bind_pending(length(multiline_flow_text) + 2)
        flow_position_append(raw, clean, source_line)
        multiline_flow_text = multiline_flow_text " " clean
        multiline_flow_depth = flow_balance(multiline_flow_text)
        if (multiline_flow_depth <= 0) {
            process_line(multiline_flow_text, multiline_flow_line)
            flow_position_clear()
            multiline_flow_active = 0
            multiline_flow_text = ""
        }
        return
    }
    process_line(raw, source_line)
}

function expression_parse_yaml_text(value,    saved_document_index, saved_file_offset, saved_file_index, saved_filename, saved_combined, saved_inplace, embedded_document, source_base, line, next_newline, source_line, root, node, start_node, last_document, anchor_index, key) {
    if (max_input_bytes > 0 && length(value) > max_input_bytes) fail("embedded YAML size limit exceeded (max " max_input_bytes " bytes)")
    saved_document_index = document_index
    saved_file_offset = file_document_offset
    saved_file_index = current_input_file_index
    saved_filename = current_input_filename
    saved_combined = combined_files_mode
    saved_inplace = inplace_mode
    start_node = node_count + 1

    embedded_document = 1000000 + (++codec_yaml_serial * 1000)
    source_base = embedded_document
    document_index = embedded_document
    file_document_offset = embedded_document
    current_input_file_index = 0
    current_input_filename = "<embedded>"
    combined_files_mode = 0
    inplace_mode = 0
    clear_structure()
    block_active = 0
    multiline_scalar_active = 0
    multiline_flow_active = 0
    document_ended = 0

    source_line = source_base
    while (1) {
        next_newline = index(value, "\n")
        if (next_newline) {
            line = substr(value, 1, next_newline - 1)
            value = substr(value, next_newline + 1)
        } else {
            line = value
            value = ""
        }
        codec_yaml_process_line(line, ++source_line)
        if (!next_newline) break
    }
    if (multiline_scalar_active) fail("unclosed quoted scalar in embedded YAML")
    if (multiline_flow_active) fail("unclosed flow collection in embedded YAML")
    flush_block()
    fail_pending_explicit_keys(source_line + 1)
    if (!(embedded_document in document_root)) create_empty_document(source_line + 1)
    finalize_nodes()
    validate_aliases()
    validate_merges()
    root = document_root[embedded_document]

    last_document = document_index
    for (node = start_node; node <= node_count; node++) {
        node_line[node] = 0
        node_column[node] = 0
        delete node_document[node]
        delete node_file_index[node]
        delete node_filename[node]
    }
    for (document_index = embedded_document; document_index <= last_document; document_index++) {
        for (anchor_index = 1; anchor_index <= document_anchor_count[document_index]; anchor_index++) {
            key = document_index SUBSEP document_anchor_name[document_index, anchor_index]
            delete anchor_target[key]
            delete document_anchor_name[document_index, anchor_index]
            delete document_anchor_node[document_index, anchor_index]
        }
        delete document_anchor_count[document_index]
        delete document_root[document_index]
        delete document_file_index[document_index]
        delete document_filename[document_index]
        delete document_has_content[document_index]
        delete document_explicit[document_index]
        delete document_ended_line[document_index]
        delete document_directive_pending[document_index]
    }
    clear_structure()
    block_active = 0
    multiline_scalar_active = 0
    multiline_flow_active = 0
    document_ended = 0
    document_index = saved_document_index
    file_document_offset = saved_file_offset
    current_input_file_index = saved_file_index
    current_input_filename = saved_filename
    combined_files_mode = saved_combined
    inplace_mode = saved_inplace
    return root
}

function local_file_read(path,    line, result, status, bytes, separator) {
    if (path == "" || index(path, "\n") || index(path, "\r")) fail("load path must be a non-empty single line")
    result = ""
    separator = ""
    while ((status = (getline line < path)) > 0) {
        bytes += length(line) + 1
        if (max_input_bytes > 0 && bytes > max_input_bytes) {
            close(path)
            fail("loaded file size limit exceeded (max " max_input_bytes " bytes)")
        }
        result = result separator line
        separator = "\n"
    }
    close(path)
    if (status < 0) fail("could not load file: " path)
    if (separator != "") result = result "\n"
    return result
}

function expression_read_file(path) {
    if (disable_file_ops) fail("file operations are disabled")
    return local_file_read(path)
}

