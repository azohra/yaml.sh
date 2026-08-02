#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
YSH_BINARY=${YSH_BINARY:-$PROJECT_DIR/ysh}
FUZZ_CASES=${YSH_FUZZ_CASES:-12000}
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
trap 'rm -f "$INPUT" "$ORACLE" "$ROUNDTRIP" "$ACTUAL" "$EXPECTED" "$CANDIDATE" "$CANDIDATE_ORACLE"' 0 1 2 3 15

generate_case() {
    generated_case=$1
    shrink_level=$2
    generated_input=$3
    generated_oracle=$4
    awk -v seed="$generated_case" -v shrink="$shrink_level" -v oracle="$generated_oracle" '
    function truth(value) { return value ? "true" : "false" }
    BEGIN {
        mode = seed % 6
        count = (seed % 7) + 1
        if (shrink >= 1 && count > 3) count = 3
        if (shrink >= 2) { count = 1; mode = 0 }
        enabled = seed % 2
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
    property_mode=$((($1 + FUZZ_SEED) % 5))
    case "$property_mode" in
    0)
        PROPERTY=roundtrip
        QUERY=.
        ;;
    1)
        PROPERTY=query
        case $(((($1 + FUZZ_SEED) / 3) % 4)) in
        0) QUERY='.items[1:3] | map(.name)' ;;
        1) QUERY='.items | map(select(.active) | .score) | add' ;;
        2) QUERY='"\(.meta.label):\(.items | length)"' ;;
        3) QUERY='.items | map(select(.name | test("^item-")) | .name) | length' ;;
        esac
        ;;
    2)
        PROPERTY=mutation
        QUERY='.meta.checked = true | .items |= map(.score += 1)'
        ;;
    3)
        PROPERTY=query
        QUERY='.items | sort_by(.score) | reverse | map(.name) | .[0:3]'
        ;;
    4)
        PROPERTY=query
        QUERY='.items | map(.score) | unique | sort | min'
        ;;
    esac
}

run_property() {
    property_input=$1
    property_oracle=$2
    if ! "$YSH_BINARY" --json . "$property_input" | jq -cS . > "$ACTUAL" 2>/dev/null ||
        ! jq -cS . "$property_oracle" > "$EXPECTED" || ! cmp -s "$ACTUAL" "$EXPECTED"; then
        return 1
    fi
    case "$PROPERTY" in
    roundtrip)
        "$YSH_BINARY" -o yaml . "$property_input" > "$ROUNDTRIP" 2>/dev/null || return 1
        "$YSH_BINARY" --json . "$ROUNDTRIP" | jq -cS . > "$ACTUAL" 2>/dev/null || return 1
        jq -cS . "$property_oracle" > "$EXPECTED"
        cmp -s "$ACTUAL" "$EXPECTED"
        ;;
    query|mutation)
        "$YSH_BINARY" --json "$QUERY" "$property_input" | jq -cS . > "$ACTUAL" 2>/dev/null || return 1
        jq -cS "$QUERY" "$property_oracle" > "$EXPECTED" 2>/dev/null || return 1
        cmp -s "$ACTUAL" "$EXPECTED"
        ;;
    esac
}

preserve_failure() {
    failed_case=$1
    failure_dir=$FAILURE_ROOT/ysh-fuzz-failure-$failed_case
    mkdir -p "$failure_dir"
    cp "$INPUT" "$failure_dir/input.yml"
    cp "$ORACLE" "$failure_dir/oracle.json"
    level=1
    while [ "$level" -le 2 ]; do
        generate_case "$failed_case" "$level" "$CANDIDATE" "$CANDIDATE_ORACLE"
        if ! run_property "$CANDIDATE" "$CANDIDATE_ORACLE"; then
            cp "$CANDIDATE" "$failure_dir/input.yml"
            cp "$CANDIDATE_ORACLE" "$failure_dir/oracle.json"
        fi
        level=$((level + 1))
    done
    printf '%s\n' "YSH_FUZZ_REPLAY=$failed_case YSH_FUZZ_SEED=$FUZZ_SEED ./test/fuzz.sh" > "$failure_dir/replay.sh"
    chmod 755 "$failure_dir/replay.sh"
    printf 'Grammar-guided %s property failed for case %s; minimized replay saved in %s\n' "$PROPERTY" "$failed_case" "$failure_dir" >&2
}

if [ -n "$FUZZ_REPLAY" ]; then
    case "$FUZZ_REPLAY" in
    *[!0-9]*|'') printf '%s\n' 'YSH_FUZZ_REPLAY must be a positive integer.' >&2; exit 2 ;;
    esac
    first_case=$FUZZ_REPLAY
    last_case=$FUZZ_REPLAY
else
    first_case=$FUZZ_SEED
    last_case=$((FUZZ_SEED + FUZZ_CASES - 1))
fi

case_id=$first_case
passed=0
while [ "$case_id" -le "$last_case" ]; do
    generate_case "$case_id" 0 "$INPUT" "$ORACLE"
    property_for_case "$case_id"
    if ! run_property "$INPUT" "$ORACLE"; then
        preserve_failure "$case_id"
        exit 1
    fi
    passed=$((passed + 1))
    case_id=$((case_id + 1))
done

printf 'Grammar-guided YAML properties: %s/%s pass (seed %s)\n' "$passed" "$passed" "$FUZZ_SEED"
