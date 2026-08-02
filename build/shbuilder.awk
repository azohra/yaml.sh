#!/usr/bin/awk -f

/^YAML_AWK_PARSER=/ {
    print "YAML_AWK_PARSER='"
    while ((getline parser_line < "src/ysh.awk") > 0) {
        if (index(parser_line, sprintf("%c", 39))) {
            print "The AWK parser cannot contain a single quote" > "/dev/stderr"
            exit 1
        }
        print parser_line
    }
    close("src/ysh.awk")
    print "'"
    next
}

{
    print
}
