#!/bin/sh

set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
CORPUS=$ROOT/test/workflows.tsv
FIXTURES=$ROOT/test/workflows
YSH_BINARY=${YSH_BINARY:-$ROOT/ysh}

tab=$(printf '\t')
total=0
passed=0
families=0
previous_family=

while IFS="$tab" read -r family id fixture query expected; do
    case "$family" in
    ''|'#'*) continue ;;
    esac
    total=$((total + 1))
    if [ "$family" != "$previous_family" ]; then
        families=$((families + 1))
        previous_family=$family
    fi
    if ! actual=$("$YSH_BINARY" --json "$query" "$FIXTURES/$fixture" 2>&1); then
        printf 'Workflow failed: %s/%s\n%s\n' "$family" "$id" "$actual" >&2
        exit 1
    fi
    if [ "$actual" != "$expected" ]; then
        printf 'Workflow mismatch: %s/%s\nexpected: %s\nactual:   %s\n' \
            "$family" "$id" "$expected" "$actual" >&2
        exit 1
    fi
    passed=$((passed + 1))
done < "$CORPUS"

if [ "$families" -lt 5 ] || [ "$total" -lt 24 ]; then
    printf 'Workflow corpus is below its release floor: %s families, %s cases\n' "$families" "$total" >&2
    exit 1
fi

printf 'Real-world workflows: %s/%s across %s families.\n' "$passed" "$total" "$families"
