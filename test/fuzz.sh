#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
YSH_BINARY=${YSH_BINARY:-$PROJECT_DIR/ysh}
FUZZ_CASES=${YSH_FUZZ_CASES:-250}

if ! command -v jq >/dev/null 2>&1; then
    printf '%s\n' "The fuzz harness requires jq." >&2
    exit 2
fi

INPUT=$(mktemp "${TMPDIR:-/tmp}/ysh-fuzz-input.XXXXXX")
ROUNDTRIP=$(mktemp "${TMPDIR:-/tmp}/ysh-fuzz-roundtrip.XXXXXX")
FIRST=$(mktemp "${TMPDIR:-/tmp}/ysh-fuzz-first.XXXXXX")
SECOND=$(mktemp "${TMPDIR:-/tmp}/ysh-fuzz-second.XXXXXX")
trap 'rm -f "$INPUT" "$ROUNDTRIP" "$FIRST" "$SECOND"' 0 1 2 3 15

case_id=1
while [ "$case_id" -le "$FUZZ_CASES" ]; do
    awk -v seed="$case_id" 'BEGIN {
        count = (seed % 7) + 1
        print "meta:"
        print "  id: " seed
        print "  enabled: " (seed % 2 ? "true" : "false")
        print "  label: \"case " seed " # deterministic\""
        print "values: [" seed ", " (seed + 1) ", null, \"v" seed "\"]"
        print "items:"
        for (i = 1; i <= count; i++) {
            print "  - name: item-" seed "-" i
            print "    score: " ((seed * 17 + i * 13) % 1000)
            print "    active: " ((seed + i) % 3 ? "true" : "false")
        }
        print "message: |-"
        print "  generated case " seed
        print "  line " (seed * 3)
    }' > "$INPUT"

    "$YSH_BINARY" --json '.' "$INPUT" | jq -cS . > "$FIRST"
    "$YSH_BINARY" -o yaml '.' "$INPUT" > "$ROUNDTRIP"
    "$YSH_BINARY" --json '.' "$ROUNDTRIP" | jq -cS . > "$SECOND"
    if ! cmp -s "$FIRST" "$SECOND"; then
        printf 'Round-trip property failed for deterministic case %s\n' "$case_id" >&2
        exit 1
    fi

    expected=$(jq -c '.items | map(.name) | length' "$FIRST")
    actual=$("$YSH_BINARY" --json '.items | map(.name) | length' "$INPUT")
    if [ "$actual" != "$expected" ]; then
        printf 'Query property failed for deterministic case %s\n' "$case_id" >&2
        exit 1
    fi
    case_id=$((case_id + 1))
done

printf 'Deterministic YAML properties: %s/%s pass\n' "$FUZZ_CASES" "$FUZZ_CASES"
