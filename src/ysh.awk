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

function leading_horizontal_width(value,    copy) {
    copy = value
    sub(/[^ \t].*$/, "", copy)
    return length(copy)
}

function trim_quoted_right(value, double_quoted) {
    if (double_quoted && match(value, /\\[ \t]+$/)) {
        return substr(value, 1, RSTART + 1)
    }
    return trim_right_horizontal(value)
}

function json_escape(value,    result, i, char, byte) {
    result = ""
    for (i = 1; i <= length(value); i++) {
        if (codec_toml_nul_marker != "" && substr(value, i, length(codec_toml_nul_marker)) == codec_toml_nul_marker) {
            result = result "\\u0000"
            i += length(codec_toml_nul_marker) - 1
            continue
        }
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
            byte = codec_byte(char)
            if (byte < 32 || byte == 127) result = result "\\u00" substr(codec_hex, int(byte / 16) + 1, 1) substr(codec_hex, (byte % 16) + 1, 1)
            else result = result char
        }
    }
    return result
}

function json_quote(value) {
    return "\"" json_escape(value) "\""
}

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

function split_flow(value, output,    count, start, i, char, quote, escaped, braces, brackets, raw, leading) {
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
            raw = substr(value, start, i - start)
            leading = leading_horizontal_width(raw)
            output[++count] = trim(raw)
            flow_piece_offset[count] = start + leading
            start = i + 1
        }
    }
    raw = substr(value, start)
    leading = leading_horizontal_width(raw)
    output[++count] = trim(raw)
    flow_piece_offset[count] = start + leading
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
    if (max_nodes > 0 && node_count >= max_nodes) {
        fail("node limit exceeded (max " max_nodes ")")
    }
    node = ++node_count
    node_kind[node] = kind
    node_line[node] = source_line
    if (value != "") {
        node_value[node] = value
    }
    if (value_type != "") {
        node_type[node] = value_type
    }
    if (tag != "") {
        node_tag[node] = tag
    }
    if (document_index != file_document_offset) {
        node_document[node] = document_index - file_document_offset
    }
    if (combined_files_mode) {
        node_file_index[node] = current_input_file_index
        node_filename[node] = current_input_filename
    }
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
        if (substr(node_parent_edge[node], 1, 4) == "key " && (node in node_line_comment)) {
            node_key_line_comment[node] = node_line_comment[node]
            delete node_line_comment[node]
        }
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
        document_file_index[document_index] = current_input_file_index
        document_filename[document_index] = current_input_filename
        document_has_content[document_index] = 1
        parser_record_content(root, 0)
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
    document_file_index[document_index] = current_input_file_index
    document_filename[document_index] = current_input_filename
    document_has_content[document_index] = 1
    parser_record_content(root, 0)
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
    node_depth[child] = node_depth[parent] + 1
    if (max_depth > 0 && node_depth[child] > max_depth) {
        fail("collection depth limit exceeded (max " max_depth ")")
    }
}

function add_sequence(parent, child, source_line,    entry) {
    ensure_container(parent, "sequence", source_line)
    entry = ++sequence_count[parent]
    sequence_child[parent, entry] = child
    node_parent[child] = parent
    node_parent_edge[child] = "index " (entry - 1)
    node_depth[child] = node_depth[parent] + 1
    if (max_depth > 0 && node_depth[child] > max_depth) {
        fail("collection depth limit exceeded (max " max_depth ")")
    }
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
    if (index(remainder, "\n")) {
        fail("implicit mapping keys must fit on one line " source_line)
    }
    parsed_key_is_merge = remainder == "<<" && tag == ""
    return node_value[resolved]
}

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

function expression_lex_next(    char, next_char, start, quote, escaped, word, lowered, raw) {
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
    if (char == "@") {
        start = expression_position
        expression_position++
        while (expression_position <= length(expression_source) && expression_is_word_char(substr(expression_source, expression_position, 1))) {
            expression_position++
        }
        if (expression_position == start + 1) {
            fail("codec names require characters after @")
        }
        expression_token_type = "identifier"
        expression_token_value = substr(expression_source, start, expression_position - start)
        return
    }
    if (char == "*") {
        start = expression_position
        expression_position++
        while (expression_position <= length(expression_source) && substr(expression_source, expression_position, 1) ~ /^[+d?n]$/) {
            expression_position++
        }
        expression_token_type = "arithmetic"
        expression_token_value = substr(expression_source, start, expression_position - start)
        return
    }
    if (char == "+" || char == "-" || char == "/" || char == "%") {
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
                raw = substr(expression_source, start, expression_position - start)
                if (quote == "\"" && index(raw, "\\(")) {
                    expression_token_type = "interpolated"
                    expression_token_value = substr(raw, 2, length(raw) - 2)
                } else {
                    expression_token_type = "string"
                    expression_token_value = scalar_value(raw)
                }
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
        if (lowered == "and" || lowered == "or" || lowered == "not" || lowered == "as" || lowered == "ref") {
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
    if (max_nodes > 0 && expression > max_nodes) fail("expression node limit exceeded (max " max_nodes ")")
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

function expression_parse_fragment(source,    saved_source, saved_position, saved_type, saved_value, expression) {
    saved_source = expression_source
    saved_position = expression_position
    saved_type = expression_token_type
    saved_value = expression_token_value
    expression_source = source
    expression_position = 1
    expression_lex_next()
    expression = expression_parse_stream()
    if (expression_token_type != "end") {
        fail("unexpected token in interpolation: " expression_token_name(expression_token_type))
    }
    expression_source = saved_source
    expression_position = saved_position
    expression_token_type = saved_type
    expression_token_value = saved_value
    return expression
}

function expression_compile_interpolation(raw,    expression, segment_start, i, j, slash_count, marker, depth, quote, escaped, char, inner_start, literal, child, count) {
    expression = expression_new("interpolate", 0, 0, "")
    segment_start = 1
    i = 1
    while (i <= length(raw)) {
        if (substr(raw, i, 1) != "\\") {
            i++
            continue
        }
        slash_count = 0
        j = i
        while (substr(raw, j, 1) == "\\") {
            slash_count++
            j++
        }
        if (substr(raw, j, 1) != "(" || slash_count % 2 == 0) {
            i = j
            continue
        }
        marker = j - 1
        literal = substr(raw, segment_start, marker - segment_start)
        expression_interpolation_literal[expression, count + 1] = decode_double_quoted(literal)
        inner_start = j + 1
        depth = 1
        quote = ""
        escaped = 0
        for (j = inner_start; j <= length(raw); j++) {
            char = substr(raw, j, 1)
            if (quote != "") {
                if (escaped) {
                    escaped = 0
                } else if (char == "\\") {
                    escaped = 1
                } else if (char == quote) {
                    quote = ""
                }
                continue
            }
            if (char == "\"" || char == sprintf("%c", 39)) {
                quote = char
            } else if (char == "(") {
                depth++
            } else if (char == ")") {
                depth--
                if (!depth) {
                    break
                }
            }
        }
        if (depth) {
            fail("unterminated interpolation in expression")
        }
        child = expression_parse_fragment(substr(raw, inner_start, j - inner_start))
        expression_child[expression, ++count] = child
        expression_child_count[expression] = count
        segment_start = j + 1
        i = segment_start
    }
    expression_interpolation_literal[expression, count + 1] = decode_double_quoted(substr(raw, segment_start))
    return expression
}

function expression_parse_primary(    expression, name, step, argument, value, value_type, child, key, key_expression, source, initial, update, variable, slice, start_expression, end_expression) {
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
    } else if (expression_token_type == "interpolated") {
        value = expression_token_value
        expression_lex_next()
        expression = expression_compile_interpolation(value)
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
                key_expression = 0
                if (expression_token_type == "left_parenthesis") {
                    expression_lex_next()
                    key_expression = expression_parse_stream()
                    expression_expect("right_parenthesis")
                    key = ""
                } else {
                    if (expression_token_type != "identifier" && expression_token_type != "string") {
                        fail("object keys must be identifiers, strings, or parenthesized expressions")
                    }
                    key = expression_token_value
                    expression_lex_next()
                }
                expression_expect("colon")
                child = expression_parse_pipe()
                expression_object_key[expression, ++expression_child_count[expression]] = key
                expression_object_key_expression[expression, expression_child_count[expression]] = key_expression
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
        } else if (name == "env" || name == "strenv") {
            expression_expect("left_parenthesis")
            if (expression_token_type != "identifier" && expression_token_type != "string") {
                fail(name " requires an environment variable name")
            }
            value = expression_token_value
            expression_lex_next()
            expression_expect("right_parenthesis")
            expression = expression_new(name, 0, 0, value)
        } else if (name == "envsubst") {
            value = ""
            if (expression_token_type == "left_parenthesis") {
                expression_lex_next()
                while (expression_token_type != "right_parenthesis") {
                    if (expression_token_type != "identifier" ||
                        (tolower(expression_token_value) != "nu" && tolower(expression_token_value) != "ne" && tolower(expression_token_value) != "ff")) {
                        fail("envsubst options are nu, ne, or ff")
                    }
                    value = value " " tolower(expression_token_value) " "
                    expression_lex_next()
                    if (expression_token_type != "comma") {
                        break
                    }
                    expression_lex_next()
                }
                expression_expect("right_parenthesis")
            }
            expression = expression_new("envsubst", 0, 0, value)
        } else if (name == "first") {
            if (expression_token_type == "left_parenthesis") {
                expression_lex_next()
                argument = expression_parse_stream()
                expression_expect("right_parenthesis")
                expression = expression_new("first", argument, 0, "filtered")
            } else {
                expression = expression_new("first", 0, 0, "")
            }
        } else if (name == "with") {
            expression_expect("left_parenthesis")
            argument = expression_parse_stream()
            expression_expect("semicolon")
            child = expression_parse_stream()
            expression_expect("right_parenthesis")
            expression = expression_new("with", argument, child, "")
        } else if (name == "setpath") {
            expression_expect("left_parenthesis")
            argument = expression_parse_stream()
            expression_expect("semicolon")
            child = expression_parse_stream()
            expression_expect("right_parenthesis")
            expression = expression_new("setpath", argument, child, "")
        } else if (name == "delpaths") {
            expression_expect("left_parenthesis")
            argument = expression_parse_stream()
            expression_expect("right_parenthesis")
            expression = expression_new("delpaths", argument, 0, "")
        } else if (name == "explode") {
            expression_expect("left_parenthesis")
            argument = expression_parse_stream()
            expression_expect("right_parenthesis")
            expression = expression_new("explode", argument, 0, "")
        } else if (name == "error" || name == "eval" || name == "load" || name == "load_str" || name == "load_base64" || name == "load_props" ||
            name == "pointer" || name == "apply_patch" || name == "merge_patch" || name == "diff_patch") {
            expression_expect("left_parenthesis")
            argument = expression_parse_stream()
            expression_expect("right_parenthesis")
            expression = expression_new(name, argument, 0, "")
        } else if (name == "validate" || name == "schema_valid" || name == "schema_errors") {
            expression_expect("left_parenthesis")
            argument = expression_parse_stream()
            expression_expect("right_parenthesis")
            expression = expression_new(name, argument, 0, "")
        } else if (name == "to_json" || name == "to_yaml") {
            argument = 0
            if (expression_token_type == "left_parenthesis") {
                expression_lex_next()
                if (expression_token_type != "right_parenthesis") {
                    argument = expression_parse_stream()
                }
                expression_expect("right_parenthesis")
            }
            expression = expression_new(name, argument, 0, "")
        } else if (name == "from_json" || name == "from_yaml" || name == "from_props" || name == "from_csv" || name == "from_tsv" ||
            name == "from_toml" || name == "from_ini" || name == "from_xml" || name == "to_props" || name == "to_csv" || name == "to_tsv" ||
            name == "to_toml" || name == "to_ini" || name == "to_xml") {
            if (expression_token_type == "left_parenthesis") {
                expression_lex_next()
                expression_expect("right_parenthesis")
            }
            expression = expression_new(name, 0, 0, "")
        } else if (name == "@json" || name == "@jsond" || name == "@yaml" || name == "@yamld" ||
            name == "@props" || name == "@propsd" || name == "@csv" || name == "@csvd" || name == "@tsv" || name == "@tsvd" ||
            name == "@toml" || name == "@tomld" || name == "@ini" || name == "@inid" || name == "@xml" || name == "@xmld" ||
            name == "@base64" || name == "@base64d" ||
            name == "@uri" || name == "@urid" || name == "@sh") {
            if (name == "@json") expression = expression_new("to_json", 0, 0, "compact")
            else if (name == "@jsond") expression = expression_new("from_json", 0, 0, "")
            else if (name == "@yaml") expression = expression_new("to_yaml", 0, 0, "")
            else if (name == "@yamld") expression = expression_new("from_yaml", 0, 0, "")
            else if (name == "@props") expression = expression_new("to_props", 0, 0, "")
            else if (name == "@propsd") expression = expression_new("from_props", 0, 0, "")
            else if (name == "@csv") expression = expression_new("to_csv", 0, 0, "")
            else if (name == "@csvd") expression = expression_new("from_csv", 0, 0, "")
            else if (name == "@tsv") expression = expression_new("to_tsv", 0, 0, "")
            else if (name == "@tsvd") expression = expression_new("from_tsv", 0, 0, "")
            else if (name == "@toml") expression = expression_new("to_toml", 0, 0, "")
            else if (name == "@tomld") expression = expression_new("from_toml", 0, 0, "")
            else if (name == "@ini") expression = expression_new("to_ini", 0, 0, "")
            else if (name == "@inid") expression = expression_new("from_ini", 0, 0, "")
            else if (name == "@xml") expression = expression_new("to_xml", 0, 0, "")
            else if (name == "@xmld") expression = expression_new("from_xml", 0, 0, "")
            else expression = expression_new("codec_" substr(name, 2), 0, 0, "")
        } else if (name == "select" || name == "has" || name == "del" || name == "map" || name == "map_values" || name == "with_entries" ||
            name == "contains" || name == "startswith" || name == "endswith" || name == "split" || name == "join" ||
            name == "sort_by" || name == "group_by" || name == "unique_by" || name == "min_by" || name == "max_by" ||
            name == "any_c" || name == "all_c" || name == "test" || name == "sort_keys" || name == "filter" ||
            name == "pick" || name == "omit") {
            expression_expect("left_parenthesis")
            argument = expression_parse_stream()
            expression_expect("right_parenthesis")
            expression = expression_new(name == "test" ? "regex_test" : name, argument, 0, "")
        } else if (name == "sub") {
            expression_expect("left_parenthesis")
            argument = expression_parse_stream()
            expression_expect("semicolon")
            child = expression_parse_stream()
            expression_expect("right_parenthesis")
            expression = expression_new("regex_sub", argument, child, "")
        } else if (name == "length" || name == "keys" || name == "kind" || name == "type" || name == "to_entries" || name == "from_entries" ||
            name == "sort" || name == "unique" || name == "flatten" || name == "reverse" || name == "upcase" || name == "downcase" ||
            name == "trim" || name == "to_string" || name == "array_to_map" || name == "split_doc" || name == "shuffle" ||
            name == "min" || name == "max" || name == "any" || name == "all" || name == "add" || name == "path" ||
            name == "parent" || name == "root" || name == "to_number" || name == "documentindex" ||
            name == "fileindex" || name == "filename" || name == "empty" || name == "line" || name == "key" ||
            name == "column" || name == "tag" || name == "anchor" || name == "alias" || name == "style" || name == "line_comment" ||
            name == "head_comment" || name == "foot_comment" || name == "pivot") {
            if (expression_token_type == "left_parenthesis") {
                expression_lex_next()
                expression_expect("right_parenthesis")
            }
            if (name == "line") name = "node_line"
            else if (name == "column") name = "node_column"
            else if (name == "key") name = "node_key"
            else if (name == "tag") name = "node_tag"
            else if (name == "anchor") name = "node_anchor"
            else if (name == "alias") name = "node_alias"
            else if (name == "style") name = "node_style"
            else if (name == "line_comment") name = "node_line_comment"
            else if (name == "head_comment") name = "node_head_comment"
            else if (name == "foot_comment") name = "node_foot_comment"
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
            } else if (expression_token_type == "colon") {
                slice = expression_new("slice", expression, 0, "")
                expression_lex_next()
                if (expression_token_type != "right_bracket") {
                    end_expression = expression_parse_stream()
                    expression_child[slice, 2] = end_expression
                    expression_slice_has_end[slice] = 1
                }
                expression_expect("right_bracket")
                expression = slice
            } else if (expression_token_type == "number") {
                value = expression_token_value
                if (value !~ /^[0-9]+$/) {
                    fail("sequence indexes must be integers")
                }
                expression_lex_next()
                if (expression_token_type == "colon") {
                    start_expression = expression_new("literal", 0, 0, value)
                    expression_literal_type[start_expression] = "int"
                    slice = expression_new("slice", expression, 0, "")
                    expression_child[slice, 1] = start_expression
                    expression_slice_has_start[slice] = 1
                    expression_lex_next()
                    if (expression_token_type != "right_bracket") {
                        end_expression = expression_parse_stream()
                        expression_child[slice, 2] = end_expression
                        expression_slice_has_end[slice] = 1
                    }
                    expression_expect("right_bracket")
                    expression = slice
                } else {
                    expression_expect("right_bracket")
                    expression = expression_new("index", expression, 0, value + 0)
                }
            } else if (expression_token_type == "string") {
                value = expression_token_value
                expression_lex_next()
                if (expression_token_type == "colon") {
                    start_expression = expression_new("literal", 0, 0, value)
                    expression_literal_type[start_expression] = "string"
                    slice = expression_new("slice", expression, 0, "")
                    expression_child[slice, 1] = start_expression
                    expression_slice_has_start[slice] = 1
                    expression_lex_next()
                    if (expression_token_type != "right_bracket") {
                        end_expression = expression_parse_stream()
                        expression_child[slice, 2] = end_expression
                        expression_slice_has_end[slice] = 1
                    }
                    expression_expect("right_bracket")
                    expression = slice
                } else {
                    expression_expect("right_bracket")
                    expression = expression_new("key", expression, 0, value)
                }
            } else {
                step = expression_parse_stream()
                if (expression_token_type == "colon") {
                    slice = expression_new("slice", expression, 0, "")
                    expression_child[slice, 1] = step
                    expression_slice_has_start[slice] = 1
                    expression_lex_next()
                    if (expression_token_type != "right_bracket") {
                        end_expression = expression_parse_stream()
                        expression_child[slice, 2] = end_expression
                        expression_slice_has_end[slice] = 1
                    }
                    expression_expect("right_bracket")
                    expression = slice
                } else {
                    expression_expect("right_bracket")
                    expression = expression_new("dynamic", expression, step, "")
                }
            }
        } else if (expression_token_type == "identifier" &&
            (tolower(expression_token_value) == "style" || tolower(expression_token_value) == "line_comment" ||
            tolower(expression_token_value) == "head_comment" || tolower(expression_token_value) == "foot_comment" ||
            tolower(expression_token_value) == "tag" || tolower(expression_token_value) == "anchor" ||
            tolower(expression_token_value) == "alias")) {
            value = tolower(expression_token_value)
            expression_lex_next()
            expression = expression_new("node_property", expression, 0, value)
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

function expression_path(node,    result, depth, current, edge, i, value) {
    result = new_node("sequence", 0, "", "", "")
    depth = 0
    current = node
    while (current in node_parent) {
        expression_path_edge[++depth] = node_parent_edge[current]
        current = node_parent[current]
    }
    for (i = depth; i >= 1; i--) {
        edge = expression_path_edge[i]
        if (substr(edge, 1, 6) == "index ") {
            add_sequence(result, expression_scalar(substr(edge, 7), "int"), 0)
        } else {
            add_sequence(result, expression_scalar(substr(edge, 5), "string"), 0)
        }
        delete expression_path_edge[i]
    }
    return result
}

function expression_root(node,    current) {
    current = node
    while (current in node_parent) current = node_parent[current]
    return current
}

function patch_pointer_decode(token,    result, i, char, next_char) {
    result = ""
    for (i = 1; i <= length(token); i++) {
        char = substr(token, i, 1)
        if (char != "~") {
            result = result char
            continue
        }
        next_char = substr(token, ++i, 1)
        if (next_char == "0") result = result "~"
        else if (next_char == "1") result = result "/"
        else fail("invalid JSON Pointer escape")
    }
    return result
}

function patch_pointer_encode(token,    result) {
    result = token
    gsub(/~/, "~0", result)
    gsub(/\//, "~1", result)
    return result
}

function patch_pointer_find(root, pointer, allow_append,    remaining, slash, token, current, resolved, child, index_value) {
    patch_pointer_parent = 0
    patch_pointer_target = 0
    patch_pointer_token = ""
    patch_pointer_index = -1
    if (pointer == "") {
        patch_pointer_target = root
        return root
    }
    if (substr(pointer, 1, 1) != "/") fail("JSON Pointer must be empty or start with /")
    remaining = substr(pointer, 2)
    current = root
    while (1) {
        slash = index(remaining, "/")
        if (slash) {
            token = patch_pointer_decode(substr(remaining, 1, slash - 1))
            remaining = substr(remaining, slash + 1)
        } else {
            token = patch_pointer_decode(remaining)
        }
        resolved = resolve_alias(current)
        if (!slash) {
            patch_pointer_parent = resolved
            patch_pointer_token = token
            if (node_kind[resolved] == "mapping") {
                patch_pointer_target = mapping_lookup(resolved, token)
                return patch_pointer_target
            }
            if (node_kind[resolved] == "sequence") {
                if (token == "-" && allow_append) {
                    patch_pointer_index = sequence_count[resolved]
                    return 0
                }
                if (token !~ /^(0|[1-9][0-9]*)$/) fail("JSON Pointer array index must be an unsigned integer without leading zeros")
                index_value = token + 0
                if (index_value < sequence_count[resolved]) patch_pointer_target = sequence_child[resolved, index_value + 1]
                else if (!(allow_append && index_value == sequence_count[resolved])) fail("JSON Pointer array index is out of bounds: " token)
                patch_pointer_index = index_value
                return patch_pointer_target
            }
            fail("JSON Pointer cannot traverse " expression_type_name(resolved))
        }
        if (node_kind[resolved] == "mapping") {
            child = mapping_lookup(resolved, token)
        } else if (node_kind[resolved] == "sequence") {
            if (token !~ /^(0|[1-9][0-9]*)$/ || token + 0 >= sequence_count[resolved]) {
                fail("JSON Pointer array index is out of bounds: " token)
            }
            child = sequence_child[resolved, token + 1]
        } else {
            fail("JSON Pointer cannot traverse " expression_type_name(resolved))
        }
        if (!child) fail("JSON Pointer path does not exist at /" patch_pointer_encode(token))
        current = child
    }
}

function expression_semantic_equal(left, right,    left_node, right_node, i, collection, key, child) {
    left_node = resolve_alias(left)
    right_node = resolve_alias(right)
    if (node_kind[left_node] != node_kind[right_node]) return 0
    if (node_kind[left_node] == "scalar") return expression_nodes_equal(left_node, right_node)
    if (node_kind[left_node] == "sequence") {
        if (sequence_count[left_node] != sequence_count[right_node]) return 0
        for (i = 1; i <= sequence_count[left_node]; i++) {
            if (!expression_semantic_equal(sequence_child[left_node, i], sequence_child[right_node, i])) return 0
        }
        return 1
    }
    if (expression_mapping_length(left_node) != expression_mapping_length(right_node)) return 0
    collection = ++collection_serial
    collect_mapping_keys(left_node, collection)
    for (i = 1; i <= collection_count[collection]; i++) {
        key = collection_key[collection, i]
        child = mapping_lookup(right_node, key)
        if (!child || !expression_semantic_equal(mapping_lookup(left_node, key), child)) return 0
    }
    return 1
}

function patch_sequence_insert(parent, index_value, value,    replacement, i) {
    replacement = new_node("sequence", 0, "", "", "")
    for (i = 0; i <= sequence_count[parent]; i++) {
        if (i == index_value) add_sequence(replacement, expression_clone_node(value), 0)
        if (i < sequence_count[parent]) add_sequence(replacement, expression_clone_node(sequence_child[parent, i + 1]), 0)
    }
    expression_replace_node(parent, replacement)
    return expression_last_replace_changed
}

function patch_add(root, pointer, value,    target, parent, placeholder, changed) {
    target = patch_pointer_find(root, pointer, 1)
    parent = patch_pointer_parent
    if (!parent) {
        expression_replace_node(root, value)
        return expression_last_replace_changed
    }
    if (node_kind[parent] == "mapping") {
        if (target) {
            expression_replace_node(target, value)
            return expression_last_replace_changed
        }
        placeholder = expression_null()
        expression_missing_parent[placeholder] = parent
        expression_missing_key[placeholder] = patch_pointer_token
        expression_replace_node(placeholder, value)
        return expression_last_replace_changed
    }
    return patch_sequence_insert(parent, patch_pointer_index, value)
}

function patch_remove(root, pointer,    target) {
    target = patch_pointer_find(root, pointer, 0)
    if (!target) fail("JSON Patch remove path does not exist: " pointer)
    expression_delete_node(target)
    return expression_last_delete_changed
}

function patch_replace(root, pointer, value,    target) {
    target = patch_pointer_find(root, pointer, 0)
    if (!target) fail("JSON Patch replace path does not exist: " pointer)
    expression_replace_node(target, value)
    return expression_last_replace_changed
}

function patch_required_string(operation, name,    node) {
    node = mapping_lookup(operation, name)
    if (!node) fail("JSON Patch operation requires " name)
    node = resolve_alias(node)
    if (node_kind[node] != "scalar" || node_type[node] != "string") fail("JSON Patch " name " must be a string")
    return node_value[node]
}

function patch_apply(root, patch,    resolved_patch, i, operation, op, path, from, value, source, changed) {
    resolved_patch = resolve_alias(patch)
    if (node_kind[resolved_patch] != "sequence") fail("JSON Patch must be an array of operations")
    for (i = 1; i <= sequence_count[resolved_patch]; i++) {
        changed = 0
        operation = resolve_alias(sequence_child[resolved_patch, i])
        if (node_kind[operation] != "mapping") fail("JSON Patch operation must be an object")
        op = patch_required_string(operation, "op")
        path = patch_required_string(operation, "path")
        if (op == "add" || op == "replace" || op == "test") {
            value = mapping_lookup(operation, "value")
            if (!value) fail("JSON Patch " op " operation requires value")
        }
        if (op == "add") {
            changed = patch_add(root, path, value)
        } else if (op == "remove") {
            changed = patch_remove(root, path)
        } else if (op == "replace") {
            changed = patch_replace(root, path, value)
        } else if (op == "copy" || op == "move") {
            from = patch_required_string(operation, "from")
            source = patch_pointer_find(root, from, 0)
            if (!source) fail("JSON Patch " op " source does not exist: " from)
            if (op == "move" && path != from && index(path, from "/") == 1) fail("JSON Patch cannot move a value into its own descendant")
            value = expression_clone_node(source)
            if (op == "move" && path != from) changed = patch_remove(root, from) || changed
            if (path != from) changed = patch_add(root, path, value) || changed
        } else if (op == "test") {
            source = patch_pointer_find(root, path, 0)
            if (!source || !expression_semantic_equal(source, value)) fail("JSON Patch test failed at " path)
        } else {
            fail("unsupported JSON Patch operation: " op)
        }
        if (changed) expression_mark_changed(root)
    }
    return root
}

function merge_patch_apply(target, patch,    resolved_target, resolved_patch, collection, i, key, child, existing, placeholder) {
    resolved_target = resolve_alias(target)
    resolved_patch = resolve_alias(patch)
    if (node_kind[resolved_patch] != "mapping") {
        expression_replace_node(target, resolved_patch)
        if (expression_last_replace_changed) expression_mark_changed(target)
        return
    }
    if (node_kind[resolved_target] != "mapping") {
        expression_replace_node(target, new_node("mapping", 0, "", "", ""))
        if (expression_last_replace_changed) expression_mark_changed(target)
        resolved_target = resolve_alias(target)
    }
    collection = ++collection_serial
    collect_mapping_keys(resolved_patch, collection)
    for (i = 1; i <= collection_count[collection]; i++) {
        key = collection_key[collection, i]
        child = resolve_alias(mapping_lookup(resolved_patch, key))
        existing = mapping_lookup(resolved_target, key)
        if (node_kind[child] == "scalar" && node_type[child] == "null") {
            if (existing) {
                expression_delete_node(existing)
                if (expression_last_delete_changed) expression_mark_changed(resolved_target)
            }
        } else if (existing) {
            merge_patch_apply(existing, child)
        } else {
            placeholder = expression_null()
            expression_missing_parent[placeholder] = resolved_target
            expression_missing_key[placeholder] = key
            if (node_kind[child] == "mapping") {
                expression_replace_node(placeholder, new_node("mapping", 0, "", "", ""))
                merge_patch_apply(placeholder, child)
            } else {
                expression_replace_node(placeholder, child)
            }
            if (expression_last_replace_changed) expression_mark_changed(resolved_target)
        }
    }
}

function patch_operation(result, op, path, value,    operation) {
    operation = new_node("mapping", 0, "", "", "")
    add_mapping(operation, "op", expression_scalar(op, "string"), 0, 0)
    add_mapping(operation, "path", expression_scalar(path, "string"), 0, 0)
    if (value) add_mapping(operation, "value", expression_clone_node(value), 0, 0)
    add_sequence(result, operation, 0)
}

function patch_diff_into(before, after, path, result,    left, right, left_keys, right_keys, i, key, left_child, right_child) {
    left = resolve_alias(before)
    right = resolve_alias(after)
    if (expression_semantic_equal(left, right)) return
    if (node_kind[left] != "mapping" || node_kind[right] != "mapping") {
        patch_operation(result, "replace", path, right)
        return
    }
    left_keys = ++collection_serial
    right_keys = ++collection_serial
    collect_mapping_keys(left, left_keys)
    collect_mapping_keys(right, right_keys)
    for (i = 1; i <= collection_count[left_keys]; i++) {
        key = collection_key[left_keys, i]
        if (!mapping_lookup(right, key)) patch_operation(result, "remove", path "/" patch_pointer_encode(key), 0)
    }
    for (i = 1; i <= collection_count[left_keys]; i++) {
        key = collection_key[left_keys, i]
        left_child = mapping_lookup(left, key)
        right_child = mapping_lookup(right, key)
        if (right_child) patch_diff_into(left_child, right_child, path "/" patch_pointer_encode(key), result)
    }
    for (i = 1; i <= collection_count[right_keys]; i++) {
        key = collection_key[right_keys, i]
        if (!mapping_lookup(left, key)) patch_operation(result, "add", path "/" patch_pointer_encode(key), mapping_lookup(right, key))
    }
}

function schema_add_error(errors, instance_path, schema_path, keyword, message,    error) {
    error = new_node("mapping", 0, "", "", "")
    add_mapping(error, "instancePath", expression_scalar(instance_path, "string"), 0, 0)
    add_mapping(error, "schemaPath", expression_scalar(schema_path, "string"), 0, 0)
    add_mapping(error, "keyword", expression_scalar(keyword, "string"), 0, 0)
    add_mapping(error, "message", expression_scalar(message, "string"), 0, 0)
    add_sequence(errors, error, 0)
}

function schema_type_name(instance,    node) {
    node = resolve_alias(instance)
    if (node_kind[node] == "mapping") return "object"
    if (node_kind[node] == "sequence") return "array"
    if (node_type[node] == "bool") return "boolean"
    if (node_type[node] == "null") return "null"
    if (node_type[node] == "int") return "integer"
    if (node_type[node] == "float") return "number"
    return "string"
}

function schema_type_matches(instance, wanted,    node, number) {
    node = resolve_alias(instance)
    if (wanted == "object") return node_kind[node] == "mapping"
    if (wanted == "array") return node_kind[node] == "sequence"
    if (wanted == "string") return node_kind[node] == "scalar" && node_type[node] == "string"
    if (wanted == "boolean") return node_kind[node] == "scalar" && node_type[node] == "bool"
    if (wanted == "null") return node_kind[node] == "scalar" && node_type[node] == "null"
    if (wanted == "number") return node_kind[node] == "scalar" && (node_type[node] == "int" || node_type[node] == "float")
    if (wanted == "integer") {
        if (node_kind[node] != "scalar" || (node_type[node] != "int" && node_type[node] != "float")) return 0
        number = node_value[node] + 0
        return number == int(number)
    }
    return 0
}

function schema_type_contract(type_node,    node, i, child) {
    node = resolve_alias(type_node)
    if (node_kind[node] == "scalar" && node_type[node] == "string") return node_value[node]
    if (node_kind[node] == "sequence") {
        for (i = 1; i <= sequence_count[node]; i++) {
            child = resolve_alias(sequence_child[node, i])
            if (node_kind[child] != "scalar" || node_type[child] != "string") fail("JSON Schema type array must contain strings")
        }
        return "array"
    }
    fail("JSON Schema type must be a string or array of strings")
}

function schema_matches_type(instance, type_node,    node, i) {
    node = resolve_alias(type_node)
    if (node_kind[node] == "scalar") return schema_type_matches(instance, node_value[node])
    for (i = 1; i <= sequence_count[node]; i++) {
        if (schema_type_matches(instance, node_value[resolve_alias(sequence_child[node, i])])) return 1
    }
    return 0
}

function schema_utf8_length(value,    count, i, byte) {
    count = 0
    for (i = 1; i <= length(value); i++) {
        byte = codec_byte(substr(value, i, 1))
        if (byte < 128 || byte >= 192) count++
    }
    return count
}

function schema_number(node, keyword,    resolved) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] != "scalar" || (node_type[resolved] != "int" && node_type[resolved] != "float")) {
        fail("JSON Schema " keyword " must be a number")
    }
    return node_value[resolved] + 0
}

function schema_nonnegative_integer(node, keyword,    resolved, value) {
    resolved = resolve_alias(node)
    value = node_value[resolved] + 0
    if (node_kind[resolved] != "scalar" || (node_type[resolved] != "int" && node_type[resolved] != "float") || value < 0 || value != int(value)) {
        fail("JSON Schema " keyword " must be a non-negative integer")
    }
    return value
}

function schema_boolean(node, keyword,    resolved) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] != "scalar" || node_type[resolved] != "bool") fail("JSON Schema " keyword " must be a boolean")
    return tolower(node_value[resolved]) == "true"
}

function schema_trial(instance, schema, instance_path, schema_path, root,    errors) {
    errors = new_node("sequence", 0, "", "", "")
    schema_validate(instance, schema, errors, instance_path, schema_path, root)
    return sequence_count[errors] == 0
}

function schema_validate(instance, schema, errors, instance_path, schema_path, root,    resolved_schema, resolved_instance, valid, keyword, type_node, i, j, child, collection, key, property_schema, instance_child, required, matched, count, trial, minimum, maximum, number, size, pattern, properties, pattern_properties, additional, covered, item_start, contains_count, min_contains, max_contains, ref, referenced, active_key, dependent, dependency, name_node, name_schema, conditional, numeric_text) {
    if (++schema_validation_depth > max_depth) fail("JSON Schema validation depth limit exceeded (max " max_depth ")")
    resolved_schema = resolve_alias(schema)
    resolved_instance = resolve_alias(instance)
    valid = 1

    if (node_kind[resolved_schema] == "scalar" && node_type[resolved_schema] == "bool") {
        if (tolower(node_value[resolved_schema]) != "true") {
            schema_add_error(errors, instance_path, schema_path, "falseSchema", "value is rejected by the schema")
            valid = 0
        }
        schema_validation_depth--
        return valid
    }
    if (node_kind[resolved_schema] != "mapping") fail("JSON Schema must be an object or boolean")
    if (mapping_lookup(resolved_schema, "$dynamicRef")) fail("JSON Schema dynamic references are outside the focused profile")
    if (mapping_lookup(resolved_schema, "unevaluatedProperties") || mapping_lookup(resolved_schema, "unevaluatedItems")) {
        fail("JSON Schema unevaluated vocabularies are outside the focused profile")
    }

    child = mapping_lookup(resolved_schema, "$ref")
    if (child) {
        child = resolve_alias(child)
        if (node_kind[child] != "scalar" || node_type[child] != "string") fail("JSON Schema $ref must be a string")
        ref = node_value[child]
        if (ref == "#") referenced = root
        else if (substr(ref, 1, 2) == "#/") referenced = patch_pointer_find(root, substr(ref, 2), 0)
        else fail("JSON Schema supports local $ref values only")
        if (!referenced) fail("JSON Schema $ref does not resolve: " ref)
        active_key = referenced SUBSEP resolved_instance
        if (schema_ref_active[active_key]) fail("cyclic JSON Schema $ref")
        schema_ref_active[active_key] = 1
        if (!schema_validate(resolved_instance, referenced, errors, instance_path, ref, root)) valid = 0
        delete schema_ref_active[active_key]
    }

    type_node = mapping_lookup(resolved_schema, "type")
    if (type_node) {
        schema_type_contract(type_node)
        if (!schema_matches_type(resolved_instance, type_node)) {
            schema_add_error(errors, instance_path, schema_path "/type", "type", "expected " expression_to_string(type_node) ", got " schema_type_name(resolved_instance))
            valid = 0
        }
    }

    child = mapping_lookup(resolved_schema, "const")
    if (child && !expression_semantic_equal(resolved_instance, child)) {
        schema_add_error(errors, instance_path, schema_path "/const", "const", "value does not match const")
        valid = 0
    }
    child = mapping_lookup(resolved_schema, "enum")
    if (child) {
        child = resolve_alias(child)
        if (node_kind[child] != "sequence") fail("JSON Schema enum must be an array")
        matched = 0
        for (i = 1; i <= sequence_count[child]; i++) if (expression_semantic_equal(resolved_instance, sequence_child[child, i])) matched = 1
        if (!matched) {
            schema_add_error(errors, instance_path, schema_path "/enum", "enum", "value is not in enum")
            valid = 0
        }
    }

    for (j = 1; j <= 3; j++) {
        keyword = j == 1 ? "allOf" : (j == 2 ? "anyOf" : "oneOf")
        child = mapping_lookup(resolved_schema, keyword)
        if (!child) continue
        child = resolve_alias(child)
        if (node_kind[child] != "sequence" || !sequence_count[child]) fail("JSON Schema " keyword " must be a non-empty array")
        count = 0
        if (keyword == "allOf") {
            for (i = 1; i <= sequence_count[child]; i++) {
                if (!schema_validate(resolved_instance, sequence_child[child, i], errors, instance_path, schema_path "/" keyword "/" (i - 1), root)) valid = 0
            }
        } else {
            for (i = 1; i <= sequence_count[child]; i++) {
                if (schema_trial(resolved_instance, sequence_child[child, i], instance_path, schema_path "/" keyword "/" (i - 1), root)) count++
            }
            if ((keyword == "anyOf" && count == 0) || (keyword == "oneOf" && count != 1)) {
                schema_add_error(errors, instance_path, schema_path "/" keyword, keyword, keyword == "anyOf" ? "value matches no subschema" : "value must match exactly one subschema")
                valid = 0
            }
        }
    }
    child = mapping_lookup(resolved_schema, "not")
    if (child && schema_trial(resolved_instance, child, instance_path, schema_path "/not", root)) {
        schema_add_error(errors, instance_path, schema_path "/not", "not", "value matches the forbidden schema")
        valid = 0
    }
    conditional = mapping_lookup(resolved_schema, "if")
    if (conditional) {
        if (schema_trial(resolved_instance, conditional, instance_path, schema_path "/if", root)) {
            child = mapping_lookup(resolved_schema, "then")
            if (child && !schema_validate(resolved_instance, child, errors, instance_path, schema_path "/then", root)) valid = 0
        } else {
            child = mapping_lookup(resolved_schema, "else")
            if (child && !schema_validate(resolved_instance, child, errors, instance_path, schema_path "/else", root)) valid = 0
        }
    }

    if (node_kind[resolved_instance] == "mapping") {
        size = expression_mapping_length(resolved_instance)
        child = mapping_lookup(resolved_schema, "minProperties")
        if (child && size < schema_nonnegative_integer(child, "minProperties")) {
            schema_add_error(errors, instance_path, schema_path "/minProperties", "minProperties", "object has too few properties")
            valid = 0
        }
        child = mapping_lookup(resolved_schema, "maxProperties")
        if (child && size > schema_nonnegative_integer(child, "maxProperties")) {
            schema_add_error(errors, instance_path, schema_path "/maxProperties", "maxProperties", "object has too many properties")
            valid = 0
        }
        required = mapping_lookup(resolved_schema, "required")
        if (required) {
            required = resolve_alias(required)
            if (node_kind[required] != "sequence") fail("JSON Schema required must be an array")
            for (i = 1; i <= sequence_count[required]; i++) {
                name_node = resolve_alias(sequence_child[required, i])
                if (node_kind[name_node] != "scalar" || node_type[name_node] != "string") fail("JSON Schema required names must be strings")
                key = node_value[name_node]
                if (!mapping_lookup(resolved_instance, key)) {
                    schema_add_error(errors, instance_path, schema_path "/required", "required", "required property is missing: " key)
                    valid = 0
                }
            }
        }
        properties = mapping_lookup(resolved_schema, "properties")
        if (properties && node_kind[resolve_alias(properties)] != "mapping") fail("JSON Schema properties must be an object")
        pattern_properties = mapping_lookup(resolved_schema, "patternProperties")
        if (pattern_properties && node_kind[resolve_alias(pattern_properties)] != "mapping") fail("JSON Schema patternProperties must be an object")
        additional = mapping_lookup(resolved_schema, "additionalProperties")
        name_schema = mapping_lookup(resolved_schema, "propertyNames")
        collection = ++collection_serial
        collect_mapping_keys(resolved_instance, collection)
        for (i = 1; i <= collection_count[collection]; i++) {
            key = collection_key[collection, i]
            instance_child = mapping_lookup(resolved_instance, key)
            if (name_schema) {
                name_node = expression_scalar(key, "string")
                if (!schema_validate(name_node, name_schema, errors, instance_path "/" patch_pointer_encode(key), schema_path "/propertyNames", root)) valid = 0
            }
            covered = 0
            if (properties) {
                property_schema = mapping_lookup(resolve_alias(properties), key)
                if (property_schema) {
                    covered = 1
                    if (!schema_validate(instance_child, property_schema, errors, instance_path "/" patch_pointer_encode(key), schema_path "/properties/" patch_pointer_encode(key), root)) valid = 0
                }
            }
            if (pattern_properties) {
                trial = ++collection_serial
                collect_mapping_keys(resolve_alias(pattern_properties), trial)
                for (j = 1; j <= collection_count[trial]; j++) {
                    pattern = collection_key[trial, j]
                    if (key ~ pattern) {
                        covered = 1
                        if (!schema_validate(instance_child, mapping_lookup(resolve_alias(pattern_properties), pattern), errors, instance_path "/" patch_pointer_encode(key), schema_path "/patternProperties/" patch_pointer_encode(pattern), root)) valid = 0
                    }
                }
            }
            if (!covered && additional) {
                child = resolve_alias(additional)
                if (node_kind[child] == "scalar" && node_type[child] == "bool") {
                    if (!schema_boolean(child, "additionalProperties")) {
                        schema_add_error(errors, instance_path "/" patch_pointer_encode(key), schema_path "/additionalProperties", "additionalProperties", "additional property is not allowed")
                        valid = 0
                    }
                } else if (!schema_validate(instance_child, child, errors, instance_path "/" patch_pointer_encode(key), schema_path "/additionalProperties", root)) valid = 0
            }
        }
        dependent = mapping_lookup(resolved_schema, "dependentRequired")
        if (dependent) {
            dependent = resolve_alias(dependent)
            if (node_kind[dependent] != "mapping") fail("JSON Schema dependentRequired must be an object")
            trial = ++collection_serial
            collect_mapping_keys(dependent, trial)
            for (i = 1; i <= collection_count[trial]; i++) {
                key = collection_key[trial, i]
                if (!mapping_lookup(resolved_instance, key)) continue
                dependency = resolve_alias(mapping_lookup(dependent, key))
                if (node_kind[dependency] != "sequence") fail("JSON Schema dependentRequired entries must be arrays")
                for (j = 1; j <= sequence_count[dependency]; j++) {
                    name_node = resolve_alias(sequence_child[dependency, j])
                    if (node_kind[name_node] != "scalar" || node_type[name_node] != "string") fail("JSON Schema dependentRequired names must be strings")
                    if (!mapping_lookup(resolved_instance, node_value[name_node])) {
                        schema_add_error(errors, instance_path, schema_path "/dependentRequired/" patch_pointer_encode(key), "dependentRequired", "dependent property is missing: " node_value[name_node])
                        valid = 0
                    }
                }
            }
        }
        dependent = mapping_lookup(resolved_schema, "dependentSchemas")
        if (dependent) {
            dependent = resolve_alias(dependent)
            if (node_kind[dependent] != "mapping") fail("JSON Schema dependentSchemas must be an object")
            trial = ++collection_serial
            collect_mapping_keys(dependent, trial)
            for (i = 1; i <= collection_count[trial]; i++) {
                key = collection_key[trial, i]
                if (mapping_lookup(resolved_instance, key) &&
                    !schema_validate(resolved_instance, mapping_lookup(dependent, key), errors, instance_path, schema_path "/dependentSchemas/" patch_pointer_encode(key), root)) valid = 0
            }
        }
    }

    if (node_kind[resolved_instance] == "sequence") {
        size = sequence_count[resolved_instance]
        child = mapping_lookup(resolved_schema, "minItems")
        if (child && size < schema_nonnegative_integer(child, "minItems")) {
            schema_add_error(errors, instance_path, schema_path "/minItems", "minItems", "array has too few items")
            valid = 0
        }
        child = mapping_lookup(resolved_schema, "maxItems")
        if (child && size > schema_nonnegative_integer(child, "maxItems")) {
            schema_add_error(errors, instance_path, schema_path "/maxItems", "maxItems", "array has too many items")
            valid = 0
        }
        child = mapping_lookup(resolved_schema, "uniqueItems")
        if (child && schema_boolean(child, "uniqueItems")) {
            for (i = 1; i <= size; i++) for (j = i + 1; j <= size; j++) {
                if (expression_semantic_equal(sequence_child[resolved_instance, i], sequence_child[resolved_instance, j])) {
                    schema_add_error(errors, instance_path, schema_path "/uniqueItems", "uniqueItems", "array items are not unique")
                    valid = 0
                    i = size
                    break
                }
            }
        }
        child = mapping_lookup(resolved_schema, "prefixItems")
        item_start = 1
        if (child) {
            child = resolve_alias(child)
            if (node_kind[child] != "sequence") fail("JSON Schema prefixItems must be an array")
            for (i = 1; i <= sequence_count[child] && i <= size; i++) {
                if (!schema_validate(sequence_child[resolved_instance, i], sequence_child[child, i], errors, instance_path "/" (i - 1), schema_path "/prefixItems/" (i - 1), root)) valid = 0
            }
            item_start = sequence_count[child] + 1
        }
        child = mapping_lookup(resolved_schema, "items")
        if (child) for (i = item_start; i <= size; i++) {
            if (!schema_validate(sequence_child[resolved_instance, i], child, errors, instance_path "/" (i - 1), schema_path "/items", root)) valid = 0
        }
        child = mapping_lookup(resolved_schema, "contains")
        if (child) {
            contains_count = 0
            for (i = 1; i <= size; i++) if (schema_trial(sequence_child[resolved_instance, i], child, instance_path "/" (i - 1), schema_path "/contains", root)) contains_count++
            min_contains = mapping_lookup(resolved_schema, "minContains") ? schema_nonnegative_integer(mapping_lookup(resolved_schema, "minContains"), "minContains") : 1
            max_contains = mapping_lookup(resolved_schema, "maxContains") ? schema_nonnegative_integer(mapping_lookup(resolved_schema, "maxContains"), "maxContains") : -1
            if (contains_count < min_contains || (max_contains >= 0 && contains_count > max_contains)) {
                schema_add_error(errors, instance_path, schema_path "/contains", "contains", "array contains count is outside the allowed range")
                valid = 0
            }
        }
    }

    if (node_kind[resolved_instance] == "scalar" && node_type[resolved_instance] == "string") {
        size = schema_utf8_length(node_value[resolved_instance])
        child = mapping_lookup(resolved_schema, "minLength")
        if (child && size < schema_nonnegative_integer(child, "minLength")) {
            schema_add_error(errors, instance_path, schema_path "/minLength", "minLength", "string is too short")
            valid = 0
        }
        child = mapping_lookup(resolved_schema, "maxLength")
        if (child && size > schema_nonnegative_integer(child, "maxLength")) {
            schema_add_error(errors, instance_path, schema_path "/maxLength", "maxLength", "string is too long")
            valid = 0
        }
        child = mapping_lookup(resolved_schema, "pattern")
        if (child) {
            child = resolve_alias(child)
            if (node_kind[child] != "scalar" || node_type[child] != "string") fail("JSON Schema pattern must be a string")
            if (node_value[resolved_instance] !~ node_value[child]) {
                schema_add_error(errors, instance_path, schema_path "/pattern", "pattern", "string does not match the required pattern")
                valid = 0
            }
        }
    }

    if (node_kind[resolved_instance] == "scalar" && (node_type[resolved_instance] == "int" || node_type[resolved_instance] == "float")) {
        number = node_value[resolved_instance] + 0
        child = mapping_lookup(resolved_schema, "minimum")
        if (child && number < schema_number(child, "minimum")) {
            schema_add_error(errors, instance_path, schema_path "/minimum", "minimum", "number is below the minimum")
            valid = 0
        }
        child = mapping_lookup(resolved_schema, "maximum")
        if (child && number > schema_number(child, "maximum")) {
            schema_add_error(errors, instance_path, schema_path "/maximum", "maximum", "number is above the maximum")
            valid = 0
        }
        child = mapping_lookup(resolved_schema, "exclusiveMinimum")
        if (child && number <= schema_number(child, "exclusiveMinimum")) {
            schema_add_error(errors, instance_path, schema_path "/exclusiveMinimum", "exclusiveMinimum", "number is not above the exclusive minimum")
            valid = 0
        }
        child = mapping_lookup(resolved_schema, "exclusiveMaximum")
        if (child && number >= schema_number(child, "exclusiveMaximum")) {
            schema_add_error(errors, instance_path, schema_path "/exclusiveMaximum", "exclusiveMaximum", "number is not below the exclusive maximum")
            valid = 0
        }
        child = mapping_lookup(resolved_schema, "multipleOf")
        if (child) {
            minimum = schema_number(child, "multipleOf")
            if (minimum <= 0) fail("JSON Schema multipleOf must be greater than zero")
            maximum = number / minimum
            if (maximum < 0) maximum = -maximum
            numeric_text = tolower(sprintf("%.15g", maximum))
            if (numeric_text ~ /inf|nan/ || maximum - int(maximum + 0.000000000001) > 0.000000001) {
                schema_add_error(errors, instance_path, schema_path "/multipleOf", "multipleOf", "number is not a multiple of the required value")
                valid = 0
            }
        }
    }

    schema_validation_depth--
    return valid
}

function schema_errors(instance, schema,    errors) {
    errors = new_node("sequence", 0, "", "", "")
    schema_validation_depth = 0
    schema_validate(instance, schema, errors, "", "#", resolve_alias(schema))
    return errors
}

function explain_path(node,    depth, current, parent, edge, i, result, key) {
    depth = 0
    current = node
    while (current) {
        if ((current in expression_missing_parent) && !expression_placeholder_attached[current]) {
            parent = expression_missing_parent[current]
            edge = "key " expression_missing_key[current]
        } else if (current in node_parent) {
            parent = node_parent[current]
            edge = node_parent_edge[current]
        } else {
            break
        }
        explain_path_edge[++depth] = edge
        current = parent
    }
    result = ""
    for (i = depth; i >= 1; i--) {
        edge = explain_path_edge[i]
        if (substr(edge, 1, 6) == "index ") {
            result = result "[" substr(edge, 7) "]"
        } else {
            key = substr(edge, 5)
            if (key ~ /^[A-Za-z_][A-Za-z0-9_-]*$/) {
                result = result "." key
            } else {
                result = result "[" json_quote(key) "]"
            }
        }
        delete explain_path_edge[i]
    }
    return result == "" ? "." : result
}

function explain_record_mutation(kind, path, node,    file) {
    explain_mutation_count++
    file = expression_input_file(node)
    explain_mutation_file[explain_mutation_count] = file
    if (kind == "insert") {
        explain_insertion_count++
    } else if (kind == "delete") {
        explain_deletion_count++
    } else {
        explain_replacement_count++
    }
    if (explain_mode == 2 || explain_mutation_count <= 20) {
        explain_mutation_kind[explain_mutation_count] = kind
        explain_mutation_path[explain_mutation_count] = path
    }
}

function explain_input_target(node,    current, document) {
    current = node
    while (current) {
        if ((current in expression_missing_parent) && !expression_placeholder_attached[current]) {
            current = expression_missing_parent[current]
        } else if (current in node_parent) {
            current = node_parent[current]
        } else {
            break
        }
    }
    for (document = 0; document <= document_index; document++) {
        if ((document in document_root) && document_root[document] == current) {
            return 1
        }
    }
    return 0
}

function expression_input_file(node,    current) {
    current = node
    while (current) {
        if ((current in expression_missing_parent) && !expression_placeholder_attached[current]) {
            current = expression_missing_parent[current]
        } else if (current in node_parent) {
            current = node_parent[current]
        } else {
            break
        }
    }
    return (current in node_file_index) ? node_file_index[current] : input_file_index + 0
}

function expression_mark_changed(node,    file) {
    expression_any_change = 1
    file = expression_input_file(node)
    expression_file_changed[file] = 1
}

function expression_envsubst(value, options,    result, i, char, closing, name, start, body, suffix, replacement, is_set) {
    result = ""
    i = 1
    while (i <= length(value)) {
        char = substr(value, i, 1)
        if (char != "$") {
            result = result char
            i++
            continue
        }
        if (substr(value, i + 1, 1) == "{") {
            closing = index(substr(value, i + 2), "}")
            if (!closing) {
                result = result char
                i++
                continue
            }
            body = substr(value, i + 2, closing - 1)
            name = ""
            start = 1
            if (substr(body, start, 1) ~ /^[A-Za-z_]$/) {
                while (substr(body, start, 1) ~ /^[A-Za-z0-9_]$/) {
                    name = name substr(body, start, 1)
                    start++
                }
            }
            suffix = substr(body, start)
            is_set = name in ENVIRON
            if (name == "") {
                result = result substr(value, i, closing + 2)
            } else if (substr(suffix, 1, 2) == ":-") {
                replacement = substr(suffix, 3)
                if (!is_set || ENVIRON[name] == "") {
                    result = result replacement
                } else {
                    result = result ENVIRON[name]
                }
            } else if (substr(suffix, 1, 1) == "-") {
                replacement = substr(suffix, 2)
                if (is_set) {
                    result = result ENVIRON[name]
                } else {
                    result = result replacement
                }
            } else if (suffix != "") {
                result = result substr(value, i, closing + 2)
            } else {
                if (index(options, " nu ") && !is_set) {
                    fail("environment variable " name " is not set")
                }
                if (index(options, " ne ") && is_set && ENVIRON[name] == "") {
                    fail("environment variable " name " is empty")
                }
                result = result ENVIRON[name]
            }
            i += closing + 2
            continue
        }
        start = i + 1
        name = ""
        if (substr(value, start, 1) ~ /^[A-Za-z_]$/) {
            while (substr(value, start, 1) ~ /^[A-Za-z0-9_]$/) {
                name = name substr(value, start, 1)
                start++
            }
        }
        if (name == "") {
            result = result char
            i++
        } else {
            if (index(options, " nu ") && !(name in ENVIRON)) {
                fail("environment variable " name " is not set")
            }
            if (index(options, " ne ") && (name in ENVIRON) && ENVIRON[name] == "") {
                fail("environment variable " name " is empty")
            }
            result = result ENVIRON[name]
            i = start
        }
    }
    return result
}

function expression_sort_mapping(node,    result, collection, count, i, j, key) {
    result = new_node("mapping", 0, "", "", "")
    collection = ++collection_serial
    collect_mapping_keys(node, collection)
    count = collection_count[collection]
    for (i = 1; i <= count; i++) {
        key = collection_key[collection, i]
        j = i
        while (j > 1 && key < expression_sorted_key[j - 1]) {
            expression_sorted_key[j] = expression_sorted_key[j - 1]
            j--
        }
        expression_sorted_key[j] = key
    }
    for (i = 1; i <= count; i++) {
        key = expression_sorted_key[i]
        add_mapping(result, key, expression_clone_node(mapping_lookup(node, key)), 0, 0)
        delete expression_sorted_key[i]
    }
    return result
}

function expression_sort_keys_clone(node, recursive,    resolved, result, i, replacement) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] == "mapping") {
        result = expression_sort_mapping(resolved)
        if (recursive) {
            for (i = 1; i <= mapping_count[result]; i++) {
                replacement = expression_sort_keys_clone(mapping_child[result, i], 1)
                mapping_child[result, i] = replacement
                node_parent[replacement] = result
                node_parent_edge[replacement] = "key " mapping_key[result, i]
            }
        }
        return result
    }
    result = expression_clone_node(node)
    if (recursive && node_kind[resolved] == "sequence") {
        for (i = 1; i <= sequence_count[result]; i++) {
            replacement = expression_sort_keys_clone(sequence_child[result, i], 1)
            sequence_child[result, i] = replacement
            node_parent[replacement] = result
            node_parent_edge[replacement] = "index " (i - 1)
        }
    }
    return result
}

function expression_predicate_matches(expression, node,    stream, result, i) {
    stream = expression_stream_single(node)
    result = expression_evaluate(expression, stream)
    for (i = 1; i <= expression_stream_count[result]; i++) {
        if (expression_truthy(expression_stream_node[result, i])) {
            return 1
        }
    }
    return 0
}

function expression_pick_or_omit(node, choices, omit_mode,    result, selected, i, j, choice, key, child, collection) {
    if (node_kind[node] != "mapping" && node_kind[node] != "sequence") {
        fail((omit_mode ? "omit" : "pick") " requires a mapping or sequence")
    }
    result = new_node(node_kind[node], 0, "", "", "")
    selected = ++expression_selection_serial
    for (i = 1; i <= sequence_count[choices]; i++) {
        choice = resolve_alias(sequence_child[choices, i])
        if (node_kind[choice] != "scalar") {
            fail((omit_mode ? "omit" : "pick") " choices must be scalar keys or indexes")
        }
        if (node_kind[node] == "mapping") {
            key = node_value[choice]
            child = mapping_lookup(node, key)
            if (child && !(selected SUBSEP key in expression_selected)) {
                expression_selected[selected, key] = 1
                if (!omit_mode) {
                    add_mapping(result, key, expression_clone_node(child), 0, 0)
                }
            }
        } else if (node_type[choice] == "int") {
            j = node_value[choice] + 0
            if (j >= 0 && j < sequence_count[node]) {
                expression_selected[selected, j] = 1
                if (!omit_mode) {
                    add_sequence(result, expression_clone_node(sequence_child[node, j + 1]), 0)
                }
            }
        }
    }
    if (omit_mode && node_kind[node] == "mapping") {
        collection = ++collection_serial
        collect_mapping_keys(node, collection)
        for (i = 1; i <= collection_count[collection]; i++) {
            key = collection_key[collection, i]
            if (!(selected SUBSEP key in expression_selected)) {
                add_mapping(result, key, expression_clone_node(mapping_lookup(node, key)), 0, 0)
            }
        }
    } else if (omit_mode) {
        for (i = 0; i < sequence_count[node]; i++) {
            if (!(selected SUBSEP i in expression_selected)) {
                add_sequence(result, expression_clone_node(sequence_child[node, i + 1]), 0)
            }
        }
    }
    return result
}

function expression_pivot(node,    result, first, mode, max_count, i, j, child, row, collection, key, seen) {
    if (node_kind[node] != "sequence") {
        fail("pivot requires a sequence")
    }
    if (!sequence_count[node]) {
        return new_node("sequence", 0, "", "", "")
    }
    first = resolve_alias(sequence_child[node, 1])
    mode = node_kind[first]
    if (mode != "sequence" && mode != "mapping") {
        fail("pivot requires a sequence of sequences or mappings")
    }
    for (i = 1; i <= sequence_count[node]; i++) {
        child = resolve_alias(sequence_child[node, i])
        if (node_kind[child] != mode) {
            fail("pivot requires homogeneous collection kinds")
        }
        if (mode == "sequence" && sequence_count[child] > max_count) {
            max_count = sequence_count[child]
        }
    }
    if (mode == "sequence") {
        result = new_node("sequence", 0, "", "", "")
        for (j = 1; j <= max_count; j++) {
            row = new_node("sequence", 0, "", "", "")
            for (i = 1; i <= sequence_count[node]; i++) {
                child = resolve_alias(sequence_child[node, i])
                add_sequence(row, j <= sequence_count[child] ? expression_clone_node(sequence_child[child, j]) : expression_null(), 0)
            }
            add_sequence(result, row, 0)
        }
        return result
    }
    result = new_node("mapping", 0, "", "", "")
    seen = ++expression_selection_serial
    for (i = 1; i <= sequence_count[node]; i++) {
        child = resolve_alias(sequence_child[node, i])
        collection = ++collection_serial
        collect_mapping_keys(child, collection)
        for (j = 1; j <= collection_count[collection]; j++) {
            key = collection_key[collection, j]
            if (!(seen SUBSEP key in expression_selected)) {
                expression_selected[seen, key] = 1
                row = new_node("sequence", 0, "", "", "")
                add_mapping(result, key, row, 0, 0)
            }
        }
    }
    collection = ++collection_serial
    collect_mapping_keys(result, collection)
    for (j = 1; j <= collection_count[collection]; j++) {
        key = collection_key[collection, j]
        row = mapping_lookup(result, key)
        for (i = 1; i <= sequence_count[node]; i++) {
            child = resolve_alias(sequence_child[node, i])
            add_sequence(row, mapping_lookup(child, key) ? expression_clone_node(mapping_lookup(child, key)) : expression_null(), 0)
        }
    }
    return result
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
    while (expression_token_type == "arithmetic" && (substr(expression_token_value, 1, 1) == "*" || expression_token_value == "/" || expression_token_value == "%")) {
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

function expression_parse_pipe(    left, right, variable, initial, update, reduction) {
    left = expression_parse_assignment()
    if (expression_token_type == "ref") {
        expression_lex_next()
        if (expression_token_type != "variable") fail("ref requires a variable")
        variable = expression_token_value
        expression_lex_next()
        expression_expect("pipe")
        right = expression_parse_pipe()
        return expression_new("bind", left, right, variable)
    }
    if (expression_token_type == "as") {
        expression_lex_next()
        if (expression_token_type != "variable") {
            fail("as requires a variable")
        }
        variable = expression_token_value
        expression_lex_next()
        if (expression_token_type == "identifier" && tolower(expression_token_value) == "ireduce") {
            expression_lex_next()
            expression_expect("left_parenthesis")
            initial = expression_parse_pipe()
            expression_expect("semicolon")
            update = expression_parse_pipe()
            expression_expect("right_parenthesis")
            reduction = expression_new("reduce", left, initial, variable)
            expression_child[reduction, 1] = update
            if (expression_token_type == "pipe") {
                expression_lex_next()
                right = expression_parse_pipe()
                return expression_new("pipe", reduction, right, "")
            }
            return reduction
        }
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
    return node_type[left_node] == node_type[right_node] && node_value[left_node] == node_value[right_node]
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
    if (resolved in node_style) {
        node_style[clone] = node_style[resolved]
    }
    if (resolved in node_line_comment) {
        node_line_comment[clone] = node_line_comment[resolved]
    }
    if (resolved in node_head_comment) node_head_comment[clone] = node_head_comment[resolved]
    if (resolved in node_foot_comment) node_foot_comment[clone] = node_foot_comment[resolved]
    if (resolved in node_key_head_comment) node_key_head_comment[clone] = node_key_head_comment[resolved]
    if (resolved in node_key_foot_comment) node_key_foot_comment[clone] = node_key_foot_comment[resolved]
    if (resolved in node_key_line_comment) node_key_line_comment[clone] = node_key_line_comment[resolved]
    if (node_line_comment_modified[resolved]) {
        node_line_comment_modified[clone] = 1
    }
    if (node_head_comment_modified[resolved]) node_head_comment_modified[clone] = 1
    if (node_foot_comment_modified[resolved]) node_foot_comment_modified[clone] = 1
    if (node_key_head_comment_modified[resolved]) node_key_head_comment_modified[clone] = 1
    if (node_key_foot_comment_modified[resolved]) node_key_foot_comment_modified[clone] = 1
    if (node_key_line_comment_modified[resolved]) node_key_line_comment_modified[clone] = 1
    delete node_document[clone]
    delete node_file_index[clone]
    delete node_filename[clone]
    if (resolved in node_document) {
        node_document[clone] = node_document[resolved]
    }
    if (resolved in node_file_index) {
        node_file_index[clone] = node_file_index[resolved]
    }
    if (resolved in node_filename) {
        node_filename[clone] = node_filename[resolved]
    }
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

function expression_node_state_equal(left, right,    i) {
    if (node_kind[left] != node_kind[right] || node_type[left] != node_type[right] ||
        node_value[left] != node_value[right] || node_tag[left] != node_tag[right] ||
        node_anchor[left] != node_anchor[right]) {
        return 0
    }
    if (node_kind[left] == "alias") {
        return node_value[left] == node_value[right]
    }
    if (node_kind[left] == "sequence") {
        if (sequence_count[left] != sequence_count[right]) {
            return 0
        }
        for (i = 1; i <= sequence_count[left]; i++) {
            if (!expression_node_state_equal(sequence_child[left, i], sequence_child[right, i])) {
                return 0
            }
        }
    } else if (node_kind[left] == "mapping") {
        if (mapping_count[left] != mapping_count[right]) {
            return 0
        }
        for (i = 1; i <= mapping_count[left]; i++) {
            if (mapping_key[left, i] != mapping_key[right, i] || mapping_merge[left, i] != mapping_merge[right, i] ||
                !expression_node_state_equal(mapping_child[left, i], mapping_child[right, i])) {
                return 0
            }
        }
    }
    return 1
}

function expression_replace_node(target, source,    clone, saved_parent, saved_edge, saved_line, saved_document, i, key, child) {
    expression_last_replace_changed = 0
    if (resolve_alias(target) == resolve_alias(source) && !(target in expression_missing_parent)) {
        return target
    }
    if (!(target in expression_missing_parent) && expression_node_state_equal(target, resolve_alias(source))) {
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
    expression_last_replace_changed = 1
    return target
}

function expression_delete_node(target,    parent, i, j, key, child) {
    expression_last_delete_changed = 0
    if (target in expression_missing_parent && !expression_placeholder_attached[target]) {
        return
    }
    if (inplace_mode) {
        presentation_track_delete(target)
    }
    parent = (target in node_parent) ? node_parent[target] : 0
    if (!parent) {
        expression_clear_node(target)
        node_kind[target] = "scalar"
        node_value[target] = ""
        node_type[target] = "null"
        node_tag[target] = ""
        expression_last_delete_changed = 1
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
            expression_last_delete_changed = 1
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
            expression_last_delete_changed = 1
            return
        }
    }
}

function expression_prepare_path_container(node, kind) {
    node = resolve_alias(node)
    if (node_kind[node] == kind) {
        return node
    }
    if (node_kind[node] != "scalar" || node_type[node] != "null") {
        fail("cannot traverse " expression_type_name(node) " as a " kind)
    }
    expression_clear_node(node)
    node_kind[node] = kind
    node_value[node] = ""
    node_type[node] = ""
    node_tag[node] = ""
    return node
}

function expression_follow_path(root, path_node, create,    path, current, segment, child, key, path_index, i) {
    expression_path_was_missing = 0
    path = resolve_alias(path_node)
    if (node_kind[path] != "sequence") {
        fail("path must be an array")
    }
    current = root
    for (i = 1; i <= sequence_count[path]; i++) {
        segment = resolve_alias(sequence_child[path, i])
        current = resolve_alias(current)
        if (node_kind[segment] != "scalar" || (node_type[segment] != "string" && node_type[segment] != "int")) {
            fail("path components must be strings or integers")
        }
        if (node_type[segment] == "string") {
            key = node_value[segment]
            if (node_kind[current] != "mapping") {
                if (!create) {
                    return 0
                }
                current = expression_prepare_path_container(current, "mapping")
            }
            child = mapping_lookup(current, key)
            if (!child) {
                if (!create) {
                    return 0
                }
                child = expression_null()
                add_mapping(current, key, child, 0, 0)
                expression_path_was_missing = 1
            }
        } else {
            path_index = node_value[segment] + 0
            if (path_index < 0) {
                fail("path indexes must be non-negative")
            }
            if (node_kind[current] != "sequence") {
                if (!create) {
                    return 0
                }
                current = expression_prepare_path_container(current, "sequence")
            }
            if (path_index >= sequence_count[current]) {
                if (!create) {
                    return 0
                }
                while (sequence_count[current] <= path_index) {
                    add_sequence(current, expression_null(), 0)
                }
                expression_path_was_missing = 1
            }
            child = sequence_child[current, path_index + 1]
        }
        current = child
    }
    return current
}

function expression_node_property_value(node, property,    value) {
    if (property == "style") {
        value = node_style[node]
        return value == "plain" ? "" : value
    }
    if (property == "line_comment") {
        return node_line_comment[node]
    }
    if (property == "head_comment") return node_head_comment[node]
    if (property == "foot_comment") return node_foot_comment[node]
    if (property == "tag") {
        return expression_type_name(node)
    }
    if (property == "anchor") {
        return node_anchor[node]
    }
    return node_kind[node] == "alias" ? node_value[node] : ""
}

function expression_normalize_tag(value) {
    if (value == "") {
        return ""
    }
    if (substr(value, 1, 2) == "!!") {
        return "tag:yaml.org,2002:" substr(value, 3)
    }
    if (substr(value, 1, 2) == "!<" && substr(value, length(value), 1) == ">") {
        return substr(value, 3, length(value) - 3)
    }
    if (substr(value, 1, 1) == "!" || value ~ /^tag:/) {
        return value
    }
    fail("tag must be empty, a YAML tag such as !!str, or an absolute tag URI")
}

function expression_node_document(node,    current, document) {
    current = node
    while (current in node_parent) {
        current = node_parent[current]
    }
    for (document = 0; document <= document_index; document++) {
        if ((document in document_root) && document_root[document] == current) {
            return document
        }
    }
    return -1
}

function expression_anchor_references(node,    candidate, count) {
    count = 0
    for (candidate = 1; candidate <= node_count; candidate++) {
        if (node_kind[candidate] == "alias" && alias_target[candidate] == node) {
            count++
        }
    }
    return count
}

function expression_refresh_anchor_target(document, name,    candidate, best) {
    if (name == "") {
        return
    }
    delete anchor_target[document SUBSEP name]
    best = 0
    for (candidate = 1; candidate <= node_count; candidate++) {
        if (node_anchor[candidate] == name && expression_node_document(candidate) == document && candidate > best) {
            best = candidate
        }
    }
    if (best) {
        anchor_target[document SUBSEP name] = best
    }
}

function expression_set_anchor(node, value,    candidate, document, old_value) {
    if (node_kind[node] == "alias") {
        fail("anchor cannot be set on an alias")
    }
    if (value != "" && !valid_anchor_name(value)) {
        fail("invalid anchor name: " value)
    }
    if (value == "" && expression_anchor_references(node)) {
        fail("cannot remove an anchor while aliases still reference it")
    }
    document = expression_node_document(node)
    for (candidate = 1; candidate <= node_count; candidate++) {
        if (candidate != node && node_anchor[candidate] == value && value != "" &&
            expression_node_document(candidate) == document) {
            fail("duplicate anchor name: " value)
        }
    }
    old_value = node_anchor[node]
    node_anchor[node] = value
    if (old_value != value) {
        for (candidate = 1; candidate <= node_count; candidate++) {
            if (node_kind[candidate] == "alias" && alias_target[candidate] == node) {
                node_value[candidate] = value
            }
        }
        expression_refresh_anchor_target(document, old_value)
        expression_refresh_anchor_target(document, value)
    }
}

function expression_set_alias(node, value,    document, target, parent) {
    if (value == "") {
        fail("alias must name an anchor")
    }
    if (!valid_anchor_name(value)) {
        fail("invalid alias name: " value)
    }
    if (expression_anchor_references(node)) {
        fail("cannot replace an anchor while aliases still reference it")
    }
    document = expression_node_document(node)
    target = anchor_target[document SUBSEP value]
    if (!target) {
        fail("unknown anchor for alias: " value)
    }
    if (target >= node) {
        fail("forward alias is not supported: " value)
    }
    parent = node_parent[node]
    while (parent) {
        if (parent == target) {
            fail("recursive alias: " value)
        }
        parent = node_parent[parent]
    }
    expression_clear_node(node)
    node_kind[node] = "alias"
    node_value[node] = value
    node_type[node] = ""
    node_tag[node] = ""
    delete node_style[node]
    alias_target[node] = target
}

function expression_set_node_property(node, property, value_node,    resolved, value, old_value, new_value, tag) {
    expression_last_property_changed = 0
    resolved = resolve_alias(value_node)
    if (node_kind[resolved] != "scalar" || node_type[resolved] != "string") {
        fail(property " must be set to a string")
    }
    value = node_value[resolved]
    if (node_key_reference[node] && (property == "line_comment" || property == "head_comment" || property == "foot_comment")) {
        node = node_origin[node]
        old_value = property == "line_comment" ? node_key_line_comment[node] : (property == "head_comment" ? node_key_head_comment[node] : node_key_foot_comment[node])
        if (value == old_value) return
        if (property == "line_comment") {
            node_key_line_comment[node] = value
            node_key_line_comment_modified[node] = 1
        } else if (property == "head_comment") {
            node_key_head_comment[node] = value
            node_key_head_comment_modified[node] = 1
        } else {
            node_key_foot_comment[node] = value
            node_key_foot_comment_modified[node] = 1
        }
        if (inplace_mode && !presentation_track_comment(node, property, 1, value)) presentation_possible = 0
        expression_last_property_changed = 1
        return
    }
    old_value = expression_node_property_value(node, property)
    new_value = property == "style" && value == "plain" ? "" : value
    if (new_value == old_value) {
        return
    }
    if (property == "style") {
        if (node_kind[node] == "scalar") {
            if (value != "" && value != "plain" && value != "single" && value != "double" &&
                value != "literal" && value != "folded") {
                fail("scalar style must be plain, single, double, literal, or folded")
            }
            if (value == "plain" && node_type[node] == "string" && !presentation_plain_safe(node_value[node])) {
                fail("value cannot be represented safely in plain style")
            }
            if ((value == "literal" || value == "folded") && node_type[node] != "string") {
                fail(value " style requires a string scalar")
            }
            if (value == "") {
                delete node_style[node]
            } else {
                node_style[node] = value
            }
        } else if (node_kind[node] == "mapping" || node_kind[node] == "sequence") {
            if (value != "" && value != "flow") {
                fail("collection style must be flow or empty")
            }
            if (value == "") {
                delete node_style[node]
            } else {
                node_style[node] = value
            }
        } else {
            fail("style cannot be set on an alias")
        }
    } else if (property == "line_comment") {
        node_line_comment[node] = value
        node_line_comment_modified[node] = 1
    } else if (property == "head_comment") {
        node_head_comment[node] = value
        node_head_comment_modified[node] = 1
    } else if (property == "foot_comment") {
        node_foot_comment[node] = value
        node_foot_comment_modified[node] = 1
    } else if (property == "tag") {
        if (node_kind[node] == "alias") {
            fail("tag cannot be set on an alias")
        }
        tag = expression_normalize_tag(value)
        node_tag[node] = tag
        if (node_kind[node] == "scalar") {
            node_type[node] = scalar_type(node_value[node], tag, node_value[node])
        }
    } else if (property == "anchor") {
        expression_set_anchor(node, value)
    } else if (property == "alias") {
        expression_set_alias(node, value)
    }
    if (inplace_mode) {
        if (presentation_flow_owner(node) &&
            !(property == "style" && (node_kind[node] == "mapping" || node_kind[node] == "sequence") && old_value != "flow")) {
            presentation_track_replace(node, node)
        } else if ((property == "style" || property == "line_comment") && node_kind[node] == "scalar" &&
            node_style[node] != "literal" && node_style[node] != "folded") {
            presentation_track_replace(node, node)
        } else if (property == "line_comment" && node_kind[node] == "scalar" &&
            (node_style[node] == "literal" || node_style[node] == "folded")) {
            presentation_track_owned_span(node)
        } else if (property == "head_comment" || property == "foot_comment") {
            if (!presentation_track_comment(node, property, 0, value)) presentation_possible = 0
        } else {
            presentation_possible = 0
        }
    }
    expression_last_property_changed = 1
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

function expression_deep_merge(left, right, flags,    left_node, right_node, result, collection, i, key, child, existing, merged, only_existing, only_new, append_arrays, deep_arrays) {
    left_node = resolve_alias(left)
    right_node = resolve_alias(right)
    only_existing = index(flags, "?") > 0
    only_new = index(flags, "n") > 0
    append_arrays = index(flags, "+") > 0
    deep_arrays = index(flags, "d") > 0
    if (node_kind[left_node] == "sequence" && node_kind[right_node] == "sequence") {
        result = expression_clone_node(left_node)
        if (append_arrays) {
            if (only_new) {
                return result
            }
            for (i = 1; i <= sequence_count[right_node]; i++) {
                add_sequence(result, expression_clone_node(sequence_child[right_node, i]), 0)
            }
            return result
        }
        if (deep_arrays) {
            for (i = 1; i <= sequence_count[right_node]; i++) {
                child = sequence_child[right_node, i]
                if (i <= sequence_count[result]) {
                    existing = sequence_child[result, i]
                    if (only_new &&
                        !((node_kind[resolve_alias(existing)] == "mapping" && node_kind[resolve_alias(child)] == "mapping") ||
                          (node_kind[resolve_alias(existing)] == "sequence" && node_kind[resolve_alias(child)] == "sequence"))) {
                        continue
                    }
                    merged = expression_deep_merge(existing, child, flags)
                    expression_replace_node(existing, merged)
                } else if (!only_existing) {
                    add_sequence(result, expression_clone_node(child), 0)
                }
            }
            return result
        }
        return only_new ? result : expression_clone_node(right_node)
    }
    if (node_kind[left_node] != "mapping" || node_kind[right_node] != "mapping") {
        return only_new ? expression_clone_node(left_node) : expression_clone_node(right_node)
    }
    result = expression_clone_node(left_node)
    collection = ++collection_serial
    collect_mapping_keys(right_node, collection)
    for (i = 1; i <= collection_count[collection]; i++) {
        key = collection_key[collection, i]
        child = mapping_lookup(right_node, key)
        existing = mapping_lookup(result, key)
        if (!existing) {
            if (!only_existing) {
                add_mapping(result, key, expression_clone_node(child), 0, 0)
            }
        } else if (node_kind[resolve_alias(existing)] == "mapping" && node_kind[resolve_alias(child)] == "mapping") {
            merged = expression_deep_merge(existing, child, flags)
            expression_replace_node(existing, merged)
        } else if (node_kind[resolve_alias(existing)] == "sequence" && node_kind[resolve_alias(child)] == "sequence" &&
            (deep_arrays || (append_arrays && !only_new))) {
            merged = expression_deep_merge(existing, child, flags)
            expression_replace_node(existing, merged)
        } else if (only_new) {
            continue
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
    if (substr(operator, 1, 1) == "*" &&
        ((node_kind[left_node] == "mapping" && node_kind[right_node] == "mapping") ||
         (node_kind[left_node] == "sequence" && node_kind[right_node] == "sequence"))) {
        return expression_deep_merge(left_node, right_node, substr(operator, 2))
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

function expression_json_text(node,    resolved, result, i, collection, key) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] == "scalar") {
        if (node_type[resolved] == "null") {
            return "null"
        }
        if (node_type[resolved] == "bool" || node_type[resolved] == "int" || node_type[resolved] == "float") {
            return node_value[resolved]
        }
        return json_quote(node_value[resolved])
    }
    if (node_kind[resolved] == "sequence") {
        result = "["
        for (i = 1; i <= sequence_count[resolved]; i++) {
            if (i > 1) {
                result = result ","
            }
            result = result expression_json_text(sequence_child[resolved, i])
        }
        return result "]"
    }
    collection = ++collection_serial
    collect_mapping_keys(resolved, collection)
    result = "{"
    for (i = 1; i <= collection_count[collection]; i++) {
        key = collection_key[collection, i]
        if (i > 1) {
            result = result ","
        }
        result = result json_quote(key) ":" expression_json_text(mapping_lookup(resolved, key))
    }
    return result "}"
}

function expression_json_pretty_text(node, step, level,    resolved, result, i, collection, key, child_indent, prefix) {
    if (step <= 0) return expression_json_text(node)
    resolved = resolve_alias(node)
    if (node_kind[resolved] == "scalar") return expression_json_text(resolved)
    child_indent = yaml_spaces((level + 1) * step)
    prefix = yaml_spaces(level * step)
    if (node_kind[resolved] == "sequence") {
        if (!sequence_count[resolved]) return "[]"
        result = "[\n"
        for (i = 1; i <= sequence_count[resolved]; i++) {
            if (i > 1) result = result ",\n"
            result = result child_indent expression_json_pretty_text(sequence_child[resolved, i], step, level + 1)
        }
        return result "\n" prefix "]"
    }
    collection = ++collection_serial
    collect_mapping_keys(resolved, collection)
    if (!collection_count[collection]) return "{}"
    result = "{\n"
    for (i = 1; i <= collection_count[collection]; i++) {
        key = collection_key[collection, i]
        if (i > 1) result = result ",\n"
        result = result child_indent json_quote(key) ": " expression_json_pretty_text(mapping_lookup(resolved, key), step, level + 1)
    }
    return result "\n" prefix "}"
}

function expression_yaml_scalar_text(node,    resolved, value) {
    if (node_kind[node] == "alias") {
        return "*" node_value[node]
    }
    resolved = resolve_alias(node)
    value = node_value[resolved]
    if (node_type[resolved] == "null" && value == "") {
        return "null"
    }
    if (node_type[resolved] != "string" || presentation_plain_safe(value)) {
        return value
    }
    return json_quote(value)
}

function expression_yaml_inline_text(node,    resolved) {
    if (node_kind[node] == "alias" || node_kind[resolve_alias(node)] == "scalar") {
        return expression_yaml_scalar_text(node)
    }
    resolved = resolve_alias(node)
    if ((node_kind[resolved] == "mapping" && !mapping_count[resolved]) ||
        (node_kind[resolved] == "sequence" && !sequence_count[resolved])) {
        return node_kind[resolved] == "mapping" ? "{}" : "[]"
    }
    if (node_style[resolved] == "flow") {
        return expression_yaml_flow_text(resolved)
    }
    return ""
}

function expression_yaml_flow_text(node,    resolved, result, i, key) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] == "scalar" || node_kind[node] == "alias") {
        return expression_yaml_scalar_text(node)
    }
    result = node_kind[resolved] == "sequence" ? "[" : "{"
    if (node_kind[resolved] == "sequence") {
        for (i = 1; i <= sequence_count[resolved]; i++) {
            if (i > 1) result = result ", "
            result = result expression_yaml_flow_text(sequence_child[resolved, i])
        }
        return result "]"
    }
    for (i = 1; i <= mapping_count[resolved]; i++) {
        if (i > 1) result = result ", "
        key = mapping_key[resolved, i]
        key = presentation_plain_safe(key) ? key : json_quote(key)
        result = result key ": " expression_yaml_flow_text(mapping_child[resolved, i])
    }
    return result "}"
}

function expression_yaml_text(node, indent, step,    resolved, result, i, key, child, inline, prefix) {
    if (step == "") step = yaml_indent
    if (node_kind[node] == "alias") {
        return expression_yaml_scalar_text(node)
    }
    resolved = resolve_alias(node)
    if (node_kind[resolved] == "scalar") {
        return expression_yaml_scalar_text(resolved)
    }
    if (node_style[resolved] == "flow") {
        return expression_yaml_flow_text(resolved)
    }
    prefix = yaml_spaces(indent)
    result = ""
    if (node_kind[resolved] == "sequence") {
        if (!sequence_count[resolved]) {
            return "[]"
        }
        for (i = 1; i <= sequence_count[resolved]; i++) {
            child = sequence_child[resolved, i]
            inline = expression_yaml_inline_text(child)
            if (result != "") result = result "\n"
            if (inline != "") {
                result = result prefix "- " inline
            } else {
                result = result prefix "-\n" expression_yaml_text(child, indent + step, step)
            }
        }
        return result
    }
    if (!mapping_count[resolved]) {
        return "{}"
    }
    for (i = 1; i <= mapping_count[resolved]; i++) {
        key = mapping_key[resolved, i]
        child = mapping_child[resolved, i]
        inline = expression_yaml_inline_text(child)
        if (result != "") result = result "\n"
        key = presentation_plain_safe(key) ? key : json_quote(key)
        if (inline != "") {
            result = result prefix key ": " inline
        } else {
            result = result prefix key ":\n" expression_yaml_text(child, indent + step, step)
        }
    }
    return result
}

function expression_to_string(node,    resolved) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] == "scalar") {
        return node_type[resolved] == "null" && node_value[resolved] == "" ? "null" : node_value[resolved]
    }
    return expression_yaml_text(node, 0)
}

function expression_interpolation_text(node,    resolved) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] != "scalar") {
        return expression_json_text(resolved)
    }
    if (node_type[resolved] == "null") {
        return "null"
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

function expression_regex_replace_all(value, pattern, replacement,    result, prefix, previous_nonempty) {
    result = ""
    while (match(value, pattern)) {
        prefix = substr(value, 1, RSTART - 1)
        result = result prefix
        if (RLENGTH > 0) {
            result = result replacement
            value = substr(value, RSTART + RLENGTH)
            previous_nonempty = 1
        } else {
            if (!previous_nonempty || RSTART > 1) {
                result = result replacement
            }
            previous_nonempty = 0
            if (RSTART <= length(value)) {
                result = result substr(value, RSTART, 1)
                value = substr(value, RSTART + 1)
            } else {
                return result
            }
        }
    }
    return result value
}

function expression_entry(key, value, key_type,    entry) {
    entry = new_node("mapping", 0, "", "", "")
    add_mapping(entry, "key", expression_scalar(key, key_type), 0, 0)
    add_mapping(entry, "value", expression_clone_node(value), 0, 0)
    return entry
}

function expression_evaluate_context(kind, expression, input,    output, middle, i, node, resolved, key, result_node) {
    output = expression_stream_new()
    if (kind == "filename" || kind == "fileindex" || kind == "documentindex") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            if (kind == "filename") {
                key = (node in node_filename) ? node_filename[node] : input_filename
                expression_stream_push(output, expression_scalar(key, "string"))
            } else if (kind == "fileindex") {
                key = (node in node_file_index) ? node_file_index[node] : input_file_index + 0
                expression_stream_push(output, expression_scalar(key "", "int"))
            } else {
                expression_stream_push(output, expression_scalar((node_document[node] + 0) "", "int"))
            }
        }
        return output
    }
    if (kind == "path" || kind == "parent" || kind == "root") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = expression_stream_node[input, i]
            if (kind == "path") {
                expression_stream_push(output, expression_path(node))
            } else if (kind == "root") {
                expression_stream_push(output, expression_root(node))
            } else if (node in node_parent) {
                expression_stream_push(output, node_parent[node])
            }
        }
        return output
    }
    if (kind == "node_property") {
        middle = expression_evaluate(expression_left[expression], input)
        for (i = 1; i <= expression_stream_count[middle]; i++) {
            node = expression_stream_node[middle, i]
            expression_stream_push(output, expression_scalar(expression_node_property_value(node, expression_value[expression]), "string"))
        }
        return output
    }
    for (i = 1; i <= expression_stream_count[input]; i++) {
        node = expression_stream_node[input, i]
        resolved = resolve_alias(node)
        if (kind == "node_line") {
            expression_stream_push(output, expression_scalar(node_line[node] "", "int"))
        } else if (kind == "node_column") {
            expression_stream_push(output, expression_scalar(node_column[node] + 0 "", "int"))
        } else if (kind == "node_tag") {
            expression_stream_push(output, expression_scalar(expression_type_name(resolved), "string"))
        } else if (kind == "node_anchor") {
            expression_stream_push(output, expression_scalar(node_anchor[node], "string"))
        } else if (kind == "node_alias") {
            expression_stream_push(output, expression_scalar(node_kind[node] == "alias" ? node_value[node] : "", "string"))
        } else if (kind == "node_style") {
            key = node_style[node]
            expression_stream_push(output, expression_scalar(key == "plain" ? "" : key, "string"))
        } else if (kind == "node_line_comment") {
            expression_stream_push(output, expression_scalar(node_line_comment[node], "string"))
        } else if (kind == "node_head_comment") {
            expression_stream_push(output, expression_scalar(node_head_comment[node], "string"))
        } else if (kind == "node_foot_comment") {
            expression_stream_push(output, expression_scalar(node_foot_comment[node], "string"))
        } else if (node in node_parent) {
            key = node_parent_edge[node]
            result_node = substr(key, 1, 6) == "index " ? expression_scalar(substr(key, 7), "int") : expression_scalar(substr(key, 5), "string")
            node_origin[result_node] = node
            if (substr(key, 1, 4) == "key ") node_key_reference[result_node] = 1
            node_line[result_node] = substr(key, 1, 4) == "key " && (node in node_key_line) ? node_key_line[node] : node_line[node]
            node_column[result_node] = substr(key, 1, 4) == "key " ? ((node in node_key_column) ? node_key_column[node] : node_indent[node] + 1) : node_column[node]
            if (substr(key, 1, 4) == "key ") {
                if (node in node_key_head_comment) node_head_comment[result_node] = node_key_head_comment[node]
                if (node in node_key_foot_comment) node_foot_comment[result_node] = node_key_foot_comment[node]
                if (node in node_key_line_comment) node_line_comment[result_node] = node_key_line_comment[node]
            } else {
                if (node in node_head_comment) node_head_comment[result_node] = node_head_comment[node]
                if (node in node_foot_comment) node_foot_comment[result_node] = node_foot_comment[node]
                if (node in node_line_comment) node_line_comment[result_node] = node_line_comment[node]
            }
            expression_stream_push(output, result_node)
        }
    }
    return output
}

function expression_evaluate_string(kind, expression, input,    output, i, j, node, key, single, argument_stream, argument, right_stream, child, result_node) {
    output = expression_stream_new()
    if (kind == "upcase" || kind == "downcase" || kind == "trim" || kind == "to_string") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            if (kind == "to_string") {
                expression_stream_push(output, expression_scalar(expression_to_string(node), "string"))
                continue
            }
            if (node_kind[node] != "scalar" || node_type[node] != "string") fail(kind " requires a string")
            key = node_value[node]
            if (kind == "trim") {
                sub(/^[[:space:]]+/, "", key)
                sub(/[[:space:]]+$/, "", key)
            } else {
                key = kind == "upcase" ? toupper(key) : tolower(key)
            }
            expression_stream_push(output, expression_scalar(key, "string"))
        }
        return output
    }
    if (kind == "regex_test" || kind == "regex_sub") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            if (node_kind[node] != "scalar" || node_type[node] != "string") fail((kind == "regex_test" ? "test" : "sub") " requires a string")
            single = expression_stream_single(node)
            argument_stream = expression_evaluate(expression_left[expression], single)
            if (!expression_stream_count[argument_stream]) fail("regular expression requires a pattern")
            argument = expression_string_value(expression_stream_node[argument_stream, 1])
            key = node_value[node]
            if (kind == "regex_test") {
                expression_stream_push(output, expression_boolean(key ~ argument))
                continue
            }
            right_stream = expression_evaluate(expression_right[expression], single)
            if (!expression_stream_count[right_stream]) fail("regular expression replacement requires a string")
            child = expression_string_value(expression_stream_node[right_stream, 1])
            expression_stream_push(output, expression_scalar(expression_regex_replace_all(key, argument, child), "string"))
        }
        return output
    }
    for (i = 1; i <= expression_stream_count[input]; i++) {
        node = resolve_alias(expression_stream_node[input, i])
        single = expression_stream_single(node)
        argument_stream = expression_evaluate(expression_left[expression], single)
        if (!expression_stream_count[argument_stream]) fail(kind " requires an argument")
        argument = expression_string_value(expression_stream_node[argument_stream, 1])
        if (kind == "join") {
            if (node_kind[node] != "sequence") fail("join requires a sequence")
            key = ""
            for (j = 1; j <= sequence_count[node]; j++) key = key (j > 1 ? argument : "") expression_string_value(sequence_child[node, j])
            expression_stream_push(output, expression_scalar(key, "string"))
            continue
        }
        if (node_kind[node] != "scalar" || node_type[node] != "string") fail(kind " requires a string")
        key = node_value[node]
        if (kind == "contains") expression_stream_push(output, expression_boolean(index(key, argument) > 0))
        else if (kind == "startswith") expression_stream_push(output, expression_boolean(substr(key, 1, length(argument)) == argument))
        else if (kind == "endswith") expression_stream_push(output, expression_boolean(substr(key, length(key) - length(argument) + 1) == argument))
        else {
            result_node = new_node("sequence", 0, "", "", "")
            expression_split_string(key, argument, result_node)
            expression_stream_push(output, result_node)
        }
    }
    return output
}

function expression_utility_indent(expression, single, fallback, allow_zero,    stream, node, value) {
    if (!expression_left[expression]) return fallback
    stream = expression_evaluate(expression_left[expression], single)
    if (expression_stream_count[stream] != 1) fail(expression_kind[expression] " requires one indentation value")
    node = resolve_alias(expression_stream_node[stream, 1])
    if (node_kind[node] != "scalar" || node_type[node] != "int") fail(expression_kind[expression] " indentation must be an integer")
    value = node_value[node] + 0
    if (value < (allow_zero ? 0 : 1) || value > 9) fail(expression_kind[expression] " indentation must be " (allow_zero ? "0 through 9" : "1 through 9"))
    return value
}

function expression_shuffle(node,    resolved, result, serial, count, i, j, swap) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] != "sequence") fail("shuffle requires a sequence")
    result = new_node("sequence", 0, "", "", "")
    serial = ++codec_shuffle_serial
    count = sequence_count[resolved]
    for (i = 1; i <= count; i++) codec_shuffle_index[serial, i] = i
    for (i = count; i > 1; i--) {
        j = (codec_random_next() % i) + 1
        swap = codec_shuffle_index[serial, i]
        codec_shuffle_index[serial, i] = codec_shuffle_index[serial, j]
        codec_shuffle_index[serial, j] = swap
    }
    for (i = 1; i <= count; i++) {
        add_sequence(result, expression_clone_node(sequence_child[resolved, codec_shuffle_index[serial, i]]), 0)
        delete codec_shuffle_index[serial, i]
    }
    return result
}

function expression_evaluate_patch(kind, expression, input,    output, i, node, single, argument_stream, argument, value, result) {
    output = expression_stream_new()
    for (i = 1; i <= expression_stream_count[input]; i++) {
        node = expression_stream_node[input, i]
        single = expression_stream_single(node)
        argument_stream = expression_evaluate(expression_left[expression], single)
        if (expression_stream_count[argument_stream] != 1) fail(kind " requires exactly one argument value")
        argument = expression_stream_node[argument_stream, 1]
        if (kind == "pointer") {
            value = expression_string_value(argument)
            result = patch_pointer_find(node, value, 0)
            if (!result) fail("JSON Pointer path does not exist: " value)
            expression_stream_push(output, result)
        } else if (kind == "apply_patch") {
            patch_apply(node, argument)
            expression_stream_push(output, node)
        } else if (kind == "merge_patch") {
            merge_patch_apply(node, argument)
            expression_stream_push(output, node)
        } else {
            result = new_node("sequence", 0, "", "", "")
            patch_diff_into(node, argument, "", result)
            expression_stream_push(output, result)
        }
    }
    return output
}

function expression_evaluate_schema(kind, expression, input,    output, i, node, single, argument_stream, schema, errors, first, path, message) {
    output = expression_stream_new()
    for (i = 1; i <= expression_stream_count[input]; i++) {
        node = expression_stream_node[input, i]
        single = expression_stream_single(node)
        argument_stream = expression_evaluate(expression_left[expression], single)
        if (expression_stream_count[argument_stream] != 1) fail(kind " requires exactly one schema")
        schema = expression_stream_node[argument_stream, 1]
        errors = schema_errors(node, schema)
        if (kind == "schema_errors") {
            expression_stream_push(output, errors)
        } else if (kind == "schema_valid") {
            expression_stream_push(output, expression_boolean(sequence_count[errors] == 0))
        } else if (!sequence_count[errors]) {
            expression_stream_push(output, node)
        } else {
            first = sequence_child[errors, 1]
            path = node_value[resolve_alias(mapping_lookup(first, "instancePath"))]
            message = node_value[resolve_alias(mapping_lookup(first, "message"))]
            fail("schema validation failed at " (path == "" ? "/" : path) ": " message)
        }
    }
    return output
}

function expression_evaluate_utility(kind, expression, input,    output, i, j, node, resolved, single, argument_stream, argument_node, value, result_node, dynamic_expression, dynamic_results, step) {
    output = expression_stream_new()
    if (kind == "eval") {
        if (++dynamic_eval_depth > 32) fail("dynamic eval depth limit exceeded")
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = expression_stream_node[input, i]
            single = expression_stream_single(node)
            argument_stream = expression_evaluate(expression_left[expression], single)
            for (j = 1; j <= expression_stream_count[argument_stream]; j++) {
                value = expression_string_value(expression_stream_node[argument_stream, j])
                if (value in dynamic_expression_cache) dynamic_expression = dynamic_expression_cache[value]
                else {
                    dynamic_expression = expression_parse_fragment(value)
                    dynamic_expression_cache[value] = dynamic_expression
                }
                dynamic_results = expression_evaluate(dynamic_expression, single)
                expression_stream_append(output, dynamic_results)
            }
        }
        dynamic_eval_depth--
        return output
    }
    if (kind == "load" || kind == "load_str" || kind == "load_base64" || kind == "load_props") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            single = expression_stream_single(expression_stream_node[input, i])
            argument_stream = expression_evaluate(expression_left[expression], single)
            for (j = 1; j <= expression_stream_count[argument_stream]; j++) {
                value = expression_read_file(expression_string_value(expression_stream_node[argument_stream, j]))
                if (kind == "load") result_node = expression_parse_yaml_text(value)
                else if (kind == "load_base64") result_node = expression_scalar(codec_base64_decode(value), "string")
                else if (kind == "load_props") result_node = codec_props_decode(value)
                else result_node = expression_scalar(value, "string")
                expression_stream_push(output, result_node)
            }
        }
        return output
    }
    for (i = 1; i <= expression_stream_count[input]; i++) {
        node = expression_stream_node[input, i]
        resolved = resolve_alias(node)
        single = expression_stream_single(node)
        if (kind == "to_json") {
            step = expression_value[expression] == "compact" ? 0 : expression_utility_indent(expression, single, 2, 1)
            value = expression_json_pretty_text(node, step, 0)
            if (step > 0) value = value "\n"
            result_node = expression_scalar(value, "string")
        } else if (kind == "to_yaml") {
            step = expression_utility_indent(expression, single, 2, 0)
            result_node = expression_scalar(expression_yaml_text(node, 0, step) "\n", "string")
        } else if (kind == "from_json" || kind == "from_yaml") {
            value = expression_string_value(node)
            result_node = kind == "from_json" ? expression_parse_json_text(value) : expression_parse_yaml_text(value)
        } else if (kind == "to_props") {
            result_node = expression_scalar(codec_props_walk(node, ""), "string")
        } else if (kind == "from_props") {
            result_node = codec_props_decode(expression_string_value(node))
        } else if (kind == "to_csv" || kind == "to_tsv") {
            result_node = expression_scalar(codec_delimited_encode(node, kind == "to_csv" ? "," : "\t"), "string")
        } else if (kind == "from_csv" || kind == "from_tsv") {
            result_node = codec_delimited_decode(expression_string_value(node), kind == "from_csv" ? "," : "\t")
        } else if (kind == "to_toml") {
            result_node = expression_scalar(codec_toml_encode(node), "string")
        } else if (kind == "from_toml") {
            result_node = codec_toml_decode(expression_string_value(node))
        } else if (kind == "to_ini") {
            result_node = expression_scalar(codec_ini_encode(node), "string")
        } else if (kind == "from_ini") {
            result_node = codec_ini_decode(expression_string_value(node))
        } else if (kind == "to_xml") {
            result_node = expression_scalar(codec_xml_encode(node), "string")
        } else if (kind == "from_xml") {
            result_node = codec_xml_decode(expression_string_value(node))
        } else if (kind == "codec_base64" || kind == "codec_base64d" || kind == "codec_uri" || kind == "codec_urid" || kind == "codec_sh") {
            if (node_kind[resolved] != "scalar" || node_type[resolved] != "string") fail(substr(kind, 7) " codec requires a string")
            value = node_value[resolved]
            if (kind == "codec_base64") value = codec_base64_encode(value)
            else if (kind == "codec_base64d") value = codec_base64_decode(value)
            else if (kind == "codec_uri") value = codec_uri_encode(value)
            else if (kind == "codec_urid") value = codec_uri_decode(value)
            else value = codec_shell_encode(value)
            result_node = expression_scalar(value, "string")
        } else if (kind == "shuffle") {
            result_node = expression_shuffle(node)
        }
        expression_stream_push(output, result_node)
    }
    return output
}

function expression_evaluate(expression, input,    output, middle, left_stream, right_stream, single, kind, node, resolved, child, i, j, collection, key, predicate, matched, argument_stream, argument, result_node, variable, previous, had, accumulator, update_stream, start_index, end_index, size, interpolation, partial_count, next_count, partial, stage, mutation_path, mutation_kind, was_missing, input_target, path_stream, value_stream, path_node, path_serial, target_count, property_expression, property) {
    output = expression_stream_new()
    kind = expression_kind[expression]

    if (kind == "pointer" || kind == "apply_patch" || kind == "merge_patch" || kind == "diff_patch") {
        return expression_evaluate_patch(kind, expression, input)
    }
    if (kind == "validate" || kind == "schema_valid" || kind == "schema_errors") {
        return expression_evaluate_schema(kind, expression, input)
    }

    if (kind == "eval" || kind == "load" || kind == "load_str" || kind == "load_base64" || kind == "load_props" ||
        kind == "to_json" || kind == "from_json" || kind == "to_yaml" || kind == "from_yaml" ||
        kind == "to_props" || kind == "from_props" || kind == "to_csv" || kind == "from_csv" ||
        kind == "to_tsv" || kind == "from_tsv" || kind == "to_toml" || kind == "from_toml" ||
        kind == "to_ini" || kind == "from_ini" || kind == "to_xml" || kind == "from_xml" ||
        kind == "codec_base64" || kind == "codec_base64d" || kind == "codec_uri" || kind == "codec_urid" ||
        kind == "codec_sh" || kind == "shuffle") {
        return expression_evaluate_utility(kind, expression, input)
    }

    if (kind == "identity") {
        expression_stream_append(output, input)
        return output
    }
    if (kind == "split_doc") {
        # YAML.sh already separates every YAML stream result into a valid document.
        # Keep split_doc explicit and idempotent instead of weakening that contract.
        expression_stream_append(output, input)
        return output
    }
    if (kind == "empty") {
        return output
    }
    if (kind == "error") {
        key = "aborted"
        argument_stream = expression_evaluate(expression_left[expression], input)
        if (expression_stream_count[argument_stream]) {
            node = resolve_alias(expression_stream_node[argument_stream, 1])
            key = node_kind[node] == "scalar" ? node_value[node] : ""
        }
        fail(key)
    }
    if (kind == "env" || kind == "strenv") {
        if (disable_env_ops) {
            fail("environment operations are disabled")
        }
        key = expression_value[expression]
        if (kind == "env" && !(key in ENVIRON)) {
            fail("value for env variable '" key "' not provided in env()")
        }
        for (i = 1; i <= expression_stream_count[input]; i++) {
            if (kind == "strenv") {
                expression_stream_push(output, expression_scalar(ENVIRON[key], "string"))
            } else {
                expression_stream_push(output, parse_value(ENVIRON[key], 0, -1, 0))
            }
        }
        return output
    }
    if (kind == "filename" || kind == "fileindex" || kind == "documentindex" || kind == "path" || kind == "parent" || kind == "root" ||
        kind == "node_property" || kind == "node_line" || kind == "node_column" || kind == "node_key" || kind == "node_tag" ||
        kind == "node_anchor" || kind == "node_alias" || kind == "node_style" || kind == "node_line_comment" ||
        kind == "node_head_comment" || kind == "node_foot_comment") {
        return expression_evaluate_context(kind, expression, input)
    }
    if (kind == "to_number" || kind == "envsubst") {
        if (kind == "envsubst" && disable_env_ops) {
            fail("environment operations are disabled")
        }
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            if (node_kind[node] != "scalar" || node_type[node] != "string") {
                fail(kind " requires a string")
            }
            if (kind == "envsubst") {
                expression_stream_push(output, expression_scalar(expression_envsubst(node_value[node], expression_value[expression]), "string"))
            } else {
                key = scalar_type(node_value[node], "", node_value[node])
                if (key != "int" && key != "float") {
                    fail("cannot convert value to number: " node_value[node])
                }
                expression_stream_push(output, expression_scalar(node_value[node], key))
            }
        }
        return output
    }
    if (kind == "literal") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            expression_stream_push(output, expression_scalar(expression_value[expression], expression_literal_type[expression]))
        }
        return output
    }
    if (kind == "interpolate") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            single = expression_stream_single(expression_stream_node[input, i])
            interpolation = ++expression_interpolation_serial
            partial_count = 1
            expression_interpolation_partial[interpolation, 1] = expression_interpolation_literal[expression, 1]
            for (j = 1; j <= expression_child_count[expression]; j++) {
                argument_stream = expression_evaluate(expression_child[expression, j], single)
                next_count = 0
                if (expression_stream_count[argument_stream]) {
                    for (collection = 1; collection <= partial_count; collection++) {
                        partial = expression_interpolation_partial[interpolation, collection]
                        expression_interpolation_next[interpolation, ++next_count] = partial expression_interpolation_text(expression_stream_node[argument_stream, 1]) expression_interpolation_literal[expression, j + 1]
                    }
                }
                partial_count = next_count
                for (collection = 1; collection <= partial_count; collection++) {
                    expression_interpolation_partial[interpolation, collection] = expression_interpolation_next[interpolation, collection]
                    delete expression_interpolation_next[interpolation, collection]
                }
            }
            for (collection = 1; collection <= partial_count; collection++) {
                expression_stream_push(output, expression_scalar(expression_interpolation_partial[interpolation, collection], "string"))
                delete expression_interpolation_partial[interpolation, collection]
            }
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
        if (eval_all_mode && expression == eval_all_top_expression && kind == "array") {
            result_node = new_node("sequence", 0, "", "", "")
            for (i = 1; i <= expression_stream_count[input]; i++) {
                single = expression_stream_single(expression_stream_node[input, i])
                for (j = 1; j <= expression_child_count[expression]; j++) {
                    middle = expression_evaluate(expression_child[expression, j], single)
                    for (collection = 1; collection <= expression_stream_count[middle]; collection++) {
                        add_sequence(result_node, expression_clone_node(expression_stream_node[middle, collection]), 0)
                    }
                }
            }
            expression_stream_push(output, result_node)
            return output
        }
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
                    key = expression_object_key[expression, j]
                    if (expression_object_key_expression[expression, j]) {
                        argument_stream = expression_evaluate(expression_object_key_expression[expression, j], single)
                        if (!expression_stream_count[argument_stream]) {
                            fail("computed object key produced no value")
                        }
                        argument = resolve_alias(expression_stream_node[argument_stream, 1])
                        if (node_kind[argument] != "scalar") {
                            fail("computed object keys must be scalars")
                        }
                        key = expression_interpolation_text(argument)
                    }
                    add_mapping(result_node, key, expression_clone_node(child), 0, 0)
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
        if (eval_all_mode && expression == eval_all_top_expression) {
            left_stream = expression_evaluate(expression_left[expression], input)
            right_stream = expression_evaluate(expression_right[expression], input)
            for (j = 1; j <= expression_stream_count[left_stream]; j++) {
                for (collection = 1; collection <= expression_stream_count[right_stream]; collection++) {
                    expression_stream_push(output, expression_arithmetic(expression_stream_node[left_stream, j], expression_stream_node[right_stream, collection], expression_value[expression]))
                }
            }
            return output
        }
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
        if (eval_all_mode && expression == eval_all_top_expression) {
            left_stream = expression_evaluate(expression_left[expression], input)
            for (j = 1; j <= expression_stream_count[left_stream]; j++) {
                expression_variable_node[variable] = expression_stream_node[left_stream, j]
                right_stream = expression_evaluate(expression_right[expression], input)
                expression_stream_append(output, right_stream)
            }
        } else {
            for (i = 1; i <= expression_stream_count[input]; i++) {
                single = expression_stream_single(expression_stream_node[input, i])
                left_stream = expression_evaluate(expression_left[expression], single)
                for (j = 1; j <= expression_stream_count[left_stream]; j++) {
                    expression_variable_node[variable] = expression_stream_node[left_stream, j]
                    right_stream = expression_evaluate(expression_right[expression], single)
                    expression_stream_append(output, right_stream)
                }
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
        if (eval_all_mode && expression == eval_all_top_expression) {
            left_stream = expression_evaluate(expression_left[expression], input)
            right_stream = expression_evaluate(expression_right[expression], input)
            accumulator = expression_stream_count[right_stream] ? expression_stream_node[right_stream, 1] : expression_null()
            for (j = 1; j <= expression_stream_count[left_stream]; j++) {
                expression_variable_node[variable] = expression_stream_node[left_stream, j]
                single = expression_stream_single(accumulator)
                update_stream = expression_evaluate(expression_child[expression, 1], single)
                accumulator = expression_stream_count[update_stream] ? expression_stream_node[update_stream, 1] : expression_null()
            }
            expression_stream_push(output, accumulator)
            if (had) {
                expression_variable_node[variable] = previous
            } else {
                delete expression_variable_node[variable]
            }
            return output
        }
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
    if (kind == "with") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            single = expression_stream_single(expression_stream_node[input, i])
            left_stream = expression_evaluate(expression_left[expression], single)
            for (j = 1; j <= expression_stream_count[left_stream]; j++) {
                middle = expression_stream_single(expression_stream_node[left_stream, j])
                expression_evaluate(expression_right[expression], middle)
            }
            expression_stream_push(output, expression_stream_node[input, i])
        }
        return output
    }
    if (kind == "explode") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            single = expression_stream_single(expression_stream_node[input, i])
            middle = expression_evaluate(expression_left[expression], single)
            for (j = 1; j <= expression_stream_count[middle]; j++) {
                expression_stream_push(output, expression_clone_node(expression_stream_node[middle, j]))
            }
        }
        return output
    }
    if (kind == "first" || kind == "filter") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            if (node_kind[node] != "sequence" && node_kind[node] != "mapping") {
                continue
            }
            if (kind == "filter") {
                result_node = new_node("sequence", 0, "", "", "")
            }
            collection = ++collection_serial
            if (node_kind[node] == "mapping") {
                collect_mapping_keys(node, collection)
                size = collection_count[collection]
            } else {
                size = sequence_count[node]
            }
            for (j = 1; j <= size; j++) {
                child = node_kind[node] == "mapping" ? mapping_lookup(node, collection_key[collection, j]) : sequence_child[node, j]
                matched = kind == "first" && expression_value[expression] == "" ? 1 : expression_predicate_matches(expression_left[expression], child)
                if (matched && kind == "first") {
                    expression_stream_push(output, child)
                    break
                }
                if (matched) {
                    add_sequence(result_node, expression_clone_node(child), 0)
                }
            }
            if (kind == "filter") {
                expression_stream_push(output, result_node)
            }
        }
        return output
    }
    if (kind == "pick" || kind == "omit") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            single = expression_stream_single(node)
            argument_stream = expression_evaluate(expression_left[expression], single)
            if (!expression_stream_count[argument_stream]) {
                fail(kind " requires a sequence of keys or indexes")
            }
            argument = resolve_alias(expression_stream_node[argument_stream, 1])
            if (node_kind[argument] != "sequence") {
                fail(kind " requires a sequence of keys or indexes")
            }
            expression_stream_push(output, expression_pick_or_omit(node, argument, kind == "omit"))
        }
        return output
    }
    if (kind == "pivot") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            expression_stream_push(output, expression_pivot(resolve_alias(expression_stream_node[input, i])))
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
    if (kind == "slice") {
        middle = expression_evaluate(expression_left[expression], input)
        for (i = 1; i <= expression_stream_count[middle]; i++) {
            node = expression_stream_node[middle, i]
            resolved = resolve_alias(node)
            if (node_kind[resolved] == "sequence") {
                size = sequence_count[resolved]
            } else if (node_kind[resolved] == "scalar" && node_type[resolved] == "string") {
                size = length(node_value[resolved])
            } else if (expression_optional[expression]) {
                continue
            } else {
                fail("slices require a sequence or string")
            }
            start_index = 0
            end_index = size
            single = expression_stream_single(resolved)
            if (expression_slice_has_start[expression]) {
                argument_stream = expression_evaluate(expression_child[expression, 1], single)
                if (!expression_stream_count[argument_stream]) {
                    fail("slice start requires an integer")
                }
                argument = resolve_alias(expression_stream_node[argument_stream, 1])
                if (node_type[argument] != "int") {
                    fail("slice start requires an integer")
                }
                start_index = node_value[argument] + 0
            }
            if (expression_slice_has_end[expression]) {
                argument_stream = expression_evaluate(expression_child[expression, 2], single)
                if (!expression_stream_count[argument_stream]) {
                    fail("slice end requires an integer")
                }
                argument = resolve_alias(expression_stream_node[argument_stream, 1])
                if (node_type[argument] != "int") {
                    fail("slice end requires an integer")
                }
                end_index = node_value[argument] + 0
            }
            if (start_index < 0) {
                start_index = size + start_index
            }
            if (end_index < 0) {
                end_index = size + end_index
            }
            if (start_index < 0) {
                start_index = 0
            } else if (start_index > size) {
                start_index = size
            }
            if (end_index < 0) {
                end_index = 0
            } else if (end_index > size) {
                end_index = size
            }
            if (end_index < start_index) {
                end_index = start_index
            }
            if (node_kind[resolved] == "sequence") {
                result_node = new_node("sequence", 0, "", "", "")
                for (j = start_index + 1; j <= end_index; j++) {
                    add_sequence(result_node, expression_clone_node(sequence_child[resolved, j]), 0)
                }
                expression_stream_push(output, result_node)
            } else {
                expression_stream_push(output, expression_scalar(substr(node_value[resolved], start_index + 1, end_index - start_index), "string"))
            }
        }
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
                } else if (node_kind[resolved] == "mapping" || !expression_optional[expression]) {
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
                } else if (node_kind[resolved] == "sequence" || !expression_optional[expression]) {
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
                    } else {
                        expression_stream_push(output, expression_null())
                    }
                } else if (node_kind[resolved] == "mapping") {
                    key = node_value[argument]
                    child = mapping_lookup(resolved, key)
                    if (child) {
                        expression_stream_push(output, child)
                    } else {
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
    if ((kind == "assign" || kind == "update") && expression_kind[expression_left[expression]] == "node_property") {
        property_expression = expression_left[expression]
        property = expression_value[property_expression]
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = expression_stream_node[input, i]
            single = expression_stream_single(node)
            left_stream = expression_evaluate(expression_left[property_expression], single)
            if (kind == "assign") {
                right_stream = expression_evaluate(expression_right[expression], single)
                if (!expression_stream_count[right_stream]) {
                    expression_stream_push(right_stream, expression_null())
                }
            }
            for (j = 1; j <= expression_stream_count[left_stream]; j++) {
                child = expression_stream_node[left_stream, j]
                if (kind == "update") {
                    middle = expression_stream_single(expression_scalar(expression_node_property_value(child, property), "string"))
                    right_stream = expression_evaluate(expression_right[expression], middle)
                    if (!expression_stream_count[right_stream]) {
                        expression_stream_push(right_stream, expression_scalar("", "string"))
                    }
                    argument = expression_stream_node[right_stream, 1]
                } else {
                    collection = expression_stream_count[right_stream] == expression_stream_count[left_stream] ? j : 1
                    argument = expression_stream_node[right_stream, collection]
                }
                if (explain_mode) {
                    input_target = explain_input_target(child)
                    mutation_path = explain_path(child) " " property
                }
                expression_set_node_property(child, property, argument)
                if (expression_last_property_changed) {
                    expression_mark_changed(child)
                }
                if (explain_mode && input_target && expression_last_property_changed) {
                    explain_record_mutation("replace", mutation_path, child)
                }
            }
            expression_stream_push(output, node)
        }
        return output
    }
    if (kind == "setpath") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = expression_stream_node[input, i]
            single = expression_stream_single(node)
            path_stream = expression_evaluate(expression_left[expression], single)
            value_stream = expression_evaluate(expression_right[expression], single)
            if (!expression_stream_count[path_stream]) {
                fail("setpath path produced no value")
            }
            child = expression_stream_count[value_stream] ? expression_stream_node[value_stream, 1] : expression_null()
            result_node = expression_follow_path(node, expression_stream_node[path_stream, 1], 1)
            was_missing = expression_path_was_missing
            if (explain_mode) {
                input_target = explain_input_target(result_node)
                mutation_path = explain_path(result_node)
            }
            expression_replace_node(result_node, child)
            if (expression_last_replace_changed) {
                expression_mark_changed(result_node)
            }
            if (explain_mode && input_target && expression_last_replace_changed) {
                explain_record_mutation(was_missing ? "insert" : "replace", mutation_path, result_node)
            }
            expression_stream_push(output, node)
        }
        return output
    }
    if (kind == "delpaths") {
        path_serial = ++expression_path_serial
        for (i = 1; i <= expression_stream_count[input]; i++) {
            target_count = 0
            node = expression_stream_node[input, i]
            single = expression_stream_single(node)
            path_stream = expression_evaluate(expression_left[expression], single)
            if (!expression_stream_count[path_stream]) {
                expression_stream_push(output, node)
                continue
            }
            path_node = resolve_alias(expression_stream_node[path_stream, 1])
            if (node_kind[path_node] != "sequence") {
                fail("delpaths requires an array of paths")
            }
            for (j = 1; j <= sequence_count[path_node]; j++) {
                child = expression_follow_path(node, sequence_child[path_node, j], 0)
                if (child) {
                    expression_path_target[path_serial, ++target_count] = child
                }
            }
            for (j = target_count; j >= 1; j--) {
                child = expression_path_target[path_serial, j]
                if (explain_mode) {
                    input_target = explain_input_target(child)
                    mutation_path = explain_path(child)
                }
                expression_delete_node(child)
                if (expression_last_delete_changed) {
                    expression_mark_changed(child)
                }
                if (explain_mode && input_target && expression_last_delete_changed) {
                    explain_record_mutation("delete", mutation_path, child)
                }
                delete expression_path_target[path_serial, j]
            }
            expression_stream_push(output, node)
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
                node = expression_stream_node[left_stream, i]
                if (explain_mode) {
                    input_target = explain_input_target(node)
                    mutation_path = explain_path(node)
                    was_missing = (node in expression_missing_parent) && !expression_placeholder_attached[node]
                }
                expression_replace_node(node, expression_stream_node[right_stream, j])
                if (expression_last_replace_changed) {
                    expression_mark_changed(node)
                }
                if (explain_mode && input_target && expression_last_replace_changed) {
                    explain_record_mutation(was_missing ? "insert" : "replace", mutation_path, node)
                }
            }
        } else {
            for (i = 1; i <= expression_stream_count[left_stream]; i++) {
                node = expression_stream_node[left_stream, i]
                single = expression_stream_single(node)
                right_stream = expression_evaluate(expression_right[expression], single)
                child = expression_stream_count[right_stream] ? expression_stream_node[right_stream, 1] : expression_null()
                if (explain_mode) {
                    input_target = explain_input_target(node)
                    mutation_path = explain_path(node)
                    was_missing = (node in expression_missing_parent) && !expression_placeholder_attached[node]
                }
                expression_replace_node(node, child)
                if (expression_last_replace_changed) {
                    expression_mark_changed(node)
                }
                if (explain_mode && input_target && expression_last_replace_changed) {
                    explain_record_mutation(was_missing ? "insert" : "replace", mutation_path, node)
                }
            }
        }
        expression_stream_append(output, input)
        return output
    }
    if (kind == "del") {
        middle = expression_evaluate(expression_left[expression], input)
        for (i = expression_stream_count[middle]; i >= 1; i--) {
            node = expression_stream_node[middle, i]
            if (explain_mode) {
                input_target = explain_input_target(node)
                mutation_path = explain_path(node)
            }
            expression_delete_node(node)
            if (expression_last_delete_changed) {
                expression_mark_changed(node)
            }
            if (explain_mode && input_target && expression_last_delete_changed) {
                explain_record_mutation("delete", mutation_path, node)
            }
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
    if (kind == "compare") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            single = expression_stream_single(expression_stream_node[input, i])
            left_stream = expression_evaluate(expression_left[expression], single)
            right_stream = expression_evaluate(expression_right[expression], single)
            for (j = 1; j <= expression_stream_count[left_stream]; j++) {
                for (collection = 1; collection <= expression_stream_count[right_stream]; collection++) {
                    node = expression_stream_node[left_stream, j]
                    child = expression_stream_node[right_stream, collection]
                    matched = expression_compare(node, child, expression_value[expression])
                    expression_stream_push(output, expression_boolean(matched))
                }
            }
        }
        return output
    }
    if (kind == "and" || kind == "or") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            single = expression_stream_single(expression_stream_node[input, i])
            left_stream = expression_evaluate(expression_left[expression], single)
            if (!expression_stream_count[left_stream]) {
                if (kind == "and") {
                    expression_stream_push(output, expression_boolean(0))
                } else {
                    right_stream = expression_evaluate(expression_right[expression], single)
                    for (collection = 1; collection <= expression_stream_count[right_stream]; collection++) {
                        expression_stream_push(output, expression_boolean(expression_truthy(expression_stream_node[right_stream, collection])))
                    }
                }
                continue
            }
            for (j = 1; j <= expression_stream_count[left_stream]; j++) {
                node = expression_stream_node[left_stream, j]
                matched = expression_truthy(node)
                if ((kind == "or" && matched) || (kind == "and" && !matched)) {
                    expression_stream_push(output, expression_boolean(matched))
                    continue
                }
                right_stream = expression_evaluate(expression_right[expression], single)
                for (collection = 1; collection <= expression_stream_count[right_stream]; collection++) {
                    child = expression_stream_node[right_stream, collection]
                    expression_stream_push(output, expression_boolean(expression_truthy(child)))
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
    if (kind == "array_to_map") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            if (node_kind[node] != "sequence") {
                fail("array_to_map requires a sequence")
            }
            result_node = new_node("mapping", 0, "", "", "")
            for (j = 1; j <= sequence_count[node]; j++) {
                add_mapping(result_node, (j - 1) "", expression_clone_node(sequence_child[node, j]), 0, 0)
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
    if (kind == "sort_keys") {
        middle = expression_evaluate(expression_left[expression], input)
        matched = expression_kind[expression_left[expression]] == "recursive"
        if (matched) {
            if (expression_stream_count[middle]) {
                if (inplace_mode) {
                    presentation_possible = 0
                }
                expression_stream_push(output, expression_sort_keys_clone(expression_stream_node[middle, 1], 1))
            }
            return output
        }
        for (i = 1; i <= expression_stream_count[middle]; i++) {
            expression_stream_push(output, expression_sort_keys_clone(expression_stream_node[middle, i], 0))
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
    if (kind == "upcase" || kind == "downcase" || kind == "trim" || kind == "to_string" ||
        kind == "regex_test" || kind == "regex_sub" || kind == "contains" || kind == "startswith" ||
        kind == "endswith" || kind == "split" || kind == "join") {
        return expression_evaluate_string(kind, expression, input)
    }
    if (kind == "length" || kind == "keys" || kind == "kind" || kind == "type" || kind == "has") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = expression_stream_node[input, i]
            resolved = resolve_alias(node)
            if (kind == "length") {
                if (node_kind[resolved] == "mapping") {
                    matched = expression_mapping_length(resolved)
                } else if (node_kind[resolved] == "sequence") {
                    matched = sequence_count[resolved] + 0
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
                    collection = node_value[argument] + 0
                    if (collection < 0) {
                        collection = sequence_count[resolved] + collection
                    }
                    matched = collection >= 0 && collection < sequence_count[resolved]
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
        } else if (substr(tag, 1, 1) == "!") {
            tag = tag
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
        quote = sprintf("%c", 39)
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

function emit_yaml_comment(value, indent,    count, i) {
    if (value == "") return
    count = split(value, yaml_comment_line, /\n/)
    for (i = 1; i <= count; i++) {
        print yaml_spaces(indent) "#" (yaml_comment_line[i] == "" ? "" : " " yaml_comment_line[i])
        delete yaml_comment_line[i]
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
    if (property == "foot_comment" || (as_key && property == "foot_comment")) {
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

function presentation_track_sequence_reorder(target, source,    parent, header, raw, text, target_end, serial, i, j, child, origin, found, lower, start, previous_end) {
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

function presentation_track_mapping_reorder(target, source,    parent, header, raw, text, target_end, serial, i, j, child, origin, found, lower, start, previous_end, key) {
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
    lower = header + 1
    previous_end = header
    for (i = 1; i <= mapping_count[target]; i++) {
        child = mapping_child[target, i]
        if (node_line[child] <= header) {
            return 0
        }
        lower = previous_end + 1
        start = presentation_attached_start(child, lower)
        presentation_original_start[serial, child] = start
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

function transform_all_documents(query, file_filter,    document, root, expression, input, results) {
    if (!compiled_expression) {
        compiled_expression = expression_parse(query)
    }
    expression = compiled_expression
    for (document = 0; document <= document_index; document++) {
        if (!(document in document_root) || (file_filter != "" && document_file_index[document] != file_filter)) {
            continue
        }
        root = document_root[document]
        input = expression_stream_single(root)
        results = configuration_apply_contracts(expression_evaluate(expression, input))
        explain_result_count += expression_stream_count[results]
    }
}

function transform_eval_all_documents(query,    document, expression, input, results, i, file) {
    if (!compiled_expression) {
        compiled_expression = expression_parse(query)
    }
    expression = compiled_expression
    eval_all_top_expression = expression
    input = expression_stream_new()
    for (document = 0; document <= document_index; document++) {
        if (document in document_root) {
            expression_stream_push(input, document_root[document])
        }
    }
    results = configuration_apply_contracts(expression_evaluate(expression, input))
    explain_result_count += expression_stream_count[results]
    for (i = 1; i <= expression_stream_count[results]; i++) {
        file = expression_input_file(expression_stream_node[results, i])
        explain_file_result_count[file]++
    }
}

function emit_all_yaml_documents(file_filter,    document, emitted) {
    emitted = 0
    for (document = 0; document <= document_index; document++) {
        if (!(document in document_root) || (file_filter != "" && document_file_index[document] != file_filter)) {
            continue
        }
        if (emitted++) {
            print "---"
        }
        emit_yaml(document_root[document])
    }
}

function clear_explain_state(    i) {
    for (i = 1; i <= explain_mutation_count; i++) {
        delete explain_mutation_kind[i]
        delete explain_mutation_path[i]
        delete explain_mutation_file[i]
    }
    explain_result_count = 0
    explain_mutation_count = 0
    explain_replacement_count = 0
    explain_insertion_count = 0
    explain_deletion_count = 0
    final_result_count = 0
    final_result_truthy = 0
}

function output_transaction_files(query,    file, last_file, start_nodes, marker, transaction_start_nodes) {
    last_file = declared_input_file_count ? declared_last_input_file_index : current_input_file_index
    marker = sprintf("%c", 30) "YSHFILE "
    if (eval_all_mode) {
        presentation_possible = 1
        clear_explain_state()
        transaction_start_nodes = node_count
        transform_eval_all_documents(query)
    }
    for (file = input_file_index + 0; file <= last_file; file++) {
        current_input_file_index = file
        current_input_filename = input_file_name[file]
        if (!eval_all_mode) {
            presentation_possible = 1
            clear_explain_state()
            start_nodes = node_count
            transform_all_documents(query, file)
        } else {
            start_nodes = transaction_start_nodes
        }
        if (preserve_only_mode && expression_file_changed[file] && !presentation_possible) {
            fail("preserve-only edit would regenerate YAML presentation: " input_file_name[file])
        }
        source_edit_compile(input_file_start_line[file], input_file_end_line[file], file)
        if (preserve_only_mode && expression_file_changed[file] && !presentation_possible) {
            fail("preserve-only edit would produce overlapping source edits: " input_file_name[file])
        }
        print marker file " " (expression_file_changed[file] ? 1 : 0)
        if (presentation_possible && input_file_has_lines[file]) {
            emit_preserved_input(input_file_start_line[file], input_file_end_line[file])
        } else if (!presentation_possible) {
            emit_all_yaml_documents(file)
        }
        if (explain_mode) {
            explain_file_mode = 1
            explain_file_index = file
            explain_file_generated_nodes = node_count - start_nodes
            output_explain()
            explain_file_mode = 0
        }
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

function configuration_file_node(path,    value, lower) {
    # Contract paths are explicit CLI inputs, like the primary document. The
    # file-ops policy only prevents expressions from selecting paths at runtime.
    value = local_file_read(path)
    lower = tolower(path)
    if (lower ~ /\.json$/) return expression_parse_json_text(value)
    if (lower ~ /\.toml$/) return codec_toml_decode(value)
    if (lower ~ /\.ini$/) return codec_ini_decode(value)
    if (lower ~ /\.xml$/) return codec_xml_decode(value)
    return expression_parse_yaml_text(value)
}

function configuration_apply_contracts(results,    output, i, node, errors, first, path, message) {
    if (schema_file != "" && !configuration_schema_node) configuration_schema_node = configuration_file_node(schema_file)
    if (patch_file != "" && !configuration_patch_node) configuration_patch_node = configuration_file_node(patch_file)
    if (merge_patch_file != "" && !configuration_merge_patch_node) configuration_merge_patch_node = configuration_file_node(merge_patch_file)
    if (patch_target_file != "" && !configuration_patch_target_node) configuration_patch_target_node = configuration_file_node(patch_target_file)
    output = expression_stream_new()
    for (i = 1; i <= expression_stream_count[results]; i++) {
        node = expression_stream_node[results, i]
        if (patch_file != "") patch_apply(node, configuration_patch_node)
        if (merge_patch_file != "") merge_patch_apply(node, configuration_merge_patch_node)
        if (schema_file != "") {
            errors = schema_errors(node, configuration_schema_node)
            if (sequence_count[errors]) {
                first = sequence_child[errors, 1]
                path = node_value[resolve_alias(mapping_lookup(first, "instancePath"))]
                message = node_value[resolve_alias(mapping_lookup(first, "message"))]
                fail("schema validation failed at " (path == "" ? "/" : path) ": " message)
            }
        }
        if (patch_target_file != "") {
            first = new_node("sequence", 0, "", "")
            patch_diff_into(node, configuration_patch_target_node, "", first)
            expression_stream_push(output, first)
        } else expression_stream_push(output, node)
    }
    return output
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
    } else if (output_mode == "toml") {
        printf "%s", codec_toml_encode(target)
    } else if (output_mode == "ini") {
        printf "%s", codec_ini_encode(target)
    } else if (output_mode == "xml") {
        printf "%s", codec_xml_encode(target)
    } else if (output_mode == "toml-test-json") {
        print codec_toml_test_json(target)
    } else if (output_mode == "toml-test-encode") {
        printf "%s", codec_toml_encode(codec_toml_test_decode(target))
    } else if (node_kind[resolved] == "scalar") {
        if (unwrap_scalar_mode) {
            print node_value[resolved]
        } else {
            emit_yaml(target)
        }
    } else {
        emit_json(target)
        printf "\n"
    }
}

function output_expression_results(results, output_mode,    i) {
    final_result_count = expression_stream_count[results]
    explain_result_count += final_result_count
    if (final_result_count) {
        final_result_truthy = expression_truthy(expression_stream_node[results, final_result_count])
    }
    for (i = 1; i <= expression_stream_count[results]; i++) {
        if (output_mode == "yaml" && emitted_output_count > 0) {
            print "---"
        }
        output_expression_node(expression_stream_node[results, i], output_mode)
        emitted_output_count++
    }
}

function output_explain(    documents, document, generated, presentation, shown, i, source, results, mutations, replacements, insertions, deletions, emitted_changes, parsed, source_edits) {
    documents = 0
    for (document = 0; document <= document_index; document++) {
        if ((document in document_root) && (!explain_file_mode || document_file_index[document] == explain_file_index)) {
            documents++
        }
    }
    parsed = parsed_node_count
    generated = explain_file_mode ? explain_file_generated_nodes : node_count - parsed_node_count
    results = explain_result_count + 0
    mutations = explain_mutation_count + 0
    replacements = explain_replacement_count + 0
    insertions = explain_insertion_count + 0
    deletions = explain_deletion_count + 0
    source_edits = inplace_mode ? source_edit_file_count[explain_file_mode ? explain_file_index : 0] + 0 : 0
    if (explain_file_mode && eval_all_mode) {
        parsed = 0
        results = explain_file_result_count[explain_file_index] + 0
        mutations = 0
        replacements = 0
        insertions = 0
        deletions = 0
        for (i = 1; i <= parsed_node_count; i++) {
            if (node_file_index[i] == explain_file_index) {
                parsed++
            }
        }
        for (i = 1; i <= explain_mutation_count; i++) {
            if (explain_mutation_file[i] != explain_file_index) {
                continue
            }
            mutations++
            if (explain_mutation_kind[i] == "insert") {
                insertions++
            } else if (explain_mutation_kind[i] == "delete") {
                deletions++
            } else {
                replacements++
            }
        }
    }
    source = explain_file_mode ? input_file_name[explain_file_index] : (combined_files_mode ? "multiple files" : input_filename)
    if (source == "") {
        source = "-"
    }
    if (!inplace_mode) {
        presentation = "not-requested"
    } else if (presentation_possible) {
        presentation = "preserved"
    } else {
        presentation = "regenerated"
    }
    if (explain_mode == 2) {
        printf "{\"input\":%s,\"documents\":%d,\"parsed_nodes\":%d,\"generated_nodes\":%d,", json_quote(source), documents, parsed, generated > "/dev/stderr"
        printf "\"results\":%d,\"mutations\":%d,\"replacements\":%d,\"insertions\":%d,\"deletions\":%d,", results, mutations, replacements, insertions, deletions > "/dev/stderr"
        printf "\"presentation\":%s,\"source_edits\":%d,\"changes\":[", json_quote(presentation), source_edits > "/dev/stderr"
        emitted_changes = 0
        for (i = 1; i <= explain_mutation_count; i++) {
            if (explain_file_mode && eval_all_mode && explain_mutation_file[i] != explain_file_index) {
                continue
            }
            if (emitted_changes++) {
                printf "," > "/dev/stderr"
            }
            printf "{\"kind\":%s,\"path\":%s}", json_quote(explain_mutation_kind[i]), json_quote(explain_mutation_path[i]) > "/dev/stderr"
        }
        print "]}" > "/dev/stderr"
        return
    }
    print "Explain: input=" json_quote(source) " documents=" documents " parsed_nodes=" parsed " generated_nodes=" generated > "/dev/stderr"
    print "Explain: results=" results " mutations=" mutations \
        " replacements=" replacements " insertions=" insertions \
        " deletions=" deletions " presentation=" presentation " source_edits=" source_edits > "/dev/stderr"
    shown = 0
    for (i = 1; i <= explain_mutation_count && shown < 20; i++) {
        if (explain_file_mode && eval_all_mode && explain_mutation_file[i] != explain_file_index) {
            continue
        }
        print "Explain: " explain_mutation_kind[i] " " explain_mutation_path[i] > "/dev/stderr"
        shown++
    }
    if (mutations > shown) {
        print "Explain: ... " (mutations - shown) " more mutations" > "/dev/stderr"
    }
}

function output_result(document, query, output_mode,    root, expression, input, results) {
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
    if (!compiled_expression) {
        compiled_expression = expression_parse(query)
    }
    expression = compiled_expression
    input = expression_stream_single(root)
    results = configuration_apply_contracts(expression_evaluate(expression, input))
    output_expression_results(results, output_mode)
}

function output_eval_all(query, output_mode,    expression, input, results, i) {
    expression = expression_parse(query)
    compiled_expression = expression
    eval_all_top_expression = expression
    input = expression_stream_new()
    for (i = 0; i <= document_index; i++) {
        if (i in document_root) {
            expression_stream_push(input, document_root[i])
        }
    }
    results = configuration_apply_contracts(expression_evaluate(expression, input))
    output_expression_results(results, output_mode)
}

function output_batch_files(query, output_mode,    file, last_file, document, found, file_truthy, file_has_document) {
    if (!compiled_expression && output_mode != "ast" && output_mode != "events") {
        compiled_expression = expression_parse(query)
    }
    last_file = declared_input_file_count ? declared_last_input_file_index : current_input_file_index
    for (file = input_file_index + 0; file <= last_file; file++) {
        found = 0
        file_has_document = 0
        file_truthy = 0
        current_input_file_index = file
        current_input_filename = input_file_name[file]
        for (document = 0; document <= document_index; document++) {
            if (!(document in document_root) || document_file_index[document] != file) {
                continue
            }
            file_has_document = 1
            current_input_filename = document_filename[document]
            if (!all_documents_mode && (node_document[document_root[document]] + 0) != selected_document + 0) {
                continue
            }
            found = 1
            output_result(document, query, output_mode)
            file_truthy = final_result_count && final_result_truthy
            if (!all_documents_mode) {
                break
            }
        }
        if (!found) {
            if (!file_has_document) {
                continue
            }
            fail("document index not found: " (selected_document + 0) " in " current_input_filename)
        }
        if (exit_status_mode && !file_truthy) {
            batch_files_exit_status = 1
        }
    }
}

BEGIN {
    document_index = 0
    codec_initialize()
    query = ENVIRON["YSH_QUERY_TEXT"]
    if (query == "") {
        query = "."
    }
    if (output_mode == "") {
        output_mode = "value"
    }
    if (input_format == "" || input_format == "auto") input_format = "yaml"
    if (selected_document == "") {
        selected_document = 0
    }
    if (yaml_indent == "") {
        yaml_indent = 2
    }
    if (unwrap_scalar_mode == "") {
        unwrap_scalar_mode = 1
    }
    presentation_possible = 1
    current_input_file_index = input_file_index + 0
    current_input_filename = input_filename
    file_document_offset = 0
    if (combined_files_mode) {
        for (argument_index = 1; argument_index < ARGC; argument_index++) {
            if (ARGV[argument_index] == "") {
                continue
            }
            declared_file_index = input_file_index + declared_input_file_count
            input_physical_name[declared_file_index] = ARGV[argument_index]
            if (logical_input_list != "") {
                if ((getline logical_input_name < logical_input_list) <= 0) {
                    fail("logical input list is missing an entry")
                }
                input_file_name[declared_file_index] = logical_input_name
            } else {
                input_file_name[declared_file_index] = ARGV[argument_index]
            }
            declared_input_file_count++
        }
        if (logical_input_list != "") {
            close(logical_input_list)
        }
        declared_last_input_file_index = input_file_index + declared_input_file_count - 1
    }
}

{
    if (input_format != "yaml") {
        input_byte_count += length($0) + 1
        if (max_input_bytes > 0 && input_byte_count > max_input_bytes) fail("input size limit exceeded (max " max_input_bytes " bytes)")
        codec_input_buffer = codec_input_buffer $0 "\n"
        next
    }
    if (combined_files_mode && FNR == 1) {
        next_input_file_index = combined_seen_file ? current_input_file_index + 1 : input_file_index + 0
        while (next_input_file_index <= declared_last_input_file_index && input_physical_name[next_input_file_index] != FILENAME) {
            next_input_file_index++
        }
        if (next_input_file_index > declared_last_input_file_index) {
            fail("could not map combined input file: " FILENAME)
        }
        if (!combined_seen_file) {
            current_input_file_index = next_input_file_index
            current_input_filename = input_file_name[current_input_file_index]
            input_file_start_line[current_input_file_index] = NR
            input_file_has_lines[current_input_file_index] = 1
            combined_seen_file = 1
        } else {
            input_file_end_line[current_input_file_index] = NR - 1
            if (multiline_scalar_active || multiline_flow_active) {
                fail("a YAML scalar or flow collection cannot span input files")
            }
            if (block_active) {
                flush_block()
            }
            fail_pending_explicit_keys(NR)
            if (!document_has_content[document_index] && document_explicit[document_index]) {
                create_empty_document(NR)
            }
            if ((document_index in document_root) || document_explicit[document_index] || document_has_content[document_index]) {
                document_index++
            }
            document_ended = 0
            clear_structure()
            current_input_file_index = next_input_file_index
            current_input_filename = input_file_name[current_input_file_index]
            input_file_start_line[current_input_file_index] = NR
            input_file_has_lines[current_input_file_index] = 1
            file_document_offset = document_index
        }
    }
    input_byte_count += length($0) + 1
    if (max_input_bytes > 0 && input_byte_count > max_input_bytes) {
        fail("input size limit exceeded (max " max_input_bytes " bytes)")
    }
    if (inplace_mode) {
        raw_input_line[NR] = $0
    }
    if (block_active) {
        process_line($0, NR)
        next
    }
    if (multiline_scalar_active) {
        if ($0 ~ /^(---|\.\.\.)([[:space:]]|$)/) {
            fail("document markers cannot appear inside quoted scalars on line " NR)
        }
        multiline_scalar_prefix = $0
        sub(/[^ ].*$/, "", multiline_scalar_prefix)
        if ($0 !~ /^[[:space:]]*$/ && length(multiline_scalar_prefix) < multiline_scalar_min_indent) {
            fail("invalid quoted scalar indentation on line " NR)
        }
        multiline_scalar_text = multiline_scalar_text "\n" $0
        if (!multiline_quote_is_open(multiline_scalar_text, multiline_scalar_delimiter)) {
            source_multiline_scalar_end[multiline_scalar_line] = NR
            process_line(multiline_scalar_text, multiline_scalar_line)
            multiline_scalar_active = 0
            multiline_scalar_text = ""
        }
        next
    }
    if (multiline_flow_active) {
        flow_line_prefix = $0
        sub(/[^ ].*$/, "", flow_line_prefix)
        flow_line_trimmed = trim($0)
        flow_line_first = substr(flow_line_trimmed, 1, 1)
        if (flow_line_trimmed != "" && flow_line_trimmed !~ /^#/ &&
            flow_line_first != "}" && flow_line_first != "]" &&
            length(flow_line_prefix) < multiline_flow_min_indent) {
            fail("invalid flow collection indentation on line " NR)
        }
        if (flow_line_trimmed == "---" || flow_line_trimmed == "...") {
            fail("document markers cannot appear inside flow collections on line " NR)
        }
        if (multiline_flow_root == "[" && flow_line_trimmed ~ /^:/) {
            fail("flow mapping values must follow their keys on line " NR)
        }
        if ($0 ~ /,#[^[:space:]]/) {
            fail("comments in flow collections require separation on line " NR)
        }
        if ($0 ~ /^[[:space:]]*#/) {
            multiline_flow_comment_break = 1
            flow_pending_comment_add($0, NR)
            next
        }
        if (multiline_flow_comment_break) {
            flow_previous = trim(multiline_flow_text)
            flow_previous = substr(flow_previous, length(flow_previous), 1)
            if (flow_previous != "," && flow_line_first != "," &&
                flow_line_first != "}" && flow_line_first != "]") {
                fail("flow entries separated by a comment require a comma on line " NR)
            }
            multiline_flow_comment_break = 0
        }
        flow_line_clean = strip_flow_line_comment($0)
        if (trim(flow_line_clean) == "") {
            next
        }
        flow_position_bind_pending(length(multiline_flow_text) + 2)
        flow_position_append($0, flow_line_clean, NR)
        multiline_flow_text = multiline_flow_text " " flow_line_clean
        multiline_flow_depth = flow_balance(multiline_flow_text)
        if (multiline_flow_depth <= 0) {
            source_multiline_flow_end[multiline_flow_line] = NR
            process_line(multiline_flow_text, multiline_flow_line)
            flow_position_clear()
            multiline_flow_active = 0
            multiline_flow_text = ""
        }
        next
    }
    if ($0 ~ /^[[:space:]]*$/ || $0 ~ /^[[:space:]]*#/) {
        process_line($0, NR)
        next
    }
    multiline_scalar_delimiter = $0 ~ /["']/ ? multiline_scalar_quote($0) : ""
    if (multiline_scalar_delimiter != "") {
        multiline_scalar_active = 1
        multiline_scalar_line = NR
        multiline_scalar_text = $0
        multiline_scalar_prefix = $0
        sub(/[^ ].*$/, "", multiline_scalar_prefix)
        multiline_scalar_min_indent = length(multiline_scalar_prefix)
        multiline_scalar_first = substr($0, multiline_scalar_min_indent + 1)
        if (multiline_scalar_first ~ /^-[[:space:]]/ || find_mapping_separator(multiline_scalar_first, 1)) {
            multiline_scalar_min_indent++
        }
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
    if (!exit_status && input_format != "yaml") {
        document_index = 0
        if (input_format == "json") document_root[0] = expression_parse_json_text(codec_input_buffer)
        else if (input_format == "toml") document_root[0] = codec_toml_decode(codec_input_buffer)
        else if (input_format == "ini") document_root[0] = codec_ini_decode(codec_input_buffer)
        else if (input_format == "xml") document_root[0] = codec_xml_decode(codec_input_buffer)
        else fail("unsupported input format: " input_format)
        document_has_content[0] = 1
    } else if (!exit_status) {
        if (combined_files_mode && combined_seen_file) {
            input_file_end_line[current_input_file_index] = NR
        }
        flush_block()
        parser_flush_pending_foot()
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
        parsed_node_count = node_count
        if (inplace_mode && transaction_batch_mode) {
            output_transaction_files(query)
        } else if (inplace_mode) {
            transform_all_documents(query, "")
            source_edit_compile(1, NR, 0)
            if (preserve_only_mode && !presentation_possible) {
                fail("preserve-only edit would produce overlapping source edits")
            }
            if (presentation_possible) {
                emit_preserved_input(1, NR)
            } else {
                emit_all_yaml_documents("")
            }
        } else if (eval_all_mode) {
            output_eval_all(query, output_mode)
        } else if (batch_files_mode) {
            output_batch_files(query, output_mode)
        } else if (all_documents_mode) {
            for (selected_document_cursor = 0; selected_document_cursor <= document_index; selected_document_cursor++) {
                if (selected_document_cursor in document_root) {
                    output_result(selected_document_cursor, query, output_mode)
                }
            }
        } else {
            output_result(selected_document + 0, query, output_mode)
        }
        if (explain_mode && !transaction_batch_mode) {
            output_explain()
        }
        if (exit_status_mode && (batch_files_mode ? batch_files_exit_status : (!final_result_count || !final_result_truthy))) {
            exit_status = 1
        }
    }
    exit exit_status
}
