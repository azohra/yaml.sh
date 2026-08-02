#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
SUITE_DIR=${YAML_TEST_SUITE_DIR:-${1:-}}
YSH_BINARY=${YSH_BINARY:-$PROJECT_DIR/ysh}
KNOWN_PASSES=${YAML_CONFORMANCE_PASSES:-$SCRIPT_DIR/conformance-pass.txt}
KNOWN_REJECTIONS=${YAML_REJECTION_PASSES:-$SCRIPT_DIR/rejection-pass.txt}

if [ -z "$SUITE_DIR" ] || [ ! -d "$SUITE_DIR" ]; then
    printf '%s\n' "Set YAML_TEST_SUITE_DIR to the YAML Test Suite data-2022-01-17 checkout." >&2
    exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
    printf '%s\n' "The conformance harness requires jq for semantic JSON comparison." >&2
    exit 2
fi

if [ ! -x "$YSH_BINARY" ]; then
    printf 'YAML.sh executable not found: %s\n' "$YSH_BINARY" >&2
    exit 2
fi

RESULTS_FILE=$(mktemp "${TMPDIR:-/tmp}/ysh-conformance.XXXXXX")
REJECTIONS_FILE=$(mktemp "${TMPDIR:-/tmp}/ysh-rejections.XXXXXX")
trap 'rm -f "$RESULTS_FILE" "$REJECTIONS_FILE"' 0 1 2 3 15

find "$SUITE_DIR" -name in.json -type f | sort | while IFS= read -r expected_file; do
    case_dir=${expected_file%/in.json}
    yaml_file=$case_dir/in.yaml
    case_id=${case_dir#"$SUITE_DIR"/}

    # Some error fixtures include partial event-stream JSON. A document loader
    # must reject those inputs; reproducing a parser's partial AST would be
    # permissive and misleading.
    if [ -f "$case_dir/error" ]; then
        if "$YSH_BINARY" --json '.' "$yaml_file" >/dev/null 2>&1; then
            printf 'mismatch\t%s\n' "$case_id"
        else
            printf 'pass\t%s\n' "$case_id"
        fi
        continue
    fi

    if ! expected=$(jq -cS . "$expected_file" 2>/dev/null); then
        continue
    fi

    document_count=$(jq -s 'length' "$expected_file" 2>/dev/null || printf '0')
    actual=
    document=0
    actual_ok=1
    while [ "$document" -lt "$document_count" ]; do
        if ! document_value=$("$YSH_BINARY" --document "$document" --json '.' "$yaml_file" 2>/dev/null); then
            actual_ok=0
            break
        fi
        if [ -z "$actual" ]; then
            actual=$document_value
        else
            actual=$(printf '%s\n%s' "$actual" "$document_value")
        fi
        document=$((document + 1))
    done
    if [ "$document_count" -eq 0 ]; then
        actual=$("$YSH_BINARY" --json '.' "$yaml_file" 2>/dev/null || true)
    fi

    if [ "$actual_ok" -eq 1 ]; then
        normalized=$(printf '%s\n' "$actual" | jq -cS . 2>/dev/null || printf '__invalid_json__')
        if [ "$normalized" = "$expected" ]; then
            result_kind=pass
        else
            result_kind=mismatch
        fi
    else
        result_kind=reject
    fi

    printf '%s\t%s\n' "$result_kind" "$case_id"
done > "$RESULTS_FILE"

pass_count=$(awk -F '\t' '$1 == "pass" {count++} END {print count + 0}' "$RESULTS_FILE")
mismatch_count=$(awk -F '\t' '$1 == "mismatch" {count++} END {print count + 0}' "$RESULTS_FILE")
reject_count=$(awk -F '\t' '$1 == "reject" {count++} END {print count + 0}' "$RESULTS_FILE")
total_count=$((pass_count + mismatch_count + reject_count))

printf 'YAML Test Suite semantic load results: %s/%s pass, %s mismatch, %s reject\n' \
    "$pass_count" "$total_count" "$mismatch_count" "$reject_count"

if [ "${YAML_CONFORMANCE_VERBOSE:-0}" = 1 ]; then
    awk -F '\t' '$1 != "pass" {print $1 "\t" $2}' "$RESULTS_FILE"
elif [ "${YAML_CONFORMANCE_VERBOSE:-0}" = passes ]; then
    awk -F '\t' '$1 == "pass" {print $2}' "$RESULTS_FILE"
fi

regressions=0
while IFS= read -r case_id; do
    case "$case_id" in
    ''|'#'*) continue ;;
    esac
    if ! awk -F '\t' -v wanted="$case_id" '$1 == "pass" && $2 == wanted {found=1} END {exit !found}' "$RESULTS_FILE"; then
        printf 'Conformance regression: previously passing case %s no longer passes\n' "$case_id" >&2
        regressions=$((regressions + 1))
    fi
done < "$KNOWN_PASSES"

if [ "$regressions" -ne 0 ]; then
    exit 1
fi

find "$SUITE_DIR" -name error -type f | sort | while IFS= read -r error_file; do
    case_dir=${error_file%/error}
    case_id=${case_dir#"$SUITE_DIR"/}
    if [ -f "$case_dir/in.json" ]; then
        continue
    fi
    if "$YSH_BINARY" --json '.' "$case_dir/in.yaml" >/dev/null 2>&1; then
        printf 'accept\t%s\n' "$case_id"
    else
        printf 'reject\t%s\n' "$case_id"
    fi
done > "$REJECTIONS_FILE"

reject_count=$(awk -F '\t' '$1 == "reject" {count++} END {print count + 0}' "$REJECTIONS_FILE")
accept_count=$(awk -F '\t' '$1 == "accept" {count++} END {print count + 0}' "$REJECTIONS_FILE")
rejection_total=$((reject_count + accept_count))
printf 'YAML Test Suite strict rejection results: %s/%s reject invalid input\n' "$reject_count" "$rejection_total"

rejection_regressions=0
while IFS= read -r case_id; do
    case "$case_id" in
    ''|'#'*) continue ;;
    esac
    if ! awk -F '\t' -v wanted="$case_id" '$1 == "reject" && $2 == wanted {found=1} END {exit !found}' "$REJECTIONS_FILE"; then
        printf 'Rejection regression: invalid case %s is now accepted\n' "$case_id" >&2
        rejection_regressions=$((rejection_regressions + 1))
    fi
done < "$KNOWN_REJECTIONS"

if [ "$rejection_regressions" -ne 0 ]; then
    exit 1
fi
