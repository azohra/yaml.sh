#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
YSH_BINARY=${YSH_BINARY:-$PROJECT_DIR/ysh}
BENCH_REPEATS=${YSH_BENCH_REPEATS:-20}
# Ceilings are ~3x the release-machine measurements so only a real
# regression trips them; YSH_BENCHMARK_SCALE loosens them on slow hosts.
BENCH_SCALE=${YSH_BENCHMARK_SCALE:-1}
case "$BENCH_SCALE" in
*[!0-9]*|'') printf '%s\n' 'YSH_BENCHMARK_SCALE must be a positive integer.' >&2; exit 2 ;;
esac
budget_for() {
    case "$1" in
    100) printf '%s' $((3 * BENCH_SCALE)) ;;
    1000) printf '%s' $((10 * BENCH_SCALE)) ;;
    5000) printf '%s' $((45 * BENCH_SCALE)) ;;
    esac
}
BENCH_STATUS=0

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
    budget=$(budget_for "$item_count")
    if [ "$(awk -v s="$seconds" -v b="$budget" 'BEGIN { print (s > b) ? 1 : 0 }')" -eq 1 ]; then
        printf 'Benchmark budget exceeded: %s items took %ss (budget %ss)\n' "$item_count" "$seconds" "$budget" >&2
        BENCH_STATUS=1
    fi
done

exit "$BENCH_STATUS"
