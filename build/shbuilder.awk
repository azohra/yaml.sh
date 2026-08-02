#!/usr/bin/awk -f

/^# YSH_AWK_PROGRAM$/ {
    print "ysh_awk_program() {"
    print "    LC_ALL=C awk -f - \"$@\" <<'YSH_AWK_EOF'"
    while ((getline parser_line < "src/ysh.awk") > 0) {
        if (parser_line == "YSH_AWK_EOF") {
            print "The AWK parser contains the heredoc terminator" > "/dev/stderr"
            exit 1
        }
        print parser_line
    }
    close("src/ysh.awk")
    print "YSH_AWK_EOF"
    print "}"
    next
}

{
    print
}
