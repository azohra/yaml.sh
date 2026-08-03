#!/bin/sh
set -eu

suite=${JSON_SCHEMA_TEST_SUITE_DIR:-}
if [ -z "$suite" ] || [ ! -d "$suite/tests/draft2020-12" ]; then
    printf '%s\n' 'Set JSON_SCHEMA_TEST_SUITE_DIR to the pinned JSON-Schema-Test-Suite checkout.' >&2
    exit 2
fi

cases=$(mktemp "${TMPDIR:-/tmp}/ysh-schema-cases.XXXXXX")
trap 'rm -f "$cases"' 0 1 2 3 15

for fixture in \
    additionalProperties allOf anyOf const contains dependentRequired dependentSchemas enum \
    exclusiveMaximum exclusiveMinimum if-then-else items maxItems maxLength maxProperties maximum \
    minItems minLength minProperties minimum multipleOf not oneOf pattern patternProperties \
    prefixItems properties propertyNames required type uniqueItems; do
    jq -c '.[] | .description as $group | .schema as $schema | .tests[] | {group:$group,test:.description,schema:$schema,data:.data,valid:.valid} | select((tojson | contains("\\u0000")) | not) | select((.schema | tojson | contains("unevaluated")) | not) | select(([.schema | .. | objects | .pattern? // empty] | all(contains("\\") | not)))' \
        "$suite/tests/draft2020-12/$fixture.json" >> "$cases"
done

count=0
while IFS= read -r case; do
    expected=$(printf '%s\n' "$case" | jq -r '.valid')
    if ! actual=$(printf '%s\n' "$case" | ./ysh -p json --json '.data | schema_valid(root.schema)'); then
        printf 'JSON Schema fixture could not be evaluated:\n%s\n' "$case" >&2
        exit 1
    fi
    if [ "$actual" != "$expected" ]; then
        printf 'JSON Schema conformance mismatch: expected %s, got %s\n%s\n' "$expected" "$actual" "$case" >&2
        exit 1
    fi
    count=$((count + 1))
done < "$cases"

printf 'JSON Schema 2020-12 focused profile: %d official assertions passed\n' "$count"
