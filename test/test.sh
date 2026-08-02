#!/bin/sh

testVersion() {
    assertEquals "v1.7.0" "$(./ysh --version)"
}

testHelp() {
    result=$(./ysh --help)
    assertEquals 0 $?
    assertContains "$result" "yq-style paths"
    assertContains "$result" "events"
}

testYqStyleFileQuery() {
    assertEquals "value" "$(./ysh ".key_value.key" test/test.yml)"
    assertEquals "three" "$(./ysh ".object_list.list[2].name" test/test.yml)"
}

testStandardInputQuery() {
    assertEquals "42" "$(printf "%s\n" "answer: 42" | ./ysh ".answer")"
    assertEquals "value" "$(printf "%s\n" "key: value" | ./ysh ".key")"
}

testFileOnlyEmitsRootAsJson() {
    result=$(./ysh test/test.yml)
    assertContains "$result" '"key_value":{"key":"value"}'
    assertContains "$result" '"simple_list":{"list":["one","two","three","four"]}'
}

testFileFirstCompatibility() {
    assertEquals "value" "$(./ysh test/test.yml ".key_value.key")"
}

testJsonScalarTypes() {
    assertEquals '"text"' "$(./ysh ".types.string" test/advanced.yml --json)"
    assertEquals '"12"' "$(./ysh ".types.quoted_number" test/advanced.yml --json)"
    assertEquals "null" "$(./ysh ".types.null" test/advanced.yml --json)"
    assertEquals "true" "$(./ysh ".types.boolean" test/advanced.yml --json)"
    assertEquals "42" "$(./ysh ".types.binary" test/advanced.yml --json)"
    assertEquals "15" "$(./ysh ".types.octal" test/advanced.yml --json)"
    assertEquals "42" "$(./ysh ".types.hex" test/advanced.yml --json)"
    assertEquals "5.0" "$(./ysh ".types.trailing_float" test/advanced.yml --json)"
    assertEquals '"2026-08-02"' "$(./ysh ".types.timestamp" test/advanced.yml --json)"
}

testYqStyleOutputFlags() {
    assertEquals '{"name":"two","value":2}' "$(./ysh -o=json ".object_list.list[1]" test/test.yml)"
    assertEquals "value" "$(./ysh --output-format=raw ".key_value.key" test/test.yml)"
}

testCollectionsEmitJsonByDefault() {
    assertEquals '["one","two","three","four"]' "$(./ysh ".simple_list.list" test/test.yml)"
    assertEquals '{"name":"two","value":2}' "$(./ysh ".object_list.list[1]" test/test.yml)"
}

testFlowCollections() {
    assertEquals "request" "$(./ysh ".complex.details.type" test/issues.yml)"
    assertEquals "three, four" "$(./ysh ".inline[2]" test/issues.yml)"
    assertEquals "item" "$(./ysh ".inline[3].name" test/issues.yml)"
    assertEquals '[{"name":"api"},{"name":"worker"}]' "$(printf '%s\n' 'items: [name: api, "name": worker,]' | ./ysh --json '.items')"
}

testBlockScalars() {
    assertEquals "$(printf "This value\ncan span multiple lines")" "$(./ysh ".literal" test/issues.yml)"
    assertEquals "This value folds onto one line" "$(./ysh ".folded" test/issues.yml)"
}

testBlockAndIndentlessSequences() {
    assertEquals '["item1","item2"]' "$(./ysh ".indented" test/issues.yml)"
    assertEquals '["item1","item2"]' "$(./ysh ".indentless" test/issues.yml)"
    assertEquals "ten" "$(./ysh ".long_list[10]" test/issues.yml)"
    assertEquals '[["one","two"],[["three"]]]' "$(printf '%s\n' '- - one' '  - two' '- - - three' | ./ysh --json '.')"
}

testScalarAndCollectionAliases() {
    assertEquals "hello" "$(./ysh ".scalar_alias" test/advanced.yml)"
    assertEquals "true" "$(./ysh ".mapping_alias.nested.enabled" test/advanced.yml)"
    assertEquals '["first","second"]' "$(./ysh ".list_alias" test/advanced.yml)"
    assertEquals "b" "$(./ysh ".flow_alias.y[1]" test/advanced.yml)"
    assertEquals "1" "$(./ysh ".sequence_aliases[1].x" test/advanced.yml)"
    assertEquals '"unicode anchor"' "$(printf '%s\n' '- &😁 unicode anchor' | ./ysh --json '.[0]')"
    assertEquals '"value"' "$(printf '%s\n' 'key: &an:chor value' 'copy: *an:chor' | ./ysh --json '.copy')"
}

testMergeKeysAndPrecedence() {
    assertEquals '{"color":"red","size":"large","shape":"square"}' "$(./ysh ".merged" test/advanced.yml)"
    assertEquals '{"color":"green","size":"small"}' "$(./ysh ".inline_merge" test/advanced.yml)"
    assertEquals '{"from":"flow","active":true}' "$(./ysh ".literal_merge" test/advanced.yml)"
    assertEquals '{"color":"purple","size":"small","shape":"square"}' "$(./ysh ".block_merge" test/advanced.yml)"
    assertEquals "literal" "$(./ysh '.["quoted_merge_key"]["<<"]' test/advanced.yml)"
}

testEmptyCollectionsSurviveParsing() {
    assertEquals "{}" "$(./ysh ".empty_mapping" test/advanced.yml)"
    assertEquals "[]" "$(./ysh ".empty_sequence" test/advanced.yml)"
    assertEquals "mapping" "$(./ysh ".empty_mapping" test/advanced.yml --type)"
    assertEquals "sequence" "$(./ysh ".empty_sequence" test/advanced.yml --type)"
}

testQuotedQueryKeys() {
    assertEquals "dotted" "$(./ysh '.["key.with.dots"]' test/advanced.yml)"
    assertEquals "dotted" "$(./ysh ".[\"key.with.dots\"]" test/advanced.yml)"
}

testExpressionIterationAndPipes() {
    assertEquals "$(printf "%s\n" api worker web)" "$(./ysh '.services[].name' test/expressions.yml)"
    assertEquals "$(printf "%s\n" api worker web)" "$(./ysh '.services[] | .name' test/expressions.yml)"
    assertEquals "$(printf "%s\n" platform west)" "$(./ysh '.metadata[]' test/expressions.yml)"
}

testExpressionSelectAndComparisons() {
    assertEquals "$(printf "%s\n" api web)" "$(./ysh '.services[] | select(.enabled == true) | .name' test/expressions.yml)"
    assertEquals "$(printf "%s\n" api worker)" "$(./ysh '.services[] | select(.port >= 8080) | .name' test/expressions.yml)"
    assertEquals "web" "$(./ysh '.services[] | select(.tier == "frontend") | .name' test/expressions.yml)"
    assertEquals "worker" "$(./ysh '.services[] | select(.name != "api" and .enabled == false) | .name' test/expressions.yml)"
    assertEquals "$(printf "%s\n" true true false)" "$(./ysh '.services[] | .port >= 8080' test/expressions.yml)"
}

testExpressionBooleanFilters() {
    assertEquals "$(printf "%s\n" api web)" "$(./ysh '.services[] | select(.enabled and .port < 9000) | .name' test/expressions.yml)"
    assertEquals "$(printf "%s\n" false true false)" "$(./ysh '.services[] | .enabled | not' test/expressions.yml)"
    assertEquals "$(printf "%s\n" api web)" "$(./ysh '.services[] | select(.enabled) | .name' test/expressions.yml)"
}

testExpressionAlternativeDefaults() {
    assertEquals "fallback" "$(./ysh '.missing // "fallback"' test/expressions.yml)"
    assertEquals "fallback" "$(./ysh '.unset // "fallback"' test/expressions.yml)"
    assertEquals "fallback" "$(./ysh '.disabled // "fallback"' test/expressions.yml)"
    assertEquals "platform" "$(./ysh '.metadata.owner // "fallback"' test/expressions.yml)"
}

testExpressionCollectionHelpers() {
    assertEquals "3" "$(./ysh '.services | length' test/expressions.yml)"
    assertEquals "8" "$(./ysh '.metadata.owner | length' test/expressions.yml)"
    assertEquals '["owner","region"]' "$(./ysh '.metadata | keys' test/expressions.yml)"
    assertEquals '[0,1,2]' "$(./ysh '.services | keys' test/expressions.yml)"
    assertEquals "true" "$(./ysh '.metadata | has("owner")' test/expressions.yml)"
    assertEquals "false" "$(./ysh '.metadata | has("missing")' test/expressions.yml)"
    assertEquals "true" "$(./ysh '.services | has(2)' test/expressions.yml)"
    assertEquals "false" "$(./ysh '.services | has(9)' test/expressions.yml)"
}

testExpressionKindAndType() {
    assertEquals "map" "$(./ysh '.metadata | kind' test/expressions.yml)"
    assertEquals "seq" "$(./ysh '.services | kind' test/expressions.yml)"
    assertEquals "scalar" "$(./ysh '.services[0].name | kind' test/expressions.yml)"
    assertEquals "!!int" "$(./ysh '.services[0].port | type' test/expressions.yml)"
    assertEquals "!!bool" "$(./ysh '.services[0].enabled | type' test/expressions.yml)"
}

testExpressionMissingValuesAreNull() {
    assertEquals "null" "$(./ysh --json '.missing' test/expressions.yml)"
    assertEquals "null" "$(./ysh --json '.services[99]' test/expressions.yml)"
    assertEquals "null" "$(./ysh --json '.services[0].missing' test/expressions.yml)"
}

testExpressionBareRootFilters() {
    assertEquals "5" "$(./ysh 'length' test/expressions.yml)"
    assertEquals "2" "$(printf '%s\n' '[one, two]' | ./ysh 'length')"
}

testExpressionJsonStreams() {
    assertEquals "$(printf '%s\n' '{"name":"api","enabled":true,"port":8080,"tier":"backend"}' '{"name":"web","enabled":true,"port":3000,"tier":"frontend"}')" "$(./ysh --json '.services[] | select(.enabled)' test/expressions.yml)"
}

testExpressionRecursiveAndOptionalTraversal() {
    assertEquals "$(printf '%s\n' api worker web)" "$(./ysh '.. | select(has("name")) | .name' test/expressions.yml)"
    assertEquals "" "$(./ysh '.metadata.owner[]?' test/expressions.yml)"
    assertEquals "null" "$(./ysh --json '.missing?' test/expressions.yml)"
    assertEquals "null" "$(./ysh --json '.services[99]?' test/expressions.yml)"
}

testExpressionArrayAndObjectConstruction() {
    assertEquals '["platform","api","worker","web"]' "$(./ysh --json '[.metadata.owner, .services[].name]' test/expressions.yml)"
    assertEquals '{"owner":"platform","count":3}' "$(./ysh --json '{owner: .metadata.owner, count: (.services | length)}' test/expressions.yml)"
    assertEquals '{"name":"api","enabled":true}' "$(./ysh -n --json '{name: "api", enabled: true}')"
}

testExpressionArithmetic() {
    assertEquals "14" "$(./ysh -n --json '2 + 3 * 4')"
    assertEquals "2.5" "$(./ysh -n --json '5 / 2')"
    assertEquals '"yaml.sh"' "$(./ysh -n --json '"yaml" + ".sh"')"
    assertEquals '[1,2,3]' "$(./ysh -n --json '[1, 2] + [3]')"
    assertEquals '{"a":1,"b":3,"c":4}' "$(./ysh -n --json '{left: {a: 1, b: 2}, right: {b: 3, c: 4}} | .left + .right')"
}

testExpressionAssignmentAndCreation() {
    assertEquals '{"owner":"core","region":"west"}' "$(./ysh --json '.metadata.owner = "core" | .metadata' test/expressions.yml)"
    assertEquals '"stable"' "$(./ysh --json '.release.channel = "stable" | .release.channel' test/expressions.yml)"
    assertEquals "$(printf '%s\n' active backend active)" "$(./ysh '(.services[] | select(.enabled) | .tier) = "active" | .services[].tier' test/expressions.yml)"
}

testExpressionRelativeAndCompoundUpdates() {
    assertEquals "$(printf '%s\n' false true false)" "$(./ysh --json '.services[].enabled |= not | .services[].enabled' test/expressions.yml)"
    assertEquals "8100" "$(./ysh --json '.services[0].port += 20 | .services[0].port' test/expressions.yml)"
    assertEquals '"platform-team"' "$(./ysh --json '.metadata.owner += "-team" | .metadata.owner' test/expressions.yml)"
}

testExpressionDeletion() {
    assertEquals '{"owner":"platform"}' "$(./ysh --json 'del(.metadata.region) | .metadata' test/expressions.yml)"
    assertEquals "$(printf '%s\n' api web)" "$(./ysh 'del(.services[1]) | .services[].name' test/expressions.yml)"
    assertEquals '{"owner":"platform","region":"west"}' "$(./ysh --json 'del(.missing) | .metadata' test/expressions.yml)"
}

testExpressionMapAndCommaStreams() {
    assertEquals '["api","worker","web"]' "$(./ysh --json '.services | map(.name)' test/expressions.yml)"
    assertEquals '{"owner":"PLATFORM","region":"WEST"}' "$(./ysh --json '.metadata | map_values(upcase)' test/expressions.yml)"
    assertEquals "$(printf '%s\n' platform west)" "$(./ysh '.metadata.owner, .metadata.region' test/expressions.yml)"
}

testExpressionEntries() {
    assertEquals '[{"key":"owner","value":"platform"},{"key":"region","value":"west"}]' "$(./ysh --json '.metadata | to_entries' test/expressions.yml)"
    assertEquals '{"owner":"platform","region":"west"}' "$(./ysh --json '.metadata | to_entries | from_entries' test/expressions.yml)"
    assertEquals '{"owner":"PLATFORM","region":"WEST"}' "$(./ysh --json '.metadata | with_entries(.value |= upcase)' test/expressions.yml)"
}

testExpressionSequenceAndStringHelpers() {
    assertEquals '[1,1,2,3]' "$(./ysh -n --json '[3, 1, 2, 1] | sort')"
    assertEquals '[3,1,2]' "$(./ysh -n --json '[3, 1, 2, 1] | unique')"
    assertEquals '[1,2,3,4]' "$(./ysh -n --json '[[1, 2], [3, [4]]] | flatten')"
    assertEquals '["yaml","sh"]' "$(./ysh -n --json '"yaml.sh" | split(".")')"
    assertEquals '"yaml.sh"' "$(./ysh -n --json '["yaml", "sh"] | join(".")')"
    assertEquals 'true' "$(./ysh -n --json '"yaml.sh" | startswith("yaml") and endswith(".sh")')"
    assertEquals '6' "$(./ysh -n --json '[1, 2, 3] | add')"
    assertEquals '"yaml.sh"' "$(./ysh -n --json '["yaml", ".", "sh"] | add')"
}

testExpressionSlicesInterpolationAndRegex() {
    assertEquals '["worker","web"]' "$(./ysh --json '.services[1:3] | map(.name)' test/expressions.yml)"
    assertEquals '["api","worker"]' "$(./ysh --json '.services[:-1] | map(.name)' test/expressions.yml)"
    assertEquals '"platform/api/3"' "$(./ysh --json '"\(.metadata.owner)/\(.services[0].name)/\(.services | length)"' test/expressions.yml)"
    assertEquals 'true' "$(./ysh -n --json '"yaml.sh" | test("^[a-z]+\\.sh$")')"
    assertEquals '"YAML.sh/YAML.sh"' "$(./ysh -n --json '"yaml.sh/yaml.sh" | sub("yaml"; "YAML")')"
    assertEquals '"&-&"' "$(./ysh -n --json '"a-a" | sub("a"; "&")')"
    assertEquals '"-a-"' "$(./ysh -n --json '"ab" | sub("b*"; "-")')"
    assertEquals '"literal \\(text)"' "$(./ysh -n --json '"literal \\(text)"')"
}

testExpressionProjectedCollectionsAndQuantifiers() {
    assertEquals '[{"name":"api","port":80},{"name":"worker","port":443},{"name":"admin","port":443}]' "$(./ysh -n --json '[{name: "worker", port: 443}, {name: "api", port: 80}, {name: "admin", port: 443}] | sort_by(.port)')"
    assertEquals '[[{"name":"worker","port":443},{"name":"admin","port":443}],[{"name":"api","port":80}]]' "$(./ysh -n --json '[{name: "worker", port: 443}, {name: "api", port: 80}, {name: "admin", port: 443}] | group_by(.port)')"
    assertEquals '[{"name":"worker","port":443},{"name":"api","port":80}]' "$(./ysh -n --json '[{name: "worker", port: 443}, {name: "api", port: 80}, {name: "admin", port: 443}] | unique_by(.port)')"
    assertEquals '1' "$(./ysh -n --json '[3, 1, 2] | min')"
    assertEquals '3' "$(./ysh -n --json '[3, 1, 2] | max')"
    assertEquals '"web"' "$(./ysh --json '.services | min_by(.port) | .name' test/expressions.yml)"
    assertEquals '"worker"' "$(./ysh --json '.services | max_by(.port) | .name' test/expressions.yml)"
    assertEquals 'true' "$(./ysh -n --json '[false, true] | any')"
    assertEquals 'false' "$(./ysh -n --json '[true, false] | all')"
    assertEquals 'true' "$(./ysh -n --json '[1, 2, 3] | any_c(. == 2)')"
    assertEquals 'true' "$(./ysh -n --json '[1, 2, 3] | all_c(. > 0)')"
}

testExpressionVariablesAndDynamicIndexes() {
    assertEquals '"web"' "$(./ysh --json '.services[-1].name' test/expressions.yml)"
    assertEquals '"platform"' "$(./ysh -n --json '{key: "owner", data: {owner: "platform"}} | .key as $key | .data[$key]')"
    assertEquals '{"owner":"platform","region":"west"}' "$(./ysh --json '.metadata as $meta | {owner: $meta.owner, region: $meta.region}' test/expressions.yml)"
}

testExpressionReduceAndDeepMerge() {
    assertEquals '20170' "$(./ysh --json 'reduce .services[].port as $port (0; . + $port)' test/expressions.yml)"
    assertEquals '{"a":{"x":1,"y":3,"z":4},"b":1,"c":2}' "$(./ysh -n --json '{a: {x: 1, y: 2}, b: 1} * {a: {y: 3, z: 4}, c: 2}')"
}

testExpressionEnvironmentComposition() {
    assertEquals '{"name":"api","ports":[80,443]}' "$(YSH_TEST_CONFIG='{name: api, ports: [80, 443]}' ./ysh -n --json 'env(YSH_TEST_CONFIG)')"
    assertEquals '"literal: [text]"' "$(YSH_TEST_TEXT='literal: [text]' ./ysh -n --json 'strenv(YSH_TEST_TEXT)')"
    assertEquals '""' "$(env -u YSH_TEST_MISSING ./ysh -n --json 'strenv(YSH_TEST_MISSING)')"
    assertEquals '"hello world / world"' "$(printf '%s\n' 'value: hello $YSH_TEST_NAME / ${YSH_TEST_NAME}' | YSH_TEST_NAME=world ./ysh --json '.value | envsubst')"
    assertEquals '"fallback/default"' "$(printf '%s\n' 'value: ${YSH_TEST_EMPTY:-fallback}/${YSH_TEST_MISSING-default}' | YSH_TEST_EMPTY='' ./ysh --json '.value | envsubst')"

    result=$(YSH_TEST_CONFIG=value ./ysh --security-disable-env-ops -n 'env(YSH_TEST_CONFIG)' 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "environment operations are disabled"
    result=$(env -u YSH_TEST_MISSING ./ysh -n 'env(YSH_TEST_MISSING)' 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "not provided in env()"
    result=$(printf '%s\n' 'value: ${YSH_TEST_EMPTY}' | YSH_TEST_EMPTY='' ./ysh '.value | envsubst(ne, ff)' 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "is empty"
}

testExpressionStructuralContextAndScopedUpdates() {
    input=$(printf '%s\n' 'a:' '  b: [10, 20]' 'c: 3')
    assertEquals '["a","b",1]' "$(printf '%s\n' "$input" | ./ysh --json '.. | select(. == 20) | path')"
    assertEquals '[10,20]' "$(printf '%s\n' "$input" | ./ysh --json '.. | select(. == 20) | parent')"
    assertEquals '[]' "$(printf '%s\n' "$input" | ./ysh --json 'path')"
    assertEquals '' "$(printf '%s\n' "$input" | ./ysh --json 'parent')"
    assertEquals '{"a":{"x":9,"y":2},"b":3}' "$(printf '%s\n' 'a:' '  x: 1' '  y: 2' 'b: 3' | ./ysh --json 'with(.a; .x = 9)')"
}

testExpressionConversionAndKeyOrdering() {
    assertEquals '12' "$(printf '%s\n' 'value: "12"' | ./ysh --json '.value | to_number')"
    assertEquals '1.5' "$(printf '%s\n' 'value: "1.5"' | ./ysh --json '.value | to_number')"
    assertEquals '{"a":2,"m":{"z":3,"a":4},"z":1}' "$(printf '%s\n' 'z: 1' 'a: 2' 'm:' '  z: 3' '  a: 4' | ./ysh --json 'sort_keys(.)')"

    result=$(printf '%s\n' 'value: nope' | ./ysh '.value | to_number' 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "cannot convert value to number"
}

testExpressionFocusedCollectionOperators() {
    input=$(printf '%s\n' 'a:' '  - cat' '  - dog' '  - cow')
    assertEquals '"dog"' "$(printf '%s\n' "$input" | ./ysh --json '.a | first(. == "dog")')"
    assertEquals '"cat"' "$(printf '%s\n' "$input" | ./ysh --json '.a | first')"
    assertEquals '["dog","cow"]' "$(printf '%s\n' "$input" | ./ysh --json '.a | filter(. != "cat")')"
    assertEquals '["cow","cat"]' "$(printf '%s\n' "$input" | ./ysh --json '.a | pick([2, 0, 99])')"
    assertEquals '["dog","cow"]' "$(printf '%s\n' "$input" | ./ysh --json '.a | omit([0, 99])')"
    assertEquals '[["a","x"],["b",null]]' "$(./ysh -n --json '[["a", "b"], ["x"]] | pivot')"
    assertEquals '{"a":[1,3],"b":[2,null],"c":[null,4]}' "$(./ysh -n --json '[{"a": 1, "b": 2}, {"a": 3, "c": 4}] | pivot')"
}

testExpressionNodeMetadata() {
    input=$(printf '%s\n' 'a:' '  - cat' '  - dog')
    assertEquals '3' "$(printf '%s\n' "$input" | ./ysh --json '.a[1] | line')"
    assertEquals '1' "$(printf '%s\n' "$input" | ./ysh --json '.a[1] | key')"
    assertEquals '"!!str"' "$(printf '%s\n' "$input" | ./ysh --json '.a[1] | tag')"
}

testMultipleInputEvaluationAndMetadata() {
    first=$(mktemp "${TMPDIR:-/tmp}/ysh-first.XXXXXX")
    second=$(mktemp "${TMPDIR:-/tmp}/ysh-second.XXXXXX")
    printf '%s\n' 'answer: 1' > "$first"
    printf '%s\n' 'answer: 2' > "$second"
    expected=$(printf '["%s",0,0,1]\n["%s",1,0,2]' "$first" "$second")
    assertEquals "$expected" "$(./ysh eval --json '[filename, fileIndex, documentIndex, .answer]' "$first" "$second")"
    assertEquals "$(printf '%s\n' '"answer": 1' '---' '"answer": 2')" "$(./ysh -o yaml '.' "$first" "$second")"
    ./ysh -i '.answer = 3' "$first" "$second" >/dev/null 2>&1
    assertEquals 2 $?
    ./ysh ea -i '.answer = 3' "$first" >/dev/null 2>&1
    assertEquals 2 $?
    rm -f "$first" "$second"
}

testAllDocumentEvaluation() {
    input=$(printf '%s\n' '---' 'answer: 1' '---' 'answer: 2' '---' 'answer: 3')
    assertEquals "$(printf '%s\n' '[0,1]' '[1,2]' '[2,3]')" "$(printf '%s\n' "$input" | ./ysh --all-documents --json '[documentIndex, .answer]')"
    assertEquals "$(printf '%s\n' '"answer": 1' '---' '"answer": 2' '---' '"answer": 3')" "$(printf '%s\n' "$input" | ./ysh --all-documents -o yaml '.')"
}

testEvalAllAcrossFiles() {
    first=$(mktemp "${TMPDIR:-/tmp}/ysh-eval-all-first.XXXXXX")
    second=$(mktemp "${TMPDIR:-/tmp}/ysh-eval-all-second.XXXXXX")
    printf '%s\n' 'a: 1' > "$first"
    printf '%s\n' '---' 'b: 2' '---' 'c: 3' > "$second"
    expected=$(printf '["%s",0,0,"%s",1,0,"%s",1,1]' "$first" "$second" "$second")
    assertEquals "$expected" "$(./ysh eval-all --json '[filename, fileIndex, documentIndex]' "$first" "$second")"
    assertEquals '[{"a":1},{"b":2},{"c":3}]' "$(./ysh ea --json '[.]' "$first" "$second")"
    assertEquals "$(printf '%s\n' '{"a":1,"b":2}' '{"a":1,"c":3}')" "$(./ysh ea --json 'select(fileIndex == 0) * select(fileIndex == 1)' "$first" "$second")"
    rm -f "$first" "$second"
}

testExitStatusAndEmptyStreams() {
    printf '%s\n' 'value: true' | ./ysh -e '.value' >/dev/null
    assertEquals 0 $?
    printf '%s\n' 'value: false' | ./ysh --exit-status '.value' >/dev/null
    assertEquals 1 $?
    printf '%s\n' 'value: null' | ./ysh -e '.value' >/dev/null
    assertEquals 1 $?
    printf '%s\n' 'value: true' | ./ysh -e 'empty' >/dev/null
    assertEquals 1 $?
}

testExpandedYamlSyntax() {
    assertEquals '"snowman ☃ rocket 🚀"' "$(printf '%s\n' 'unicode: "snowman \u2603 rocket \U0001F680"' | ./ysh --json '.unicode')"
    assertEquals '["one",{"name":"two","enabled":true},"three"]' "$(printf '%s\n' 'items: [' '  one,' '  {name: two, enabled: true},' '  three' ']' | ./ysh --json '.items')"
    assertEquals '"hello\nworld"' "$(printf '%s\n' 'message: |2-' '  hello' '  world' | ./ysh --json '.message')"
}

testYamlOutputRoundTrips() {
    assertEquals '"core"' "$(./ysh -o=yaml '.metadata.owner = "core"' test/expressions.yml | ./ysh --json '.metadata.owner')"
    assertEquals '"web"' "$(./ysh -o=yaml '.' test/expressions.yml | ./ysh --json '.services[2].name')"
    assertEquals '{"color":"red","size":"large","shape":"square"}' "$(./ysh -o=yaml '.' test/advanced.yml | ./ysh --json '.merged')"
    assertEquals 'tag:example.com,2026:widget' "$(./ysh -o=yaml '.' test/advanced.yml | ./ysh --tag '.types.custom')"
}

testYamlOutputSeparatesStreams() {
    assertEquals "$(printf '%s\n' '"api"' '---' '"worker"' '---' '"web"')" "$(./ysh -o=yaml '.services[].name' test/expressions.yml)"
}

testInplaceUpdate() {
    inplace_file=test/.tmp-inplace-$$.yml
    cp test/expressions.yml "$inplace_file"
    chmod 640 "$inplace_file"
    mode_before=$(find "$inplace_file" -prune -exec ls -ld {} \; | cut -c2-10)
    ./ysh -i '.metadata.owner = "core"' "$inplace_file"
    assertEquals 0 $?
    assertEquals '"core"' "$(./ysh --json '.metadata.owner' "$inplace_file")"
    assertEquals "$mode_before" "$(find "$inplace_file" -prune -exec ls -ld {} \; | cut -c2-10)"
    rm -f "$inplace_file"
}

testInplaceFailureIsAtomic() {
    inplace_file=test/.tmp-inplace-atomic-$$.yml
    backup_file=test/.tmp-inplace-atomic-backup-$$.yml
    link_file=test/.tmp-inplace-atomic-link-$$.yml
    printf '%s\n' 'service:' '  name: api' > "$inplace_file"
    cp "$inplace_file" "$backup_file"

    ./ysh -i '.service.name = ' "$inplace_file" >/dev/null 2>&1
    assertNotEquals 0 $?
    cmp -s "$backup_file" "$inplace_file"
    assertEquals 0 $?

    ln -s "$(basename "$inplace_file")" "$link_file"
    result=$(./ysh -i '.service.name = "worker"' "$link_file" 2>&1)
    assertEquals 2 $?
    assertContains "$result" 'refuses symbolic links'
    cmp -s "$backup_file" "$inplace_file"
    assertEquals 0 $?

    set -- "test/.$(basename "$inplace_file").ysh."*
    assertFalse "temporary file must be removed" "[ -e \"$1\" ]"
    rm -f "$link_file" "$backup_file" "$inplace_file"
}

testInplaceTransformsAllDocuments() {
    inplace_file=test/.tmp-inplace-multi-$$.yml
    cp test/test.yml "$inplace_file"
    ./ysh -i '.key = "changed"' "$inplace_file"
    assertEquals 0 $?
    assertEquals 'changed' "$(./ysh -d 0 '.key' "$inplace_file")"
    assertEquals 'changed' "$(./ysh -d 1 '.key' "$inplace_file")"
    assertEquals 'changed' "$(./ysh -d 2 '.key' "$inplace_file")"
    rm -f "$inplace_file"
}

testInplacePreservesScalarPresentation() {
    inplace_file=test/.tmp-inplace-presentation-$$.yml
    printf '%s\n' '# deployment settings' 'service:' '  name: api      # public name' '  label: "API service"' '  owner: '\''platform team'\''' '  enabled: true' > "$inplace_file"
    ./ysh -i '.service.name = "worker" | .service.label = "Worker service" | .service.owner = "core team" | .service.enabled = false' "$inplace_file"
    assertEquals 0 $?
    result=$(cat "$inplace_file")
    assertContains "$result" '# deployment settings'
    assertContains "$result" 'name: worker      # public name'
    assertContains "$result" 'label: "Worker service"'
    assertContains "$result" "owner: 'core team'"
    assertContains "$result" 'enabled: false'
    rm -f "$inplace_file"
}

testInplacePreservesStructuralPresentation() {
    inplace_file=test/.tmp-inplace-structure-$$.yml
    printf '%s\n' '# deployment settings' 'service:' '  name: api      # public name' '  port: 8080     # remove this' '' '# worker stays documented' 'workers:' '  - first' '  - second' 'footer: kept    # untouched' > "$inplace_file"
    ./ysh -i 'del(.service.port) | del(.workers[0]) | .service.protocol = "http" | .region = "west"' "$inplace_file"
    assertEquals 0 $?
    result=$(cat "$inplace_file")
    assertContains "$result" '# deployment settings'
    assertContains "$result" 'name: api      # public name'
    assertNotContains "$result" 'port: 8080'
    assertContains "$result" '# worker stays documented'
    assertNotContains "$result" '  - first'
    assertContains "$result" '  - second'
    assertContains "$result" '  protocol: "http"'
    assertContains "$result" 'footer: kept    # untouched'
    assertContains "$result" 'region: "west"'
    rm -f "$inplace_file"
}

testInplacePreservesReorderedSequenceComments() {
    inplace_file=test/.tmp-inplace-reorder-$$.yml
    printf '%s\n' '# queue order' 'workers: # keep the header' '  # first worker' '  - first' '  # second worker' '  - second' 'footer: kept' > "$inplace_file"
    ./ysh -i '.workers |= reverse' "$inplace_file"
    assertEquals 0 $?
    expected=$(printf '%s\n' '# queue order' 'workers: # keep the header' '  # second worker' '  - second' '  # first worker' '  - first' 'footer: kept')
    assertEquals "$expected" "$(cat "$inplace_file")"
    rm -f "$inplace_file"
}

testInplacePreservesSortedSequenceBlocks() {
    inplace_file=test/.tmp-inplace-sort-$$.yml
    printf '%s\n' 'services:' '  # slow path' '  - name: worker' '    port: 9000' '  # fast path' '  - name: api' '    port: 80' 'tail: kept' > "$inplace_file"
    ./ysh -i '.services |= sort_by(.port)' "$inplace_file"
    assertEquals 0 $?
    expected=$(printf '%s\n' 'services:' '  # fast path' '  - name: api' '    port: 80' '  # slow path' '  - name: worker' '    port: 9000' 'tail: kept')
    assertEquals "$expected" "$(cat "$inplace_file")"
    rm -f "$inplace_file"
}

testInplacePreservesRichYamlPresentation() {
    inplace_file=test/.tmp-inplace-rich-$$.yml
    cp test/presentation.yml "$inplace_file"
    ./ysh -i 'del(.service.obsolete) | .items[0] = "uno" | .items |= reverse | .service.name = "worker" | .service.region = "west"' "$inplace_file"

    expected=$(printf '%s\n' '%YAML 1.2' '%TAG !e! tag:example.com,2026:' '---' '# deployment' 'defaults: &defaults {retries: 3, mode: safe} # flow stays' 'service: !e!app' '  name: "worker"       # public name' "  owner: 'platform team'" '  notes: |-' '    keep this' '    exactly' '  inherited: *defaults' '  region: "west"' 'items: # order' '  # second item' "  - !e!item 'two'" '  # first item' '  - &first "uno"' 'footer: kept # tail')
    assertEquals "$expected" "$(cat "$inplace_file")"
    rm -f "$inplace_file"
}

testExpressionErrors() {
    result=$(./ysh '.services[] | select(' test/expressions.yml 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "expected expression"

    result=$(./ysh '.metadata.owner[]' test/expressions.yml 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "cannot iterate over string"

    result=$(./ysh '.services | mystery' test/expressions.yml 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "unknown expression operator"

    result=$(./ysh -n '1 / 0' 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "division by zero"

    result=$(./ysh -n '"unterminated \(."' 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "unterminated interpolation"

    result=$(./ysh -n '[1, 2]["x":]' 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "slice start requires an integer"
}

testScalarAndCollectionTypes() {
    assertEquals "string" "$(./ysh ".types.quoted_number" test/advanced.yml --type)"
    assertEquals "null" "$(./ysh ".types.null" test/advanced.yml --type)"
    assertEquals "bool" "$(./ysh ".types.boolean" test/advanced.yml --type)"
    assertEquals "int" "$(./ysh ".types.integer" test/advanced.yml --type)"
    assertEquals "float" "$(./ysh ".types.exponent" test/advanced.yml --type)"
    assertEquals "timestamp" "$(./ysh ".types.timestamp" test/advanced.yml --type)"
    assertEquals "tagged" "$(./ysh ".types.custom" test/advanced.yml --type)"
    assertEquals "mapping" "$(./ysh ".tagged_mapping" test/advanced.yml --type)"
}

testExpandedTags() {
    assertEquals "tag:yaml.org,2002:str" "$(./ysh ".types.forced_string" test/advanced.yml --tag)"
    assertEquals "tag:example.com,2026:widget" "$(./ysh ".types.custom" test/advanced.yml --tag)"
    assertEquals "tag:example.com,2026:box" "$(./ysh ".tagged_mapping" test/advanced.yml --tag)"
}

testSourceLines() {
    assertEquals "2" "$(./ysh ".complex.details.type" test/issues.yml --line)"
    assertEquals "10" "$(./ysh ".literal" test/issues.yml --line)"
}

testMultipleDocuments() {
    assertEquals "value" "$(./ysh ".key" test/test.yml)"
    assertEquals "block_2_value" "$(./ysh -d 1 ".key" test/test.yml)"
    assertEquals "block_3_value" "$(./ysh --document 2 ".key" test/test.yml)"
    assertEquals "second" "$(./ysh -d 1 ".fresh_alias" test/advanced.yml)"
    assertEquals '"inline"' "$(printf '%s\n' '%YAML 1.2' '--- inline' | ./ysh --json '.')"
}

testExplicitScalarKeys() {
    assertEquals "explicit value" "$(./ysh '.["explicit key"]' test/advanced.yml)"
}

testRootScalarsAndCollections() {
    assertEquals "https://yaml.sh" "$(printf "%s\n" "https://yaml.sh" | ./ysh ".")"
    assertEquals '["one","two"]' "$(printf "%s\n" "[one, two]" | ./ysh ".")"
    result=$(printf "%s\n" "{one: 1, two: 2}" | ./ysh ".")
    assertContains "$result" '"one":1'
    assertContains "$result" '"two":2'
}

testEmptyStreamsAndDocuments() {
    assertEquals "" "$(printf "" | ./ysh "." --json)"
    assertEquals "" "$(printf '%s\n' '...' | ./ysh "." --json)"
    assertEquals "null" "$(printf "%s\n" "---" "..." | ./ysh "." --json)"
    assertEquals "null" "$(printf "%s\n" "---" "---" "key: value" | ./ysh -d 0 "." --json)"
    assertEquals "value" "$(printf "%s\n" "---" "---" "key: value" | ./ysh -d 1 ".key")"
    assertEquals "value" "$(printf '%s\n' 'first' '...' 'key: value' | ./ysh -d 1 '.key')"
}

testPrimaryTagHandleExpansion() {
    result=$(printf "%s\n" "%TAG ! tag:example.com,2026:" "---" "value: !widget payload" | ./ysh ".value" --tag)
    assertEquals "tag:example.com,2026:widget" "$result"
}

testAstInspection() {
    result=$(./ysh --ast test/advanced.yml)
    assertContains "$result" "node"
    assertContains "$result" 'anchor="defaults"'
    assertContains "$result" 'key="merged"'
    assertContains "$result" "merge=1"
}

testEventInspection() {
    result=$(./ysh --events test/advanced.yml)
    assertContains "$result" "STREAM_START"
    assertContains "$result" 'ALIAS name="greeting"'
    assertContains "$result" 'KEY value="<<" merge=1'
    assertContains "$result" "STREAM_END"
}

testCommentsQuotesAndCrLf() {
    assertEquals "value" "$(./ysh ".comment" test/issues.yml)"
    assertEquals 'say "hello"' "$(./ysh ".quotes.double" test/issues.yml)"
    assertEquals "it is fine" "$(printf "%s\n" "message: it is fine" | ./ysh ".message")"
    assertEquals "value" "$(printf "key: value\r\n" | ./ysh ".key")"
    assertEquals "https://yaml.sh" "$(./ysh ".urls[0]" test/issues.yml)"
}

testMultilinePlainScalars() {
    assertEquals '"a b\nc"' "$(printf '%s\n' 'plain: a' ' b' '' ' c' | ./ysh --json '.plain')"
    assertEquals '"not yaml another root"' "$(printf '%s\n' 'not yaml' 'another root' | ./ysh --json '.')"
    assertEquals '"flow in block"' "$(printf '%s\n' '-' '  "flow in block"' | ./ysh --json '.[0]')"
    assertEquals '"value"' "$(printf '%s\n' 'key: # comment' '  value' | ./ysh --json '.key')"
}

testDuplicateKeysAreRejected() {
    result=$(printf "%s\n" "key: first" "key: second" | ./ysh ".key" 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "duplicate mapping key key"
}

testUndefinedAndForwardAliasesAreRejected() {
    result=$(printf "%s\n" "value: *later" "later: &later yes" | ./ysh ".value" 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "undefined or forward alias *later"
}

testRecursiveAliasesAreRejected() {
    result=$(printf "%s\n" "root: &root" "  child: *root" | ./ysh ".root.child" 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "recursive alias *root"
}

testInvalidMergeSourcesAreRejected() {
    result=$(printf "%s\n" "scalar: &scalar value" "target:" "  <<: *scalar" | ./ysh ".target" 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "merge source is not a mapping"
}

testUnsupportedComplexKeysAreRejected() {
    result=$(printf "%s\n" "? [one, two]" ": value" | ./ysh "." 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "collection-valued complex keys are not supported"
}

testMalformedYamlIsRejected() {
    result=$(printf "%s\n" "items: [one," "  two" | ./ysh ".items" 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "unclosed multiline flow collection"
}

testStrictGrammarAndEdgeSyntax() {
    assertEquals '{"key":"value","foo":"key"}' "$(printf '%s\n' '&a: key: &a value' 'foo:' '  *a:' | ./ysh --json '.')"
    assertEquals '{"block key\n":["one","two"]}' "$(printf '%s\n' '? |' '  block key' ': - one' '  - two' | ./ysh --json '.')"
    assertEquals '"trailing\t tab"' "$(printf '"trailing\\\t\n  tab"\n' | ./ysh --json '.')"
    assertEquals '"content\n"' "$(printf '%s\n' '|' 'content' | ./ysh --json '.')"

    printf '%s\n' 'key:' ' ok: 1' '  wrong: 2' | ./ysh --json '.' >/dev/null 2>&1
    assertNotEquals 0 $?
    printf '%s\n' 'flow: [one,' 'two]' | ./ysh --json '.' >/dev/null 2>&1
    assertNotEquals 0 $?
    printf 'key:\n\tchild: value\n' | ./ysh --json '.' >/dev/null 2>&1
    assertNotEquals 0 $?
}

testResourceLimits() {
    result=$(printf '%s\n' 'key: value' | ./ysh --max-input-bytes 4 --json '.' 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "input size limit exceeded"

    result=$(printf '%s\n' 'key: value' | ./ysh --max-nodes 2 --json '.' 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "node limit exceeded"

    result=$(printf '%s\n' 'one:' '  two:' '    three: value' | ./ysh --max-depth 1 --json '.' 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "depth limit exceeded"

    ./ysh --max-nodes nope '.' test/test.yml >/dev/null 2>&1
    assertEquals 2 $?
}

testQueryErrors() {
    result=$(./ysh "missing" test/test.yml 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "unknown expression operator"
}

testCliErrors() {
    ./ysh ".key" does-not-exist.yml >/dev/null 2>&1
    assertEquals 1 $?
    ./ysh --document nope ".key" test/test.yml >/dev/null 2>&1
    assertEquals 2 $?
    ./ysh --output xml ".key" test/test.yml >/dev/null 2>&1
    assertEquals 2 $?
    ./ysh --unknown ".key" test/test.yml >/dev/null 2>&1
    assertEquals 2 $?
    ./ysh -i '.key = "value"' </dev/null >/dev/null 2>&1
    assertEquals 2 $?
    ./ysh -i -n '.key = "value"' test/test.yml >/dev/null 2>&1
    assertEquals 2 $?
}

testRunsWithPosixShell() {
    assertEquals "value" "$(/bin/sh ./ysh ".key_value.key" test/test.yml)"
}

testGeneratedDifferentialCorpusStaysInSync() {
    generated_corpus=$(mktemp "${TMPDIR:-/tmp}/ysh-corpus.XXXXXX")
    ./test/generate-yq-corpus.sh > "$generated_corpus"
    cmp -s test/yq-corpus.tsv "$generated_corpus"
    assertEquals 0 $?
    rm -f "$generated_corpus"
}

testReleaseArtifactsStayInSync() {
    if command -v sha256sum >/dev/null 2>&1; then
        release_sha256=$(sha256sum ysh)
    else
        release_sha256=$(shasum -a 256 ysh)
    fi
    release_sha256=${release_sha256%% *}
    assertContains "$(cat README.md)" "v1.7.0/ysh"
    assertContains "$(cat _static/_www/docs/getting-started.md)" "v1.7.0/ysh"
    assertContains "$(cat _static/_www/install)" "v1.7.0/ysh"
    assertContains "$(cat _static/_www/install)" "expected_sha256=$release_sha256"
    assertContains "$(cat _static/_www/install)" "checksum verification failed"
    assertContains "$(cat _static/_www/index.html)" "Install v1.7"
    assertContains "$(cat _static/_www/index.html)" "style.css?v=1.7.0"
    assertContains "$(cat _static/_www/docs/index.html)" "theme.css?v=1.7.0"
    assertContains "$(cat _static/_www/docs/index.html)" "docsify@4/lib/themes/vue.css"
    assertContains "$(cat README.md)" "og-v1.7.png"
    assertContains "$(cat _static/_www/index.html)" "og-v1.7.png"
    assertTrue "versioned social preview image must exist" "[ -s _static/_www/og-v1.7.png ]"
    assertContains "$(cat _static/_www/docs/supported_yml.md)" "282/282"
    assertContains "$(cat _static/_www/docs/supported_yml.md)" "91/91"
    assertContains "$(cat _static/_www/docs/supported_yml.md)" "2,610/2,610"
    assertContains "$(cat _static/_www/docs/supported_yml.md)" "12,000/12,000"
    assertContains "$(cat _static/_www/docs/supported_yml.md)" "400/400"
}

# shellcheck source=/dev/null
. ./test/shunit2
