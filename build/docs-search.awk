#!/usr/bin/awk -f

function json_escape(value,    out) {
    out = value
    gsub(/\\/, "\\\\", out)
    gsub(/"/, "\\\"", out)
    gsub(/\r/, "", out)
    gsub(/\n/, "\\n", out)
    return out
}

function trim(value) {
    sub(/^[[:space:]]+/, "", value)
    sub(/[[:space:]]+$/, "", value)
    return value
}

function plain(value,    before, link, after, split_at) {
    while (match(value, /\[[^]]+\]\([^)]+\)/)) {
        before = substr(value, 1, RSTART - 1)
        link = substr(value, RSTART + 1, RLENGTH - 2)
        after = substr(value, RSTART + RLENGTH)
        split_at = index(link, "](")
        value = before substr(link, 1, split_at - 1) after
    }
    gsub(/```[^`]*/, " ", value)
    gsub(/`/, "", value)
    gsub(/\*\*/, "", value)
    gsub(/^#+[[:space:]]*/, "", value)
    gsub(/^[-*>0-9.]+[[:space:]]*/, "", value)
    gsub(/\|/, " ", value)
    gsub(/[[:space:]]+/, " ", value)
    return trim(value)
}

function finish_page(    url, item) {
    if (current_file == "") return
    slug = current_file
    sub(/^.*\//, "", slug)
    sub(/\.md$/, "", slug)
    url = slug == "README" ? "/docs/" : "/docs/" slug "/"
    item = "  {\"title\":\"" json_escape(title) "\",\"url\":\"" url "\",\"text\":\"" json_escape(trim(text)) "\"}"
    if (emitted++) printf ",\n"
    printf "%s", item
}

BEGIN {
    print "["
}

FNR == 1 {
    finish_page()
    current_file = FILENAME
    title = ""
    text = ""
    in_code = 0
}

/^```/ {
    in_code = !in_code
    next
}

{
    line = $0
    if (title == "" && line ~ /^# /) {
        title = substr(line, 3)
    }
    if (!in_code) {
        line = plain(line)
        if (line != "" && line !~ /^---+$/) text = text " " line
    }
}

END {
    finish_page()
    print "\n]"
}
