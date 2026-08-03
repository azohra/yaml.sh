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

