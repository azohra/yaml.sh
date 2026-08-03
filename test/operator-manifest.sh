#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
MANIFEST=${YSH_OPERATOR_MANIFEST:-$SCRIPT_DIR/operator-manifest.tsv}
TESTS=$SCRIPT_DIR/test.sh

summary=$(awk -F '\t' '
    function clean(value) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        return value
    }
    /^#/ || !NF { next }
    {
        kind = clean($1)
        name = clean($2)
        status = clean($3)
        forms = clean($4)
        evidence = clean($5)
        if (NF != 5 || kind != "operator" || name == "" || forms == "" || evidence == "") {
            print "invalid operator manifest row: " $0 > "/dev/stderr"
            failed = 1
            next
        }
        if (status != "supported" && status != "focused" && status != "excluded") {
            print "invalid status for " name ": " status > "/dev/stderr"
            failed = 1
        }
        if (name in seen) {
            print "duplicate operator: " name > "/dev/stderr"
            failed = 1
        }
        seen[name] = 1
        count++
        totals[status]++
        test_count = split(evidence, tests, /,[[:space:]]*/)
        for (i = 1; i <= test_count; i++) {
            test_name = clean(tests[i])
            if (test_name !~ /^test[A-Za-z0-9_]+$/) {
                print "invalid evidence for " name ": " test_name > "/dev/stderr"
                failed = 1
            } else {
                print "test " test_name
            }
        }
    }
    END {
        if (!count) {
            print "operator manifest has no capability rows" > "/dev/stderr"
            failed = 1
        }
        print "summary " count " " totals["supported"] " " totals["focused"] " " totals["excluded"]
        exit failed
    }
' "$MANIFEST")

printf '%s\n' "$summary" | while read -r kind value; do
    [ "$kind" != test ] || grep -Fq "$value()" "$TESTS" || {
        printf 'Operator manifest references missing test %s\n' "$value" >&2
        exit 1
    }
done

printf '%s\n' "$summary" | awk '$1 == "summary" {
    printf "Operator manifest: %s areas; %s supported, %s focused, %s excluded\n", $2, $3, $4, $5
}'
