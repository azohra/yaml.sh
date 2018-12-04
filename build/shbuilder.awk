#!/bin/awk
/^YAML_AWK_PARSER=/ {
    print "YAML_AWK_PARSER='"
    print system("awk -f build/awkbuilder.awk src/ysh.awk")
    print "'"
    next
}

/^[[:space:]]*$/ { next }
/^[[:space:]]*#[^!]/ { next }

{
    print $0
}