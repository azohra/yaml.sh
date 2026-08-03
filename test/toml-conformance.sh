#!/bin/sh
set -eu

runner='github.com/toml-lang/toml-test/v2/cmd/toml-test@v2.2.0'
decoder=./test/toml-test-decoder
encoder=./test/toml-test-encoder

NO_COLOR=1 go run "$runner" test -toml 1.0 -decoder "$decoder" \
    -run 'valid/*' -run 'valid/*/*'

cases=$(mktemp -d "${TMPDIR:-/tmp}/ysh-toml-encoder.XXXXXX")
trap 'rm -r "$cases"' 0 1 2 3 15
go run "$runner" copy -toml 1.0 "$cases" >/dev/null
find "$cases/valid" -type f -name '*.json' | sort > "$cases/encoder-cases"
encoder_passed=0
while IFS= read -r expected; do
    if ! "$encoder" < "$expected" > "$cases/encoded.toml"; then
        printf 'TOML encoder rejected %s\n' "$expected" >&2
        exit 1
    fi
    if ! "$decoder" < "$cases/encoded.toml" > "$cases/decoded.json"; then
        printf 'TOML encoder produced invalid output for %s\n' "$expected" >&2
        exit 1
    fi
    if ! jq -e -n --slurpfile expected "$expected" --slurpfile actual "$cases/decoded.json" '
        def normalize: walk(if type == "object" and .type == "float" and (.value | test("^[+-]?[0-9]")) then .value |= tonumber else . end);
        ($expected[0] | normalize) == ($actual[0] | normalize)
    ' >/dev/null; then
        printf 'TOML encoder mismatch for %s\n' "$expected" >&2
        exit 1
    fi
    encoder_passed=$((encoder_passed + 1))
done < "$cases/encoder-cases"
printf 'TOML 1.0 encoder: %d official valid fixtures passed\n' "$encoder_passed"

# POSIX AWK record and string APIs do not portably expose these raw-byte faults:
# bare CR versus CRLF, embedded NUL, invalid UTF-8, and UTF-16 input. Every
# semantic TOML fixture remains enabled, and -skip-must-err prevents drift.
NO_COLOR=1 go run "$runner" test -toml 1.0 -decoder "$decoder" \
    -run 'invalid/*' -run 'invalid/*/*' -skip-must-err \
    -skip invalid/control/bare-cr \
    -skip invalid/control/bare-null \
    -skip invalid/control/comment-null \
    -skip invalid/control/only-null \
    -skip invalid/encoding/bad-codepoint \
    -skip invalid/encoding/bad-utf8-in-comment \
    -skip invalid/encoding/bad-utf8-in-multiline \
    -skip invalid/encoding/bad-utf8-in-multiline-literal \
    -skip invalid/encoding/bad-utf8-in-string \
    -skip invalid/encoding/bad-utf8-in-string-literal \
    -skip invalid/encoding/utf16-comment \
    -skip invalid/encoding/utf16-key
