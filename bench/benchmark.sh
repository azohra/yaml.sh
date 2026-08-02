#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
YSH_BINARY=${YSH_BINARY:-$PROJECT_DIR/ysh}
BENCH_REPEATS=${YSH_BENCH_REPEATS:-20}

INPUT=$(mktemp "${TMPDIR:-/tmp}/ysh-benchmark.XXXXXX")
TIME_OUTPUT=$(mktemp "${TMPDIR:-/tmp}/ysh-benchmark-time.XXXXXX")
trap 'rm -f "$INPUT" "$TIME_OUTPUT"' 0 1 2 3 15

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
    YSH_BENCH_BINARY=$YSH_BINARY \
    YSH_BENCH_INPUT=$INPUT \
    YSH_BENCH_REPEATS=$BENCH_REPEATS \
        /usr/bin/time -p sh -c '
            iteration=0
            while [ "$iteration" -lt "$YSH_BENCH_REPEATS" ]; do
                "$YSH_BENCH_BINARY" --json ".items | map(select(.enabled) | .port) | length" "$YSH_BENCH_INPUT" >/dev/null
                iteration=$((iteration + 1))
            done
        ' 2> "$TIME_OUTPUT"
    seconds=$(awk '/^real / { print $2; exit }' "$TIME_OUTPUT")
    printf '%s,%s,%s,%s\n' "$item_count" "$byte_count" "$BENCH_REPEATS" "$seconds"
done
