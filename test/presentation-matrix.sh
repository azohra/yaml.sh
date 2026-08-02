#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
YSH_BINARY=${YSH_BINARY:-$PROJECT_DIR/ysh}
PRESENTATION_PASSES=${YSH_PRESENTATION_PASSES:-1}
PRESENTATION_REPLAY=${YSH_PRESENTATION_REPLAY:-}
FAILURE_ROOT=${YSH_PRESENTATION_FAILURE_DIR:-${TMPDIR:-/tmp}}

INPUT=$(mktemp "${TMPDIR:-/tmp}/ysh-presentation-input.XXXXXX")
EXPECTED=$(mktemp "${TMPDIR:-/tmp}/ysh-presentation-expected.XXXXXX")
trap 'rm -f "$INPUT" "$EXPECTED"' 0 1 2 3 15

generate_case() {
    generated_case=$1
    generated_mode=$2
    generated_variant=$3
    awk -v seed="$generated_case" -v mode="$generated_mode" -v variant="$generated_variant" -v expected="$EXPECTED" '
    function scalar(value, mode) {
        if (mode == 0) return "\"" value "\""
        if (mode == 1) return sprintf("%c%s%c", 39, value, 39)
        return value
    }
    BEGIN {
        retries = variant == 0 ? 1 : (variant == 1 ? 5 : 9)
        owner = "team " seed
        first = "one-" seed
        second = "two-" seed
        name = scalar("api", mode)
        changed_name = scalar("worker", mode)

        print "%YAML 1.2"
        print "%TAG !e! tag:example.com,2026:"
        print "---"
        print "# deployment case " seed
        print "defaults: &defaults {retries: " retries ", mode: safe} # flow stays " seed
        print "service: !e!app"
        print "  name: " name "       # public name " seed
        print "  owner: '\''" owner "'\''"
        print "  notes: |-"
        print "    keep case " seed
        print "    exactly"
        print "  inherited: *defaults"
        print "  obsolete: remove-me # delete " seed
        print "items: # order " seed
        print "  # first item " seed
        print "  - &first \"" first "\""
        print "  # second item " seed
        print "  - !e!item '\''" second "'\''"
        print "footer: kept # tail " seed

        print "%YAML 1.2" > expected
        print "%TAG !e! tag:example.com,2026:" > expected
        print "---" > expected
        print "# deployment case " seed > expected
        print "defaults: &defaults {retries: " retries ", mode: safe} # flow stays " seed > expected
        print "service: !e!app" > expected
        print "  name: " changed_name "       # public name " seed > expected
        print "  owner: '\''" owner "'\''" > expected
        print "  notes: |-" > expected
        print "    keep case " seed > expected
        print "    exactly" > expected
        print "  inherited: *defaults" > expected
        print "  region: \"west\"" > expected
        print "items: # order " seed > expected
        print "  # second item " seed > expected
        print "  - !e!item '\''" second "'\''" > expected
        print "  # first item " seed > expected
        print "  - &first \"uno\"" > expected
        print "footer: kept # tail " seed > expected
        close(expected)
    }
    ' > "$INPUT"
}

if [ -n "$PRESENTATION_REPLAY" ]; then
    case "$PRESENTATION_REPLAY" in
    *[!0-9]*|'') printf '%s\n' 'YSH_PRESENTATION_REPLAY must be a positive integer.' >&2; exit 2 ;;
    esac
    first_case=$PRESENTATION_REPLAY
    last_case=$PRESENTATION_REPLAY
else
    case "$PRESENTATION_PASSES" in
    *[!0-9]*|''|0) printf '%s\n' 'YSH_PRESENTATION_PASSES must be a positive integer.' >&2; exit 2 ;;
    esac
    first_case=1
    last_case=$((PRESENTATION_PASSES * 9))
fi

case_id=$first_case
passed=0
while [ "$case_id" -le "$last_case" ]; do
    matrix_case=$(((case_id - 1) % 9))
    case_mode=$((matrix_case % 3))
    case_variant=$((matrix_case / 3))
    generate_case "$case_id" "$case_mode" "$case_variant"
    if ! "$YSH_BINARY" -i 'del(.service.obsolete) | .items[0] = "uno" | .items |= reverse | .service.name = "worker" | .service.region = "west"' "$INPUT" >/dev/null 2>&1 ||
        ! cmp -s "$INPUT" "$EXPECTED"; then
        failure_dir=$FAILURE_ROOT/ysh-presentation-failure-$case_id
        mkdir -p "$failure_dir"
        cp "$INPUT" "$failure_dir/actual.yml"
        cp "$EXPECTED" "$failure_dir/expected.yml"
        printf '%s\n' "YSH_PRESENTATION_REPLAY=$case_id ./test/presentation-matrix.sh" > "$failure_dir/replay.sh"
        chmod 755 "$failure_dir/replay.sh"
        printf 'Presentation mutation case %s failed; replay saved in %s\n' "$case_id" "$failure_dir" >&2
        exit 1
    fi
    passed=$((passed + 1))
    case_id=$((case_id + 1))
done

printf 'Presentation mutation matrix: %s cases pass — 3 scalar styles × 3 value/comment variants\n' "$passed"
