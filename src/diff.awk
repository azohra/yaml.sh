function remember(type, value) {
    diff_count++
    diff_type[diff_count] = type
    diff_text[diff_count] = value
}

function fallback(    prefix, suffix, i) {
    prefix = 0
    while (prefix < old_count && prefix < new_count && old_line[prefix + 1] == new_line[prefix + 1]) {
        prefix++
    }
    suffix = 0
    while (suffix < old_count - prefix && suffix < new_count - prefix &&
        old_line[old_count - suffix] == new_line[new_count - suffix]) {
        suffix++
    }
    for (i = 1; i <= prefix; i++) remember(" ", old_line[i])
    for (i = prefix + 1; i <= old_count - suffix; i++) remember("-", old_line[i])
    for (i = prefix + 1; i <= new_count - suffix; i++) remember("+", new_line[i])
    for (i = old_count - suffix + 1; i <= old_count; i++) remember(" ", old_line[i])
}

function myers(    maximum, d, k, x, y, previous_k, previous_x, previous_y, done, distance, i) {
    maximum = old_count + new_count
    frontier[1] = 0
    for (d = 0; d <= maximum; d++) {
        # Bound the trace table. Large rewrites use the exact prefix/suffix fallback.
        if (d > 256) return 0
        for (k = -d; k <= d; k += 2) {
            if (k == -d || (k != d && frontier[k - 1] < frontier[k + 1])) {
                x = frontier[k + 1]
            } else {
                x = frontier[k - 1] + 1
            }
            y = x - k
            while (x < old_count && y < new_count && old_line[x + 1] == new_line[y + 1]) {
                x++
                y++
            }
            frontier[k] = x
            trace[d, k] = x
            if (x >= old_count && y >= new_count) {
                distance = d
                done = 1
                break
            }
        }
        if (done) break
    }
    if (!done) return 0
    x = old_count
    y = new_count
    reverse_count = 0
    for (d = distance; d > 0; d--) {
        k = x - y
        if (k == -d || (k != d && trace[d - 1, k - 1] < trace[d - 1, k + 1])) {
            previous_k = k + 1
        } else {
            previous_k = k - 1
        }
        previous_x = trace[d - 1, previous_k]
        previous_y = previous_x - previous_k
        while (x > previous_x && y > previous_y) {
            reverse_type[++reverse_count] = " "
            reverse_text[reverse_count] = old_line[x]
            x--
            y--
        }
        if (x == previous_x) {
            reverse_type[++reverse_count] = "+"
            reverse_text[reverse_count] = new_line[y]
            y--
        } else {
            reverse_type[++reverse_count] = "-"
            reverse_text[reverse_count] = old_line[x]
            x--
        }
    }
    while (x > 0 && y > 0) {
        reverse_type[++reverse_count] = " "
        reverse_text[reverse_count] = old_line[x]
        x--
        y--
    }
    while (x > 0) {
        reverse_type[++reverse_count] = "-"
        reverse_text[reverse_count] = old_line[x--]
    }
    while (y > 0) {
        reverse_type[++reverse_count] = "+"
        reverse_text[reverse_count] = new_line[y--]
    }
    for (i = reverse_count; i >= 1; i--) remember(reverse_type[i], reverse_text[i])
    return 1
}

function emit_hunk(start, finish,    i, old_start, new_start, old_size, new_size, missing_eol) {
    old_start = diff_old_line[start]
    new_start = diff_new_line[start]
    old_size = 0
    new_size = 0
    for (i = start; i <= finish; i++) {
        if (diff_type[i] != "+") old_size++
        if (diff_type[i] != "-") new_size++
    }
    if (!old_size) old_start--
    if (!new_size) new_start--
    printf "@@ -%d,%d +%d,%d @@\n", old_start, old_size, new_start, new_size
    for (i = start; i <= finish; i++) {
        print diff_type[i] diff_text[i]
        missing_eol = 0
        if (diff_type[i] != "+" && diff_old_line[i] == old_count && !old_has_eol) {
            missing_eol = 1
        }
        if (diff_type[i] != "-" && diff_new_line[i] == new_count && !new_has_eol) {
            missing_eol = 1
        }
        if (missing_eol) print "\\ No newline at end of file"
    }
}

FILENAME == ARGV[1] { old_line[++old_count] = $0; next }
FILENAME == ARGV[2] { new_line[++new_count] = $0; next }

END {
    old_has_eol = old_count == 0 || old_newlines + 0 == old_count
    new_has_eol = new_count == 0 || new_newlines + 0 == new_count
    if (!myers()) fallback()
    if (old_count == new_count && old_count > 0 && old_has_eol != new_has_eol) {
        same_text = 1
        for (i = 1; i <= old_count; i++) {
            if (old_line[i] != new_line[i]) {
                same_text = 0
                break
            }
        }
        if (same_text) {
            diff_count = 0
            for (i = 1; i < old_count; i++) remember(" ", old_line[i])
            remember("-", old_line[old_count])
            remember("+", new_line[new_count])
        }
    }
    old_number = 1
    new_number = 1
    first_change = 0
    last_change = 0
    for (i = 1; i <= diff_count; i++) {
        diff_old_line[i] = old_number
        diff_new_line[i] = new_number
        if (diff_type[i] != "+") old_number++
        if (diff_type[i] != "-") new_number++
        if (diff_type[i] != " ") {
            if (!first_change) first_change = i
            last_change = i
        }
    }
    if (!first_change) exit
    if (substr(path, 1, 1) == "/") {
        print "--- " path
        print "+++ " path
    } else {
        print "--- a/" path
        print "+++ b/" path
    }
    hunk_start = first_change > 3 ? first_change - 3 : 1
    previous_change = first_change
    for (i = first_change + 1; i <= last_change; i++) {
        if (diff_type[i] != " " && i - previous_change > 6) {
            emit_hunk(hunk_start, previous_change + 3 < diff_count ? previous_change + 3 : diff_count)
            hunk_start = i > 3 ? i - 3 : 1
        }
        if (diff_type[i] != " ") previous_change = i
    }
    emit_hunk(hunk_start, last_change + 3 < diff_count ? last_change + 3 : diff_count)
}
