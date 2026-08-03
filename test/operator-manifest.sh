#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
MANIFEST=${YSH_OPERATOR_MANIFEST:-$PROJECT_DIR/_static/_www/docs/operators.md}
TESTS=$SCRIPT_DIR/test.sh

summary=$(awk -F '|' '
    function clean(value) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        return value
    }
    /^\| yq area / || /^\|---/ { next }
    /^\|/ {
        area = clean($2)
        status = clean($3)
        evidence = clean($5)
        if (area == "" || evidence == "") {
            print "invalid manifest row: " $0 > "/dev/stderr"
            failed = 1
        }
        if (status != "Supported" && status != "Focused" && status != "Excluded") {
            print "invalid manifest status for " area ": " status > "/dev/stderr"
            failed = 1
        }
        count++
        totals[status]++
        if (match(evidence, /`test[A-Za-z0-9_]+`/)) {
            name = substr(evidence, RSTART + 1, RLENGTH - 2)
            print "test " name
        } else {
            print "missing evidence " area > "/dev/stderr"
            failed = 1
        }
    }
    END {
        if (count < 55 || totals["Supported"] < 35 || totals["Focused"] < 8 || totals["Excluded"] < 5) {
            print "manifest coverage is incomplete" > "/dev/stderr"
            failed = 1
        }
        print "summary " count " " totals["Supported"] " " totals["Focused"] " " totals["Excluded"]
        exit failed
    }
' "$MANIFEST")

printf '%s\n' "$summary" | while read -r kind value; do
    [ "$kind" != test ] || grep -q "^$value()" "$TESTS" || {
        printf 'Operator manifest references missing test %s\n' "$value" >&2
        exit 1
    }
done

for form in trim to_string column array_to_map split_doc 'sort_keys(..)'; do
    grep -Fq "$form" "$MANIFEST" || {
        printf 'Operator manifest is missing %s\n' "$form" >&2
        exit 1
    }
done

printf '%s\n' "$summary" | awk '$1 == "summary" {
    printf "Operator manifest: %s areas; %s supported, %s focused, %s excluded\n", $2, $3, $4, $5
}'
