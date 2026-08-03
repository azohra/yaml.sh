#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
YSH_BINARY=${YSH_BINARY:-$PROJECT_DIR/ysh}
CASES=${YSH_PARSER_BOUNDARIES:-$SCRIPT_DIR/parser-boundaries.tsv}
OUTPUT=$(mktemp "${TMPDIR:-/tmp}/ysh-parser-boundary-output.XXXXXX")
ERROR=$(mktemp "${TMPDIR:-/tmp}/ysh-parser-boundary-error.XXXXXX")
trap 'rm -f "$OUTPUT" "$ERROR"' 0 1 2 3 15

total=0
accepted=0
rejected=0
tab=$(printf '\t')
while IFS="$tab" read -r outcome name yaml; do
    case "$outcome" in
    ''|'#'*) continue ;;
    esac
    total=$((total + 1))
    if printf '%b' "$yaml" | "$YSH_BINARY" --json . > "$OUTPUT" 2> "$ERROR"; then
        status=accept
    else
        status=reject
    fi
    if [ "$status" != "$outcome" ]; then
        printf 'Parser boundary %s expected %s, got %s\n' "$name" "$outcome" "$status" >&2
        cat "$ERROR" >&2
        exit 1
    fi
    if [ "$status" = accept ]; then
        accepted=$((accepted + 1))
    else
        rejected=$((rejected + 1))
    fi
done < "$CASES"

if [ "$accepted" -lt 5 ] || [ "$rejected" -lt 10 ]; then
    printf 'Parser boundary matrix is incomplete: %s accepted, %s rejected\n' "$accepted" "$rejected" >&2
    exit 1
fi

printf 'Parser boundaries: %s/%s deliberate accepts, %s/%s fail-closed rejections\n' "$accepted" "$total" "$rejected" "$total"
