#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
CONTRACT=${YSH_PUBLIC_CONTRACT:-$SCRIPT_DIR/public-contract.tsv}
TESTS=$SCRIPT_DIR/test.sh

tab=$(printf '\t')
rows=0
failed=0
seen_file=$(mktemp "${TMPDIR:-/tmp}/ysh-public-contract.XXXXXX")
trap 'rm -f "$seen_file"' 0 1 2 3 15

while IFS="$tab" read -r surface capability status role evidence extra; do
    case "$surface" in
    ''|'#'*) continue ;;
    esac
    rows=$((rows + 1))
    if [ -n "${extra:-}" ] || [ -z "$capability" ] || [ -z "$evidence" ]; then
        printf 'Invalid public contract row %s: expected five populated fields\n' "$rows" >&2
        failed=1
        continue
    fi
    case "$status" in
    supported|focused|excluded) ;;
    *)
        printf 'Invalid status for %s/%s: %s\n' "$surface" "$capability" "$status" >&2
        failed=1
        ;;
    esac
    case "$role" in
    core|supporting|compatibility|boundary) ;;
    *)
        printf 'Invalid product role for %s/%s: %s\n' "$surface" "$capability" "$role" >&2
        failed=1
        ;;
    esac
    key=$surface/$capability
    if grep -Fxq "$key" "$seen_file"; then
        printf 'Duplicate public contract capability: %s\n' "$key" >&2
        failed=1
    else
        printf '%s\n' "$key" >> "$seen_file"
    fi
    case "$evidence" in
    test:*)
        test_name=${evidence#test:}
        if ! grep -Fq "$test_name()" "$TESTS"; then
            printf 'Missing behavioral evidence for %s: %s\n' "$key" "$test_name" >&2
            failed=1
        fi
        ;;
    gate:*|manifest:*)
        evidence_file=${evidence#*:}
        if [ ! -s "$PROJECT_DIR/$evidence_file" ]; then
            printf 'Missing evidence file for %s: %s\n' "$key" "$evidence_file" >&2
            failed=1
        fi
        ;;
    *)
        printf 'Unknown evidence kind for %s: %s\n' "$key" "$evidence" >&2
        failed=1
        ;;
    esac
done < "$CONTRACT"

if [ "$failed" -ne 0 ]; then
    exit 1
fi

awk -F '\t' '
    $1 !~ /^#/ && NF {
        roles[$4]++
        statuses[$3]++
        rows++
    }
    END {
        printf "Public contract: %d named capabilities; %d core, %d supporting, %d compatibility, %d boundaries; %d supported, %d focused, %d excluded\n",
            rows, roles["core"], roles["supporting"], roles["compatibility"], roles["boundary"],
            statuses["supported"], statuses["focused"], statuses["excluded"]
    }
' "$CONTRACT"
