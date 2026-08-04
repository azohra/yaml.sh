#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
YSH_BINARY=${YSH_BINARY:-$PROJECT_DIR/ysh}

INPUT=$(mktemp "${TMPDIR:-/tmp}/ysh-adversarial.XXXXXX")
trap 'rm -f "$INPUT"' 0 1 2 3 15
PASSED=0

awk 'BEGIN { for (i = 0; i < 2048; i++) printf "x"; print "" }' > "$INPUT"
if "$YSH_BINARY" --max-input-bytes 1024 --json '.' "$INPUT" >/dev/null 2>&1; then
    printf '%s\n' "Input-size limit failed" >&2
    exit 1
fi
PASSED=$((PASSED + 1))

awk 'BEGIN { for (i = 1; i <= 200; i++) print "key" i ": " i }' > "$INPUT"
if "$YSH_BINARY" --max-nodes 100 --json '.' "$INPUT" >/dev/null 2>&1; then
    printf '%s\n' "Node limit failed" >&2
    exit 1
fi
PASSED=$((PASSED + 1))

awk 'BEGIN { for (i = 0; i < 40; i++) { for (j = 0; j < i * 2; j++) printf " "; print "level" i ":" } }' > "$INPUT"
if "$YSH_BINARY" --max-depth 16 --json '.' "$INPUT" >/dev/null 2>&1; then
    printf '%s\n' "Depth limit failed" >&2
    exit 1
fi
PASSED=$((PASSED + 1))

printf '%s\n' 'root: &root' '  child: *root' > "$INPUT"
if "$YSH_BINARY" --json '..' "$INPUT" >/dev/null 2>&1; then
    printf '%s\n' "Recursive alias guard failed" >&2
    exit 1
fi
PASSED=$((PASSED + 1))

printf 'Adversarial limits: %d checks pass\n' "$PASSED"
