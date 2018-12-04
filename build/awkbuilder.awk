#!/bin/awk
/^[[:space:]]*#/ { next }
/^[[:space:]]*$/ { next }
{
    sub(/#"$/, "")
    sub(/^[[:space:]]+/, " ")
}
/[^{][[:space:]]*$/ { $0=$0";"}

/^function/ {
    if (lline[0] != "") {
        print lline[0]
    }
    lline[0]=$0
    next
}
/^\// {
    print lline[0]
    lline[0]=$0
    next
}
{ lline[0]=lline[0]$0 }