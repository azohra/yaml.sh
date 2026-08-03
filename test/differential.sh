#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
CORPUS=${YQ_DIFFERENTIAL_CORPUS:-$SCRIPT_DIR/yq-corpus.tsv}
YSH_BINARY=${YSH_BINARY:-$PROJECT_DIR/ysh}
YQ_BINARY=${YQ_BINARY:-yq}
YSH_DIFFERENTIAL_CONFIG='{base: 100}'
YSH_DIFFERENTIAL_WORD=portable
export YSH_DIFFERENTIAL_CONFIG YSH_DIFFERENTIAL_WORD

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
RESULTS=$(mktemp "${TMPDIR:-/tmp}/ysh-differential-results.XXXXXX")
trap 'rm -f "$YSH_OUTPUT" "$YQ_OUTPUT" "$YSH_RAW" "$YQ_RAW" "$RESULTS"' 0 1 2 3 15

total=0
passed=0
mismatched=0
tab=$(printf '\t')
while IFS="$tab" read -r family fixture query; do
    case "$family" in
    ''|'#'*) continue ;;
    esac
    total=$((total + 1))
    input=$SCRIPT_DIR/$fixture
    oracle_query="select(document_index == 0) | ($query)"

    if ! "$YQ_BINARY" --yaml-fix-merge-anchor-to-spec -o=json -I=0 "$oracle_query" "$input" > "$YQ_RAW" 2>/dev/null ||
        ! jq -cS . "$YQ_RAW" > "$YQ_OUTPUT"; then
        printf 'yq failed differential case %s [%s]: %s\n' "$total" "$family" "$query" >&2
        exit 1
    fi
    if ! "$YSH_BINARY" --json "$query" "$input" > "$YSH_RAW" 2>/dev/null ||
        ! jq -cS . "$YSH_RAW" > "$YSH_OUTPUT"; then
        printf 'YAML.sh failed differential case %s [%s] (%s): %s\n' "$total" "$family" "$fixture" "$query" >&2
        mismatched=$((mismatched + 1))
        printf '%s\tfail\n' "$family" >> "$RESULTS"
        continue
    fi
    if ! cmp -s "$YSH_OUTPUT" "$YQ_OUTPUT"; then
        printf 'Differential mismatch %s [%s] (%s): %s\n' "$total" "$family" "$fixture" "$query" >&2
        mismatched=$((mismatched + 1))
        printf '%s\tfail\n' "$family" >> "$RESULTS"
        continue
    fi
    passed=$((passed + 1))
    printf '%s\tpass\n' "$family" >> "$RESULTS"
done < "$CORPUS"

printf 'yq v4.53.3 differential results: %s/%s pass\n' "$passed" "$total"
awk -F '\t' '
    !seen[$1]++ { order[++families] = $1 }
    { total[$1]++; if ($2 == "pass") passed[$1]++ }
    END {
        for (i = 1; i <= families; i++) {
            family = order[i]
            printf "  %-14s %d/%d\n", family, passed[family], total[family]
        }
    }
' "$RESULTS"

workflow_total=0
workflow_passed=0
while IFS="$tab" read -r family id fixture query expected; do
    case "$family" in
    ''|'#'*) continue ;;
    esac
    workflow_total=$((workflow_total + 1))
    input=$SCRIPT_DIR/workflows/$fixture
    if ! "$YQ_BINARY" --yaml-fix-merge-anchor-to-spec -o=json -I=0 "$query" "$input" > "$YQ_RAW" 2>/dev/null ||
        ! jq -cS . "$YQ_RAW" > "$YQ_OUTPUT"; then
        printf 'yq failed real-world workflow %s/%s: %s\n' "$family" "$id" "$query" >&2
        exit 1
    fi
    if ! "$YSH_BINARY" --json "$query" "$input" > "$YSH_RAW" 2>/dev/null ||
        ! jq -cS . "$YSH_RAW" > "$YSH_OUTPUT"; then
        printf 'YAML.sh failed real-world workflow %s/%s: %s\n' "$family" "$id" "$query" >&2
        exit 1
    fi
    if [ "$(cat "$YSH_RAW")" != "$expected" ]; then
        printf 'Committed workflow expectation drifted for %s/%s\n' "$family" "$id" >&2
        exit 1
    fi
    if ! cmp -s "$YSH_OUTPUT" "$YQ_OUTPUT"; then
        printf 'Real-world differential mismatch %s/%s: %s\n' "$family" "$id" "$query" >&2
        exit 1
    fi
    workflow_passed=$((workflow_passed + 1))
done < "$SCRIPT_DIR/workflows.tsv"
printf 'Real-world workflows matching yq v4.53.3: %s/%s\n' "$workflow_passed" "$workflow_total"
if [ "$workflow_total" -eq 0 ]; then
    printf 'Workflow differential has no named scenarios\n' >&2
    exit 1
fi

eval_all_total=0
eval_all_passed=0
while IFS= read -r query; do
    [ -n "$query" ] || continue
    eval_all_total=$((eval_all_total + 1))
    if ! "$YQ_BINARY" --yaml-fix-merge-anchor-to-spec eval-all -o=json -I=0 "$query" \
            "$SCRIPT_DIR/expressions.yml" "$SCRIPT_DIR/test.yml" > "$YQ_RAW" 2>/dev/null ||
        ! jq -cS . "$YQ_RAW" > "$YQ_OUTPUT"; then
        printf 'yq failed eval-all differential case %s: %s\n' "$eval_all_total" "$query" >&2
        exit 1
    fi
    if ! "$YSH_BINARY" eval-all --json "$query" \
            "$SCRIPT_DIR/expressions.yml" "$SCRIPT_DIR/test.yml" > "$YSH_RAW" 2>/dev/null ||
        ! jq -cS . "$YSH_RAW" > "$YSH_OUTPUT"; then
        printf 'YAML.sh failed eval-all differential case %s: %s\n' "$eval_all_total" "$query" >&2
        exit 1
    fi
    if ! cmp -s "$YSH_OUTPUT" "$YQ_OUTPUT"; then
        printf 'Eval-all differential mismatch %s: %s\n' "$eval_all_total" "$query" >&2
        exit 1
    fi
    eval_all_passed=$((eval_all_passed + 1))
done <<'EOF'
[.]
[filename, fileIndex, documentIndex]
select(fileIndex == 0), select(fileIndex == 1)
[select(fileIndex == 0), select(fileIndex == 1)]
select(fileIndex == 0) * select(fileIndex == 1)
select(fileIndex == 0) | keys
select(fileIndex == 1) | sort_keys(.)
select(fileIndex == 1) | path
. as $document ireduce ({}; . * $document)
EOF
printf 'yq v4.53.3 eval-all results: %s/%s pass\n' "$eval_all_passed" "$eval_all_total"
if [ "$total" -eq 0 ]; then
    printf 'Differential corpus has no named cases\n' >&2
    exit 1
fi
if [ "$mismatched" -ne 0 ] || [ "$passed" -ne "$total" ]; then
    printf 'Every documented differential case must match; found %s mismatches\n' "$mismatched" >&2
    exit 1
fi
