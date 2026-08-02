#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
YSH_BINARY=${YSH_BINARY:-$PROJECT_DIR/ysh}
SCALE_NODES=${YSH_SCALE_NODES:-125000}
SCALE_DOCUMENTS=${YSH_SCALE_DOCUMENTS:-1500}
MAX_SECONDS=${YSH_SCALE_MAX_SECONDS:-30}
MAX_RSS_KB=${YSH_SCALE_MAX_RSS_KB:-262144}

INPUT=$(mktemp "${TMPDIR:-/tmp}/ysh-scale-input.XXXXXX")
STREAM=$(mktemp "${TMPDIR:-/tmp}/ysh-scale-stream.XXXXXX")
OUTPUT=$(mktemp "${TMPDIR:-/tmp}/ysh-scale-output.XXXXXX")
ERROR=$(mktemp "${TMPDIR:-/tmp}/ysh-scale-error.XXXXXX")
TIME_OUTPUT=$(mktemp "${TMPDIR:-/tmp}/ysh-scale-time.XXXXXX")
trap 'rm -f "$INPUT" "$STREAM" "$OUTPUT" "$ERROR" "$TIME_OUTPUT"' 0 1 2 3 15

awk -v count="$SCALE_NODES" 'BEGIN {
    print "items:"
    for (i = 1; i <= count; i++) print "  - " i
}' > "$INPUT"

if "$YSH_BINARY" --json . "$INPUT" > "$OUTPUT" 2> "$ERROR"; then
    printf 'Default node limit accepted %s scalar payload nodes unexpectedly.\n' "$SCALE_NODES" >&2
    exit 1
fi
if ! grep -q 'node limit exceeded' "$ERROR"; then
    printf '%s\n' 'Default node limit did not report the expected diagnostic.' >&2
    exit 1
fi

start=$(date +%s)
rss_kb=0
case "$(uname -s)" in
Darwin)
    /usr/bin/time -l "$YSH_BINARY" --max-nodes "$((SCALE_NODES * 2 + 10))" --json '.items | length' "$INPUT" > "$OUTPUT" 2> "$TIME_OUTPUT"
    rss_bytes=$(awk '/maximum resident set size/ { print $1; exit }' "$TIME_OUTPUT")
    rss_kb=$((rss_bytes / 1024))
    ;;
*)
    /usr/bin/time -v -o "$TIME_OUTPUT" "$YSH_BINARY" --max-nodes "$((SCALE_NODES * 2 + 10))" --json '.items | length' "$INPUT" > "$OUTPUT" 2> "$ERROR"
    rss_kb=$(awk -F ': *' '/Maximum resident set size/ { print $2; exit }' "$TIME_OUTPUT")
    ;;
esac
finish=$(date +%s)
elapsed=$((finish - start))

if [ "$(cat "$OUTPUT")" != "$SCALE_NODES" ]; then
    printf 'Scale query returned %s instead of %s.\n' "$(cat "$OUTPUT")" "$SCALE_NODES" >&2
    exit 1
fi
if [ "$elapsed" -gt "$MAX_SECONDS" ]; then
    printf 'Scale query took %ss; contract is at most %ss.\n' "$elapsed" "$MAX_SECONDS" >&2
    exit 1
fi
if [ -n "$rss_kb" ] && [ "$rss_kb" -gt "$MAX_RSS_KB" ]; then
    printf 'Scale query used %s KiB RSS; contract is at most %s KiB.\n' "$rss_kb" "$MAX_RSS_KB" >&2
    exit 1
fi

awk -v count="$SCALE_DOCUMENTS" 'BEGIN {
    for (i = 0; i < count; i++) {
        print "---"
        print "index: " i
        print "value: document-" i
    }
}' > "$STREAM"
if [ "$("$YSH_BINARY" --max-nodes "$((SCALE_DOCUMENTS * 10 + 10))" --document "$((SCALE_DOCUMENTS - 1))" '.index' "$STREAM")" != "$((SCALE_DOCUMENTS - 1))" ]; then
    printf 'Could not select the final document in a %s-document stream.\n' "$SCALE_DOCUMENTS" >&2
    exit 1
fi

bytes=$(wc -c < "$INPUT" | tr -d ' ')
printf 'Scale contract: %s payload nodes, %s bytes, %ss, %s KiB RSS; %s documents pass\n' "$SCALE_NODES" "$bytes" "$elapsed" "$rss_kb" "$SCALE_DOCUMENTS"
