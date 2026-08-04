#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
YSH_BINARY=${YSH_BINARY:-$PROJECT_DIR/ysh}

fixture=${JSON_PATCH_TEST_FILE:-}
if [ -z "$fixture" ] || [ ! -f "$fixture" ]; then
    printf '%s\n' 'Set JSON_PATCH_TEST_FILE to json-patch/json-patch-tests tests.json.' >&2
    exit 2
fi

cases=$(mktemp "${TMPDIR:-/tmp}/ysh-json-patch-cases.XXXXXX")
expected_file=$(mktemp "${TMPDIR:-/tmp}/ysh-json-patch-expected.XXXXXX")
actual_file=$(mktemp "${TMPDIR:-/tmp}/ysh-json-patch-actual.XXXXXX")
trap 'rm -f "$cases" "$expected_file" "$actual_file"' 0 1 2 3 15

jq -c '.[] | select(has("doc") and has("patch")) | select(.disabled != true)' "$fixture" > "$cases"

passed=0
while IFS= read -r case; do
    if printf '%s\n' "$case" | "$YSH_BINARY" -p json --json '.doc | apply_patch(root.patch)' > "$actual_file" 2>/dev/null; then
        if printf '%s\n' "$case" | jq -e 'has("error")' >/dev/null; then
            printf 'JSON Patch fixture expected failure but succeeded:\n%s\n' "$case" >&2
            exit 1
        fi
        printf '%s\n' "$case" | jq -S '.expected' > "$expected_file"
        jq -S '.' "$actual_file" > "$actual_file.sorted"
        if ! cmp -s "$expected_file" "$actual_file.sorted"; then
            printf 'JSON Patch fixture mismatch:\n%s\n' "$case" >&2
            rm -f "$actual_file.sorted"
            exit 1
        fi
        rm -f "$actual_file.sorted"
    elif ! printf '%s\n' "$case" | jq -e 'has("error")' >/dev/null; then
        printf 'JSON Patch fixture unexpectedly failed:\n%s\n' "$case" >&2
        exit 1
    fi
    passed=$((passed + 1))
done < "$cases"

printf 'RFC 6902 community corpus: %d assertions passed\n' "$passed"
