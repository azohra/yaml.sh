#!/usr/bin/awk -f

/^# YSH_AWK_PROGRAM$/ {
    print "ysh_awk_program() {"
    print "    LC_ALL=C awk -f - \"$@\" <<'YSH_AWK_EOF'"
    module_count = split(awk_modules, module, /[[:space:]]+/)
    for (module_index = 1; module_index <= module_count; module_index++) {
        while ((getline parser_line < module[module_index]) > 0) {
            if (parser_line == "YSH_AWK_EOF") {
                print "An AWK module contains the heredoc terminator: " module[module_index] > "/dev/stderr"
                exit 1
            }
            print parser_line
        }
        close(module[module_index])
    }
    print "YSH_AWK_EOF"
    print "}"
    next
}

/^# YSH_DIFF_PROGRAM$/ {
    print "ysh_diff_program() {"
    print "    LC_ALL=C awk -f - \"$@\" <<'YSH_DIFF_AWK_EOF'"
    while ((getline diff_line < "src/diff.awk") > 0) {
        if (diff_line == "YSH_DIFF_AWK_EOF") {
            print "The AWK diff renderer contains the heredoc terminator" > "/dev/stderr"
            exit 1
        }
        print diff_line
    }
    close("src/diff.awk")
    print "YSH_DIFF_AWK_EOF"
    print "}"
    next
}

{
    print
}
