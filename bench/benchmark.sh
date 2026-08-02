#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
YSH_BINARY=${YSH_BINARY:-$PROJECT_DIR/ysh}
BENCH_REPEATS=${YSH_BENCH_REPEATS:-20}

INPUT=$(mktemp "${TMPDIR:-/tmp}/ysh-benchmark.XXXXXX")
trap 'rm -f "$INPUT"' 0 1 2 3 15

printf 'items,bytes,repeats,seconds\n'
for item_count in 100 1000 5000; do
    awk -v count="$item_count" 'BEGIN {
        print "items:"
        for (i = 1; i <= count; i++) {
            print "  - name: service-" i
            print "    port: " (2000 + i)
            print "    enabled: " (i % 2 ? "true" : "false")
        }
    }' > "$INPUT"
    byte_count=$(wc -c < "$INPUT" | tr -d ' ')
    start=$(date +%s)
    iteration=0
    while [ "$iteration" -lt "$BENCH_REPEATS" ]; do
        "$YSH_BINARY" --json '.items | map(select(.enabled) | .port) | length' "$INPUT" >/dev/null
        iteration=$((iteration + 1))
    done
    finish=$(date +%s)
    printf '%s,%s,%s,%s\n' "$item_count" "$byte_count" "$BENCH_REPEATS" "$((finish - start))"
done
