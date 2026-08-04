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
family_names=
seen_families=

while IFS="$tab" read -r family id fixture query expected; do
    case "$family" in
    ''|'#'*) continue ;;
    esac
    total=$((total + 1))
    case "$seen_families" in
    *"|$family|"*) ;;
    *)
        seen_families="$seen_families|$family|"
        family_names="$family_names${family_names:+, }$family"
        families=$((families + 1))
        ;;
    esac
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

printf 'Configuration workflows pass: %s (%s scenarios).\n' "$family_names" "$total"
