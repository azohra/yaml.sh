function raise(msg) {
    print msg > "/dev/stderr"
    if (force_complete) {
        exit_status = 1
    } else {
        exit 1
    }
}

function level() {
    match($0, /^[[:space:]]*/)
    if (RLENGTH % 2 != 0) {
        raise("Bad indentation on line "NR". Number of spaces uneven.")
    }
    return RLENGTH / 2
}

function join_stack(depth) {
    r = sprintf("%"block_level"s","")
    gsub(/ /,"-",r)
    for (i = 0; i <= depth; i++) {
        r = r "." stack[i]
    }
    sub(/^\./, "", r)
    return r
}

function safe_split(input, output) {
    split(input, chars, "")
    in_quote = 1
    acc = ""
    count = 0
    for (i=0; i <= length(input); i++) {
        c=chars[i]
        if (c=="\"") {
            in_quote = (in_quote + 1) % 2
        }
        if (c=="," && in_quote) {
            output[count++] = acc
            acc = ""
        } else {
            acc = acc c
        }
    }
    output[count++] = acc
}

function remove_sur_quotes(target) {
    sub(/^[[:space:]]*\"/, "", target) #"
    sub(/\"[[:space:]]*$/, "", target) #"
    return target
}

function check_started() {
    if (started == 0) {
        raise("Keys must be added before line "NR)
    }
}

/^---/ {
    if (started==0) {
        started=1
    } else {
        block_level++
    }
    next
}

/^[[:space:]]*[^[:space:]]+:/ {
    started=1
    depth=level()
    key=$1
    sub(/:.*$/, "", key)
    stack[depth] = key
}

/^[[:space:]]*[^[:space:]]+:[[:space:]]+[^[:space:]]+/ {
    started=1
    depth=level()
    val=$0
    sub(/^[[:space:]]*[^[:space:]]+:[[:space:]]+/, "", val)
    val = remove_sur_quotes(val)
    print join_stack(depth) "=\"" val "\""
    next
}

/^[[:space:]]*\-/ {
    check_started()
    depth=level()
    stack_key=join_stack(depth-1)
    indx=list_counter[stack_key]++
    stack[depth]="[" indx "]"
}

/^[[:space:]]*-[[:space:]]+\{.*\}[[:space:]]*$/ {
    check_started()
    line=$0
    sub(/^[[:space:]]*-[[:space:]]+\{/, "", line)
    sub(/\}[[:space:]]*$/, "", line)

    safe_split(line, entries)
    for (i in entries) {
        key=entries[i]
        val=entries[i]

        sub(/^[[:space:]]*/, "", key)
        sub(/:.*$/, "", key)

        sub(/^[[:space:]]*[^[:space:]]+:[[:space:]]+\"?/, "", val) #"
        sub(/\"?[[:space:]]*$/, "", val) #"
        val = remove_sur_quotes(val)

        print join_stack(depth) "." key "=\"" val "\""
    }
    delete entries
    next
}

/^[[:space:]]*-[[:space:]][^[:space:]]+:/ {
    check_started()
    depth++
    key=$0
    sub(/^[[:space:]]*-[[:space:]]/, "", key)
    sub(/:.*$/, "", key)
    stack[depth]=key
}

/^[[:space:]]*-[[:space:]][^[:space:]]+:[[:space:]]+[^[:space:]]+/ {
    check_started()
    val=$0
    sub(/^[[:space:]]*-[[:space:]][^[:space:]]+:[[:space:]]+/, "", val)
    val = remove_sur_quotes(val)
    print join_stack(depth) "=\"" val "\""
    next
}

/^[[:space:]]*-[[:space:]]+[^[:space:]]+/ {
    check_started()
    val=$0
    sub(/^[[:space:]]*-[[:space:]]+/, "", val)
    sub(/[[:space:]]*$/, "", val)
    val = remove_sur_quotes(val)
    print join_stack(depth) "=\"" val "\""
    next
}

/^[[:space:]]*[^[:space:]]+:[[:space:]]*$/ {next}
/^[[:space:]]*-[[:space:]]+[^[:space:]]+:[[:space:]]*$/ {next}
/^[[:space:]]*$/ { next }
/^[[:space:]]*\#/ { next }

{
    raise("Unkown syntax on line "NR)
}

END	{
    exit exit_status
}
