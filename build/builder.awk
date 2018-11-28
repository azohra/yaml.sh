#!/bin/awk

# YAML_AWK_PARSER=$(cat src/ysh.awk)
/^[^[:space:]]+[[:space:]]*=[[:space:]]*\$\(cat[[:space:]]+[^[:space:]]+[[:space:]]*\)/ {
    variable=$1
    file=$0
    sub(/[[:space:]]*=.*$/, "", variable)
    sub(/[^[:space:]]+[[:space:]]*=[[:space:]]*\$\(cat[[:space:]]+/, "", file)
    sub(/[[:space:]]*\)[[:space:]]*$/, "", file)
    print variable "='''"
    print system("cat " file)
    print "'''"
    next
}

/^[[:space:]]*$/ { next }
/^[[:space:]]*#[^!]/ { next }

{
    print $0
}