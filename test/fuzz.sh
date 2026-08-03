#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
YSH_BINARY=${YSH_BINARY:-$PROJECT_DIR/ysh}
FUZZ_MATRICES=${YSH_FUZZ_MATRICES:-1}
FUZZ_SEED=${YSH_FUZZ_SEED:-1}
FUZZ_REPLAY=${YSH_FUZZ_REPLAY:-}
FAILURE_ROOT=${YSH_FUZZ_FAILURE_DIR:-${TMPDIR:-/tmp}}

if ! command -v jq >/dev/null 2>&1; then
    printf '%s\n' "The fuzz harness requires jq." >&2
    exit 2
fi

INPUT=$(mktemp "${TMPDIR:-/tmp}/ysh-fuzz-input.XXXXXX")
ORACLE=$(mktemp "${TMPDIR:-/tmp}/ysh-fuzz-oracle.XXXXXX")
ROUNDTRIP=$(mktemp "${TMPDIR:-/tmp}/ysh-fuzz-roundtrip.XXXXXX")
ACTUAL=$(mktemp "${TMPDIR:-/tmp}/ysh-fuzz-actual.XXXXXX")
EXPECTED=$(mktemp "${TMPDIR:-/tmp}/ysh-fuzz-expected.XXXXXX")
CANDIDATE=$(mktemp "${TMPDIR:-/tmp}/ysh-fuzz-candidate.XXXXXX")
CANDIDATE_ORACLE=$(mktemp "${TMPDIR:-/tmp}/ysh-fuzz-candidate-oracle.XXXXXX")
BEFORE=$(mktemp "${TMPDIR:-/tmp}/ysh-fuzz-before.XXXXXX")
PREVIEW=$(mktemp "${TMPDIR:-/tmp}/ysh-fuzz-preview.XXXXXX")
EDIT=$(mktemp "${TMPDIR:-/tmp}/ysh-fuzz-edit.XXXXXX")
trap 'rm -f "$INPUT" "$ORACLE" "$ROUNDTRIP" "$ACTUAL" "$EXPECTED" "$CANDIDATE" "$CANDIDATE_ORACLE" "$BEFORE" "$PREVIEW" "$EDIT"' 0 1 2 3 15

property_fail() {
    PROPERTY_FAILURE=$1
}

generate_case() {
    generated_case=$1
    shrink_level=$2
    generated_input=$3
    generated_oracle=$4
    generated_mode=$5
    generated_count=$6
    generated_enabled=$7
    awk -v seed="$generated_case" -v shrink="$shrink_level" -v oracle="$generated_oracle" \
        -v mode="$generated_mode" -v count="$generated_count" -v enabled="$generated_enabled" '
    function truth(value) { return value ? "true" : "false" }
    BEGIN {
        if (shrink >= 1 && count > 3) count = 3
        if (shrink >= 2) { count = 1; mode = 0 }
        label = "case " seed

        if (mode == 3) {
            print "%YAML 1.2"
            print "---"
        }
        if (mode == 1) {
            printf "meta: {id: %d, enabled: %s, label: \"%s\"}\n", seed, truth(enabled), label
        } else {
            print "meta:"
            print "  id: " seed
            print "  enabled: " truth(enabled)
            if (mode == 2) {
                print "  label: &case_label \"" label "\""
                print "  copy: *case_label"
            } else if (mode == 4) {
                print "  label: '\''" label "'\''"
            } else {
                print "  label: \"" label "\""
            }
        }
        print "values: [" seed ", " (seed + 1) ", null, \"v" seed "\"]"

        if (mode == 1) {
            printf "items: ["
            for (i = 1; i <= count; i++) {
                if (i > 1) printf ", "
                score = (seed * 17 + i * 13) % 1000
                active = (seed + i) % 3
                printf "{name: item-%d-%d, score: %d, active: %s}", seed, i, score, truth(active)
            }
            print "]"
        } else {
            print "items:"
            for (i = 1; i <= count; i++) {
                score = (seed * 17 + i * 13) % 1000
                active = (seed + i) % 3
                prefix = mode == 5 ? "-" : "  -"
                print prefix " name: item-" seed "-" i
                print (mode == 5 ? "  " : "    ") "score: " score
                print (mode == 5 ? "  " : "    ") "active: " truth(active)
            }
        }
        if (mode == 3) {
            print "message: |-"
            print "  generated case " seed
            print "  line " (seed * 3)
        } else {
            print "message: \"generated case " seed "\\nline " (seed * 3) "\""
        }

        printf "{\"meta\":{\"id\":%d,\"enabled\":%s,\"label\":\"%s\"", seed, truth(enabled), label > oracle
        if (mode == 2) printf ",\"copy\":\"%s\"", label > oracle
        printf "},\"values\":[%d,%d,null,\"v%d\"],\"items\":[", seed, seed + 1, seed > oracle
        for (i = 1; i <= count; i++) {
            if (i > 1) printf "," > oracle
            score = (seed * 17 + i * 13) % 1000
            active = (seed + i) % 3
            printf "{\"name\":\"item-%d-%d\",\"score\":%d,\"active\":%s}", seed, i, score, truth(active) > oracle
        }
        printf "],\"message\":\"generated case %d\\nline %d\"}\n", seed, seed * 3 > oracle
        close(oracle)
    }
    ' > "$generated_input"
}

property_for_case() {
    property_mode=$1
    case "$property_mode" in
    0)
        PROPERTY=roundtrip
        QUERY=.
        ;;
    1)
        PROPERTY=query
        QUERY='.items[1:3] | map(.name)'
        ;;
    2)
        PROPERTY=query
        QUERY='.items | map(select(.active) | .score) | add'
        ;;
    3)
        PROPERTY=query
        QUERY='"\(.meta.label):\(.items | length)"'
        ;;
    4)
        PROPERTY=query
        QUERY='.items | map(select(.name | test("^item-")) | .name) | length'
        ;;
    5)
        PROPERTY=mutation
        QUERY='.meta.checked = true | .items |= map(.score += 1)'
        ;;
    6)
        PROPERTY=query
        QUERY='.items | sort_by(.score) | reverse | map(.name) | .[0:3]'
        ;;
    7)
        PROPERTY=query
        QUERY='.items | map(.score) | unique | sort | min'
        ;;
    esac
}

run_property() {
    property_input=$1
    property_oracle=$2
    PROPERTY_FAILURE=
    "$YSH_BINARY" --json . "$property_input" | jq -cS . > "$ACTUAL" 2>/dev/null || { property_fail "source parse or canonicalization failed"; return 1; }
    jq -cS . "$property_oracle" > "$EXPECTED" || { property_fail "oracle canonicalization failed"; return 1; }
    cmp -s "$ACTUAL" "$EXPECTED" || { property_fail "parsed source differs from oracle"; return 1; }
    case "$PROPERTY" in
    roundtrip)
        "$YSH_BINARY" -o yaml . "$property_input" > "$ROUNDTRIP" 2>/dev/null || { property_fail "YAML round trip emission failed"; return 1; }
        "$YSH_BINARY" --json . "$ROUNDTRIP" | jq -cS . > "$ACTUAL" 2>/dev/null || { property_fail "round-trip parse failed"; return 1; }
        jq -cS . "$property_oracle" > "$EXPECTED" || { property_fail "round-trip oracle failed"; return 1; }
        cmp -s "$ACTUAL" "$EXPECTED" || { property_fail "round-trip value differs from oracle"; return 1; }
        ;;
    query)
        "$YSH_BINARY" --json "$QUERY" "$property_input" | jq -cS . > "$ACTUAL" 2>/dev/null || { property_fail "query execution failed"; return 1; }
        jq -cS "$QUERY" "$property_oracle" > "$EXPECTED" 2>/dev/null || { property_fail "query oracle failed"; return 1; }
        cmp -s "$ACTUAL" "$EXPECTED" || { property_fail "query result differs from oracle"; return 1; }
        ;;
    mutation)
        cp "$property_input" "$EDIT"
        cp "$EDIT" "$BEFORE"
        if "$YSH_BINARY" --diff "$QUERY" "$EDIT" > "$PREVIEW" 2>/dev/null; then
            preview_status=0
        else
            preview_status=$?
        fi
        [ "$preview_status" -eq 1 ] || { property_fail "diff returned $preview_status instead of drift"; return 1; }
        cmp -s "$EDIT" "$BEFORE" || { property_fail "diff modified its input"; return 1; }
        grep -q '^--- ' "$PREVIEW" || { property_fail "diff returned no file header"; return 1; }
        "$YSH_BINARY" -i "$QUERY" "$EDIT" >/dev/null 2>&1 || { property_fail "in-place mutation failed"; return 1; }
        "$YSH_BINARY" --json . "$EDIT" | jq -cS . > "$ACTUAL" 2>/dev/null || { property_fail "mutated YAML did not parse"; return 1; }
        jq -cS "$QUERY" "$property_oracle" > "$EXPECTED" 2>/dev/null || { property_fail "mutation oracle failed"; return 1; }
        cmp -s "$ACTUAL" "$EXPECTED" || { property_fail "committed mutation differs from oracle"; return 1; }
        ;;
    esac
}

preserve_failure() {
    failed_case=$1
    failure_reason=$PROPERTY_FAILURE
    failure_dir=$FAILURE_ROOT/ysh-fuzz-failure-$failed_case
    mkdir -p "$failure_dir"
    cp "$INPUT" "$failure_dir/input.yml"
    cp "$INPUT" "$failure_dir/input-original.yml"
    cp "$ORACLE" "$failure_dir/oracle.json"
    cp "$EDIT" "$failure_dir/committed.yml"
    cp "$PREVIEW" "$failure_dir/preview.diff"
    cp "$ACTUAL" "$failure_dir/actual.json"
    cp "$EXPECTED" "$failure_dir/expected.json"
    level=1
    while [ "$level" -le 2 ]; do
        generate_case "$failed_case" "$level" "$CANDIDATE" "$CANDIDATE_ORACLE" "$CASE_MODE" "$CASE_COUNT" "$CASE_ENABLED"
        if ! run_property "$CANDIDATE" "$CANDIDATE_ORACLE"; then
            cp "$CANDIDATE" "$failure_dir/input.yml"
            cp "$CANDIDATE_ORACLE" "$failure_dir/oracle.json"
        fi
        level=$((level + 1))
    done
    printf '%s\n' "YSH_FUZZ_REPLAY=$failed_case YSH_FUZZ_SEED=$FUZZ_SEED ./test/fuzz.sh" > "$failure_dir/replay.sh"
    chmod 755 "$failure_dir/replay.sh"
    printf 'Grammar-guided %s property failed for case %s: %s; minimized replay saved in %s\n' \
        "$PROPERTY" "$failed_case" "$failure_reason" "$failure_dir" >&2
    printf '%s\n' '--- generated input' >&2
    sed -n '1,80p' "$failure_dir/input-original.yml" >&2
    printf '%s\n' '--- committed YAML' >&2
    sed -n '1,80p' "$failure_dir/committed.yml" >&2
    printf '%s\n' '--- actual canonical JSON' >&2
    sed -n '1,10p' "$failure_dir/actual.json" >&2
    printf '%s\n' '--- expected canonical JSON' >&2
    sed -n '1,10p' "$failure_dir/expected.json" >&2
}

if [ -n "$FUZZ_REPLAY" ]; then
    case "$FUZZ_REPLAY" in
    *[!0-9]*|'') printf '%s\n' 'YSH_FUZZ_REPLAY must be a positive integer.' >&2; exit 2 ;;
    esac
    first_case=$FUZZ_REPLAY
    last_case=$FUZZ_REPLAY
else
    case "$FUZZ_MATRICES" in
    *[!0-9]*|' '|''|0) printf '%s\n' 'YSH_FUZZ_MATRICES must be a positive integer.' >&2; exit 2 ;;
    esac
    first_case=$FUZZ_SEED
    last_case=$((FUZZ_SEED + FUZZ_MATRICES * 672 - 1))
fi

case_id=$first_case
passed=0
while [ "$case_id" -le "$last_case" ]; do
    case_offset=$((case_id - FUZZ_SEED))
    if [ "$case_offset" -lt 0 ]; then
        printf '%s\n' 'YSH_FUZZ_REPLAY must not be lower than YSH_FUZZ_SEED.' >&2
        exit 2
    fi
    matrix_case=$((case_offset % 672))
    CASE_MODE=$((matrix_case % 6))
    matrix_case=$((matrix_case / 6))
    CASE_COUNT=$((matrix_case % 7 + 1))
    matrix_case=$((matrix_case / 7))
    CASE_ENABLED=$((matrix_case % 2))
    matrix_case=$((matrix_case / 2))
    CASE_PROPERTY=$((matrix_case % 8))
    generate_case "$case_id" 0 "$INPUT" "$ORACLE" "$CASE_MODE" "$CASE_COUNT" "$CASE_ENABLED"
    property_for_case "$CASE_PROPERTY"
    if ! run_property "$INPUT" "$ORACLE"; then
        preserve_failure "$case_id"
        exit 1
    fi
    passed=$((passed + 1))
    case_id=$((case_id + 1))
done

printf 'Grammar/property matrix: %s cases pass — 6 layouts × 7 sizes × 2 states × 8 properties; %s matrix pass(es), seed %s\n' \
    "$passed" "$FUZZ_MATRICES" "$FUZZ_SEED"
