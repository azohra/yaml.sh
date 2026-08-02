#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
CORPUS=${YQ_DIFFERENTIAL_CORPUS:-$SCRIPT_DIR/yq-corpus.tsv}
YSH_BINARY=${YSH_BINARY:-$PROJECT_DIR/ysh}
YQ_BINARY=${YQ_BINARY:-yq}

if ! command -v "$YQ_BINARY" >/dev/null 2>&1; then
    printf '%s\n' "The differential harness requires mikefarah/yq v4.53.3." >&2
    exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
    printf '%s\n' "The differential harness requires jq." >&2
    exit 2
fi
if ! "$YQ_BINARY" --version 2>&1 | grep -q 'version v4.53.3'; then
    printf '%s\n' "The differential oracle must be mikefarah/yq v4.53.3." >&2
    exit 2
fi

YSH_OUTPUT=$(mktemp "${TMPDIR:-/tmp}/ysh-differential-ysh.XXXXXX")
YQ_OUTPUT=$(mktemp "${TMPDIR:-/tmp}/ysh-differential-yq.XXXXXX")
YSH_RAW=$(mktemp "${TMPDIR:-/tmp}/ysh-differential-ysh-raw.XXXXXX")
YQ_RAW=$(mktemp "${TMPDIR:-/tmp}/ysh-differential-yq-raw.XXXXXX")
trap 'rm -f "$YSH_OUTPUT" "$YQ_OUTPUT" "$YSH_RAW" "$YQ_RAW"' 0 1 2 3 15

total=0
passed=0
tab=$(printf '\t')
while IFS="$tab" read -r fixture query; do
    case "$fixture" in
    ''|'#'*) continue ;;
    esac
    total=$((total + 1))
    input=$SCRIPT_DIR/$fixture
    oracle_query="select(document_index == 0) | ($query)"

    if ! "$YSH_BINARY" --json "$query" "$input" > "$YSH_RAW" 2>/dev/null ||
        ! jq -cS . "$YSH_RAW" > "$YSH_OUTPUT"; then
        printf 'YAML.sh failed differential case %s: %s\n' "$total" "$query" >&2
        exit 1
    fi
    if ! "$YQ_BINARY" --yaml-fix-merge-anchor-to-spec -o=json -I=0 "$oracle_query" "$input" > "$YQ_RAW" 2>/dev/null ||
        ! jq -cS . "$YQ_RAW" > "$YQ_OUTPUT"; then
        printf 'yq failed differential case %s: %s\n' "$total" "$query" >&2
        exit 1
    fi
    if ! cmp -s "$YSH_OUTPUT" "$YQ_OUTPUT"; then
        printf 'Differential mismatch %s (%s): %s\n' "$total" "$fixture" "$query" >&2
        printf '%s\n' 'YAML.sh:' >&2
        sed 's/^/  /' "$YSH_OUTPUT" >&2
        printf '%s\n' 'yq:' >&2
        sed 's/^/  /' "$YQ_OUTPUT" >&2
        exit 1
    fi
    passed=$((passed + 1))
done < "$CORPUS"

printf 'yq v4.53.3 differential results: %s/%s pass\n' "$passed" "$total"
if [ "$total" -lt 100 ]; then
    printf 'Differential corpus must contain at least 100 cases; found %s\n' "$total" >&2
    exit 1
fi
