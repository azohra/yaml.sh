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
    /^## CLI boundaries/ { done = 1 }
    done { next }
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
        if (area in seen) {
            print "duplicate manifest area: " area > "/dev/stderr"
            failed = 1
        }
        seen[area] = 1
        count++
        totals[status]++
        rest = evidence
        evidence_count = 0
        while (match(rest, /`test[A-Za-z0-9_]+`/)) {
            name = substr(rest, RSTART + 1, RLENGTH - 2)
            print "test " name
            evidence_count++
            rest = substr(rest, RSTART + RLENGTH)
        }
        if (!evidence_count) {
            print "missing evidence " area > "/dev/stderr"
            failed = 1
        }
    }
    END {
        if (!count) {
            print "operator manifest has no capability rows" > "/dev/stderr"
            failed = 1
        }
        print "summary " count " " totals["Supported"] " " totals["Focused"] " " totals["Excluded"]
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
