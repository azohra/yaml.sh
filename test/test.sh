#!/bin/sh

testVersion() {
    assertEquals "v1.17.1" "$(./ysh --version)"
}

testHelp() {
    result=$(./ysh --help)
    assertEquals 0 $?
    assertContains "$result" "One readable shell file"
    assertContains "$result" "familiar to yq users"
    assertContains "$result" "events"
    assertContains "$result" "explain"
    assertContains "$result" "rolling back a failed write"
    assertContains "$result" "preview edits as unified diffs"
    assertContains "$result" "cannot keep comments and formatting"
    assertContains "$result" "disable eval()"
    assertContains "$(PATH=/nonexistent ./ysh --help)" "YAML.sh"
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
    ./ysh --indent=0 -o=yaml '.' test/test.yml >/dev/null 2>&1
    assertEquals 2 $?
    ./ysh --unwrap-scalar=maybe '.key_value.key' test/test.yml >/dev/null 2>&1
    assertEquals 2 $?
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
    assertEquals "false" "$(./ysh -n '[1, 2] == [1, 2]')"
    assertEquals "false" "$(./ysh -n '{a: 1} == {a: 1}')"
}

testExpressionBooleanFilters() {
    assertEquals "$(printf "%s\n" api web)" "$(./ysh '.services[] | select(.enabled and .port < 9000) | .name' test/expressions.yml)"
    assertEquals "$(printf "%s\n" false true false)" "$(./ysh '.services[] | .enabled | not' test/expressions.yml)"
    assertEquals "$(printf "%s\n" api web)" "$(./ysh '.services[] | select(.enabled) | .name' test/expressions.yml)"
}

testExpressionErrorGuards() {
    assertEquals 'true' "$(./ysh -n --json 'true or error("must not run")')"
    assertEquals 'false' "$(./ysh -n --json 'false and error("must not run")')"

    result=$(./ysh -n 'false or error("guard failed")' 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" 'guard failed'

    result=$(printf '%s\n' 'kind: Service' | ./ysh 'with(.kind; select(. == "Deployment") or error("expected Deployment"))' 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" 'expected Deployment'
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
    assertEquals '{"a":{"b":"changed","c":"also"}}' "$(printf '%s\n' 'a:' '  b: one' '  c: two' | ./ysh --json '.a ref $target | $target.b = "changed" | $target.c = "also"')"
}

testExpressionReduceAndDeepMerge() {
    assertEquals '20170' "$(./ysh --json 'reduce .services[].port as $port (0; . + $port)' test/expressions.yml)"
    assertEquals '6' "$(./ysh -n --json '[1, 2, 3][] as $item ireduce (0; . + $item)')"
    assertEquals '{"api":8080,"worker":9090,"web":3000}' "$(./ysh --json '.services[] as $service ireduce ({}; . * {($service.name): $service.port})' test/expressions.yml)"
    assertEquals '{"a":{"x":1,"y":3,"z":4},"b":1,"c":2}' "$(./ysh -n --json '{a: {x: 1, y: 2}, b: 1} * {a: {y: 3, z: 4}, c: 2}')"
}

testExpressionMergeModifiers() {
    assertEquals '{"array":[3,4],"value":"right"}' "$(./ysh -n --json '{array: [1, 2], value: "left"} * {array: [3, 4], value: "right"}')"
    assertEquals '{"array":[1,2,3,4],"value":"right"}' "$(./ysh -n --json '{array: [1, 2], value: "left"} *+ {array: [3, 4], value: "right"}')"
    assertEquals '{"thing":"two","cat":"frog"}' "$(./ysh -n --json '{thing: "one", cat: "frog"} *? {missing: "two", thing: "two"}')"
    assertEquals '{"thing":"one","cat":"frog","missing":"two"}' "$(./ysh -n --json '{thing: "one", cat: "frog"} *n {missing: "two", thing: "two"}')"
    assertEquals '{"a":{"x":1,"y":2}}' "$(./ysh -n --json '{a: {x: 1}} *n {a: {y: 2}}')"
    assertEquals '[{"name":"fred","age":34},{"name":"bob","age":32}]' "$(./ysh -n --json '[{name: "fred", age: 12}, {name: "bob", age: 32}] *d [{name: "fred", age: 34}]')"
    assertEquals '[{"x":1,"y":2}]' "$(./ysh -n --json '[{x: 1}] *dn [{y: 2}]')"
    assertEquals '[1,3]' "$(./ysh -n --json '[1] *dn [2, 3]')"
    assertEquals '{"thing":[1,2,3,4]}' "$(./ysh -n --json '{thing: [1, 2]} *?+ {thing: [3, 4], another: [1]}')"
}

testExpressionPathBasedUpdates() {
    assertEquals '{"a":{"b":1,"c":2}}' "$(printf '%s\n' 'a: {b: 1}' | ./ysh --json 'setpath(["a", "c"]; 2)')"
    assertEquals '{"a":{"items":[null,null,{"name":"third"}]}}' "$(printf '%s\n' 'a: {}' | ./ysh --json 'setpath(["a", "items", 2, "name"]; "third")')"
    assertEquals '{"a":{"c":2},"items":["zero","two"]}' "$(printf '%s\n' 'a: {b: 1, c: 2}' 'items: [zero, one, two]' | ./ysh --json 'delpaths([["a", "b"], ["items", 1]])')"

    result=$(printf '%s\n' 'a: 1' | ./ysh 'setpath(["a", "b"]; 2)' 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "cannot traverse"
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

testExpressionCapabilityClosure() {
    assertEquals '"cat"' "$(printf '%s\n' 'value: "  cat  "' | ./ysh --json '.value | trim')"
    assertEquals '["1","true","null","~","cat","an: object","- array\n- 2"]' "$(printf '%s\n' '- 1' '- true' '- null' '- ~' '- cat' '- an: object' '- - array' '  - 2' | ./ysh --json 'map(to_string)')"
    assertEquals '{"0":"zero","1":{"name":"one"}}' "$(printf '%s\n' '- zero' '- name: one' | ./ysh --json 'array_to_map')"
    assertEquals '[4,1,0]' "$(printf '%s\n' 'a: cat' 'b: bob' | ./ysh --json '[.b | column, .b | key | column, {"a": "new"} | column]')"
    assertEquals "$(printf '%s\n' '"a": "cat"' '---' '"b": "dog"')" "$(printf '%s\n' '- a: cat' '- b: dog' | ./ysh -o=yaml '.[] | split_doc')"
    assertEquals '{"a":{"c":3,"d":4},"b":2}' "$(printf '%s\n' 'b: 2' 'a:' '  d: 4' '  c: 3' | ./ysh --json 'sort_keys(..)')"
}

testExpressionPortableUtilities() {
    load_yaml=test/.tmp-load-yaml-$$.yml
    load_text=test/.tmp-load-text-$$.txt
    load_base64=test/.tmp-load-base64-$$.txt
    load_props=test/.tmp-load-props-$$.properties
    printf '%s\n' 'service:' '  name: loaded' '  ports: [80, 443]' > "$load_yaml"
    printf '%s\n' 'plain text' 'with two lines' > "$load_text"
    printf '%s\n' 'bG9hZGVkIHNlY3JldA==' > "$load_base64"
    printf '%s\n' 'service.name=props' 'service.ports.0=80' 'service.ports.1=443' > "$load_props"

    input=$(printf '%s\n' 'a:' '  cool: thing' 'text: a special string' "json: '{\"cool\":\"thing\",\"n\":3}'" 'yaml: |' '  foo: bar' '  list: [one, two]' 'pathExp: .a.cool')
    assertEquals '"{\n  \"cool\": \"thing\"\n}\n"' "$(printf '%s\n' "$input" | ./ysh --json '.a | to_json')"
    assertEquals '"{\"cool\":\"thing\"}"' "$(printf '%s\n' "$input" | ./ysh --json '.a | @json')"
    assertEquals '{"cool":"thing"}' "$(./ysh -n --json '"{\"cool\":\"thing\"}" | @jsond')"
    assertEquals '"cool: thing\n"' "$(printf '%s\n' "$input" | ./ysh --json '.a | to_yaml')"
    assertEquals '{"cool":"thing"}' "$(./ysh -n --json '"cool: thing" | @yamld')"
    assertEquals '"YSBzcGVjaWFsIHN0cmluZw=="' "$(printf '%s\n' "$input" | ./ysh --json '.text | @base64')"
    assertEquals '"a special string"' "$(./ysh -n --json '"YSBzcGVjaWFsIHN0cmluZw==" | @base64d')"
    assertEquals '"caf%C3%A9+%F0%9F%98%8A"' "$(./ysh -n --json '"café 😊" | @uri')"
    assertEquals '"café 😊"' "$(./ysh -n --json '"caf%C3%A9+%F0%9F%98%8A" | @urid')"
    assertEquals "\"with' space'\"" "$(./ysh -n --json '"with space" | @sh')"
    assertEquals '{"cool":"thing","n":3}' "$(printf '%s\n' "$input" | ./ysh --json '.json | from_json')"
    assertEquals '{"foo":"bar","list":["one","two"]}' "$(printf '%s\n' "$input" | ./ysh --json '.yaml | from_yaml')"
    assertEquals '"cool = thing\n"' "$(printf '%s\n' "$input" | ./ysh --json '.a | @props')"
    assertEquals '{"cats":"great","dogs":"cool as well","items":["one","two"]}' "$(printf '%s\n' 'data: |-' '  cats=great' '  dogs=cool as well' '  items.0=one' '  items.1=two' | ./ysh --json '.data | @propsd')"
    assertEquals '"name,type\nBobo,dog\nFifi,cat"' "$(printf '%s\n' '- name: Bobo' '  type: dog' '- name: Fifi' '  type: cat' | ./ysh --json '@csv')"
    assertEquals '[{"name":"alice","age":3,"active":true,"empty":null},{"name":"bob, jr","age":4,"active":false,"empty":null}]' "$(printf '%s\n' 'data: |-' '  name,age,active,empty' '  alice,3,true,' '  "bob, jr",4,false,""' | ./ysh --json '.data | @csvd')"
    assertEquals '"a\t2\nx\t3"' "$(./ysh -n --json '[["a", 2], ["x", 3]] | @tsv')"
    assertEquals '[{"name":"alice","age":3}]' "$(printf 'data: |-\n  name\tage\n  alice\t3\n' | ./ysh --json '.data | @tsvd')"
    assertEquals '"thing"' "$(printf '%s\n' "$input" | ./ysh --json 'eval(.pathExp)')"
    assertContains "$(printf '%s\n' "$input" | ./ysh --json 'eval(".a.cool") = "changed"')" '"cool":"changed"'
    result=$(printf '%s\n' "$input" | ./ysh --security-disable-eval 'eval(.pathExp)' 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "dynamic eval is disabled"

    assertEquals '{"service":{"name":"loaded","ports":[80,443]}}' "$(./ysh -n --json "load(\"$load_yaml\")")"
    assertEquals '"plain text\nwith two lines\n"' "$(./ysh -n --json "load_str(\"$load_text\")")"
    assertEquals '"loaded secret"' "$(./ysh -n --json "load_base64(\"$load_base64\")")"
    assertEquals '{"service":{"name":"props","ports":["80","443"]}}' "$(./ysh -n --json "load_props(\"$load_props\")")"
    result=$(./ysh -n --security-disable-file-ops "load(\"$load_yaml\")" 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "file operations are disabled"

    for query in \
        '"%%%" | @base64d' \
        '"%GG" | @urid' \
        '"{\"a\":1,}" | from_json' \
        '"a: [one" | from_yaml' \
        '"a.b=one\na=two" | from_props' \
        '"a,b\n\"unterminated" | from_csv' \
        'eval("mystery")'; do
        result=$(./ysh -n "$query" 2>&1)
        assertNotEquals 0 $?
        assertContains "$result" 'Error:'
    done

    assertEquals '[3,5,4,1,2]' "$(./ysh -n --json --shuffle-seed 43 '[1,2,3,4,5] | shuffle')"
    assertEquals '[3,5,4,1,2]' "$(./ysh -n --json --shuffle-seed=43 '[1,2,3,4,5] | shuffle')"
    rm -f "$load_base64" "$load_props" "$load_text" "$load_yaml"
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

    input=$(printf '%s\n' 'root: {' '  alpha: one,' '  beta: [' '    two,' '    {gamma: three}' '  ]' '}')
    assertEquals '[[2,10],[3,9],[4,5],[5,13],[2,3],[5,6]]' "$(printf '%s\n' "$input" | ./ysh --json '[.root.alpha | [line, column], .root.beta | [line, column], .root.beta[0] | [line, column], .root.beta[1].gamma | [line, column], .root.alpha | key | [line, column], .root.beta[1].gamma | key | [line, column]]')"

    input=$(printf '%s\n' '# document' 'root:' '  # alpha head' '  alpha: one # alpha line' '  beta: two' '  # beta foot' '')
    assertEquals '["document","","alpha line","alpha head","beta foot"]' "$(printf '%s\n' "$input" | ./ysh --json '[. | head_comment, .root | foot_comment, .root.alpha | line_comment, .root.alpha | key | head_comment, .root.beta | key | foot_comment]')"

    input=$(printf '%s\n' 'root: [' '  one,' '  # two head' '  two,' '  {alpha: one,' '   # beta head' '   beta: two}' ']')
    assertEquals '["","two head","","beta head"]' "$(printf '%s\n' "$input" | ./ysh --json '[.root[0] | head_comment, .root[1] | head_comment, .root[2].alpha | key | head_comment, .root[2].beta | key | head_comment]')"
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
    assertEquals 0 $?
    assertEquals 3 "$(./ysh '.answer' "$first")"
    assertEquals 3 "$(./ysh '.answer' "$second")"
    ./ysh ea -i '.answer = 4' "$first" "$second" >/dev/null 2>&1
    assertEquals 0 $?
    assertEquals 4 "$(./ysh '.answer' "$first")"
    assertEquals 4 "$(./ysh '.answer' "$second")"
    rm -f "$first" "$second"
}

testMultipleInputEvaluationSkipsEmptyFilesWithoutLosingMetadata() {
    empty=$(mktemp "${TMPDIR:-/tmp}/ysh-empty.XXXXXX")
    populated=$(mktemp "${TMPDIR:-/tmp}/ysh-populated.XXXXXX")
    : > "$empty"
    printf '%s\n' 'answer: 2' > "$populated"
    expected=$(printf '["%s",1,0,2]' "$populated")
    assertEquals "$expected" "$(./ysh eval --json '[filename, fileIndex, documentIndex, .answer]' "$empty" "$populated")"
    rm -f "$populated" "$empty"
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
    assertEquals '{"a":1,"b":2,"c":3}' "$(./ysh ea --json '. as $document ireduce ({}; . * $document)' "$first" "$second")"
    rm -f "$first" "$second"
}

testWritableEvalAllSharesDataAcrossFiles() {
    source_file=test/.tmp-eval-all-source-$$.yml
    target_file=test/.tmp-eval-all-target-$$.yml
    report_file=test/.tmp-eval-all-report-$$.jsonl
    printf '%s\n' 'release: stable' > "$source_file"
    printf '%s\n' 'channel: edge # managed here' > "$target_file"
    query='select(fileIndex == 0).release as $release | select(fileIndex == 1).channel = $release'

    ./ysh ea --check --explain=json "$query" "$source_file" "$target_file" >/dev/null 2> "$report_file"
    assertEquals 1 $?
    assertEquals 'channel: edge # managed here' "$(cat "$target_file")"
    assertContains "$(sed -n '1p' "$report_file")" '"mutations":0'
    assertContains "$(sed -n '2p' "$report_file")" '"path":".channel"'

    ./ysh ea -i "$query" "$source_file" "$target_file"
    assertEquals 0 $?
    assertEquals 'release: stable' "$(cat "$source_file")"
    assertEquals 'channel: stable # managed here' "$(cat "$target_file")"

    rm -f "$report_file" "$target_file" "$source_file"
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

testInplaceTransactionAcrossFiles() {
    first_file=test/.tmp-inplace-transaction-first-$$.yml
    second_file=test/.tmp-inplace-transaction-second-$$.yml
    spaced_file="test/.tmp inplace transaction spaced $$.yml"
    invalid_file=test/.tmp-inplace-transaction-invalid-$$.yml
    explain_file=test/.tmp-inplace-transaction-explain-$$.jsonl
    printf '%s\n' 'name: first # keep one' > "$first_file"
    printf '%s\n' 'name: second # keep two' > "$second_file"
    printf '%s\n' 'name: spaced # keep three' > "$spaced_file"

    ./ysh -i --explain=json '.name = "ready"' "$first_file" "$second_file" "$spaced_file" 2> "$explain_file"
    assertEquals 0 $?
    assertEquals 'name: ready # keep one' "$(cat "$first_file")"
    assertEquals 'name: ready # keep two' "$(cat "$second_file")"
    assertEquals 'name: ready # keep three' "$(cat "$spaced_file")"
    assertEquals 3 "$(wc -l < "$explain_file" | tr -d ' ')"
    assertContains "$(sed -n '1p' "$explain_file")" '"presentation":"preserved"'
    assertContains "$(sed -n '1p' "$explain_file")" '"source_edits":1'
    assertContains "$(sed -n '2p' "$explain_file")" '"path":".name"'
    assertNotContains "$(cat "$explain_file")" '"ready"'
    if command -v jq >/dev/null 2>&1; then
        jq -e 'has("input") and has("changes") and (.changes[0].path == ".name")' "$explain_file" >/dev/null
        assertEquals 0 $?
    fi

    printf '%s\n' 'name: unchanged' > "$first_file"
    printf '%s\n' 'broken: [one' > "$invalid_file"
    ./ysh -i --explain=json '.name = "should-not-land"' "$first_file" "$invalid_file" >/dev/null 2> "$explain_file"
    assertNotEquals 0 $?
    assertEquals 'name: unchanged' "$(cat "$first_file")"
    assertNotContains "$(cat "$explain_file")" '"input"'

    ./ysh -i '.name = "duplicate"' "$first_file" "$first_file" >/dev/null 2>&1
    assertEquals 2 $?
    assertEquals 'name: unchanged' "$(cat "$first_file")"

    set -- "test/.$(basename "$first_file").ysh-new."* "test/.$(basename "$first_file").ysh-old."*
    assertFalse "transaction files must be removed" "[ -e \"$1\" ]"
    assertFalse "transaction files must be removed" "[ -e \"$2\" ]"
    rm -f "$explain_file" "$invalid_file" "$spaced_file" "$second_file" "$first_file"
}

testInplaceTransactionHandlesEmptyFilesAndSkipsNoOps() {
    empty_file=test/.tmp-inplace-empty-$$.yml
    unchanged_file=test/.tmp-inplace-unchanged-$$.yml
    state_file=test/.tmp-inplace-noop-state-$$
    : > "$empty_file"
    printf '%s\n' 'name: ready' > "$unchanged_file"
    real_mv=$(command -v mv)
    real_awk=$(command -v awk)

    PATH="$(pwd)/test/fault-bin:$PATH" YSH_REAL_AWK=$real_awk YSH_REAL_MV=$real_mv YSH_FAIL_MV_AT=1 YSH_MV_STATE=$state_file \
        ./ysh -i '.name = "ready"' "$empty_file" "$unchanged_file" >/dev/null 2>&1
    assertEquals 0 $?
    assertFalse "no-op transaction must not replace a file" "[ -e \"$state_file\" ]"
    assertEquals 0 "$(wc -c < "$empty_file" | tr -d ' ')"
    assertEquals 'name: ready' "$(cat "$unchanged_file")"

    rm -f "$state_file" "$unchanged_file" "$empty_file"
}

testCheckPreflightsRepositoryChanges() {
    first_file=test/.tmp-check-first-$$.yml
    second_file=test/.tmp-check-second-$$.yml
    invalid_file=test/.tmp-check-invalid-$$.yml
    report_file=test/.tmp-check-report-$$.jsonl
    printf '%s\n' 'name: ready' > "$first_file"
    printf '%s\n' 'name: waiting' > "$second_file"
    printf '%s\n' 'broken: [one' > "$invalid_file"

    result=$(./ysh --check '.name = "ready"' "$first_file" 2>&1)
    assertEquals 0 $?
    assertContains "$result" 'Check: no changes'

    result=$(./ysh --check '.name = "ready"' "$first_file" "$second_file" 2>&1)
    assertEquals 1 $?
    assertContains "$result" "Check: would change $second_file"
    assertContains "$result" '1 file(s) would change; no files written'
    assertEquals 'name: ready' "$(cat "$first_file")"
    assertEquals 'name: waiting' "$(cat "$second_file")"

    ./ysh --check --explain=json '.name = "ready"' "$first_file" "$second_file" >/dev/null 2> "$report_file"
    assertEquals 1 $?
    assertEquals 2 "$(wc -l < "$report_file" | tr -d ' ')"
    assertNotContains "$(cat "$report_file")" 'Check:'
    assertContains "$(sed -n '2p' "$report_file")" '"path":".name"'

    ./ysh --check '.name = "ready"' "$first_file" "$invalid_file" >/dev/null 2> "$report_file"
    assertEquals 2 $?
    assertContains "$(cat "$report_file")" 'transaction aborted before writing any files'
    assertEquals 'name: ready' "$(cat "$first_file")"

    ./ysh --check '.[' "$first_file" >/dev/null 2> "$report_file"
    assertEquals 2 $?

    rm -f "$report_file" "$invalid_file" "$second_file" "$first_file"
}

testDiffPreviewsExactRepositoryTransaction() {
    first_file=test/.tmp-diff-first-$$.yml
    second_file=test/.tmp-diff-second-$$.yml
    invalid_file=test/.tmp-diff-invalid-$$.yml
    diff_file=test/.tmp-diff-output-$$
    report_file=test/.tmp-diff-report-$$
    printf '%s\n' 'name: ready # keep one' > "$first_file"
    printf '%s\n' 'name: waiting # keep two' 'tail: kept' > "$second_file"
    printf '%s\n' 'broken: [one' > "$invalid_file"

    ./ysh --diff '.name = "ready"' "$first_file" > "$diff_file" 2> "$report_file"
    assertEquals 0 $?
    assertEquals 0 "$(wc -c < "$diff_file" | tr -d ' ')"

    ./ysh --diff '.name = "temporary" | .name = "ready"' "$first_file" > "$diff_file" 2> "$report_file"
    assertEquals 0 $?
    assertEquals 0 "$(wc -c < "$diff_file" | tr -d ' ')"

    ./ysh --diff --explain=json '.name = "temporary" | .name = "ready"' "$first_file" > "$diff_file" 2> "$report_file"
    assertEquals 0 $?
    assertContains "$(cat "$report_file")" '"changed":false'

    ./ysh --diff '.name = "ready"' "$first_file" "$second_file" > "$diff_file" 2> "$report_file"
    assertEquals 1 $?
    result=$(cat "$diff_file")
    assertContains "$result" "a/$second_file"
    assertContains "$result" "b/$second_file"
    printf '%s\n' "$result" | grep -F -- '-name: waiting # keep two' >/dev/null
    assertEquals 0 $?
    printf '%s\n' "$result" | grep -F -- '+name: ready # keep two' >/dev/null
    assertEquals 0 $?
    assertContains "$result" ' tail: kept'
    assertNotContains "$result" "$first_file"
    assertEquals 'name: waiting # keep two' "$(sed -n '1p' "$second_file")"

    ./ysh --diff --explain=json '.name = "ready"' "$first_file" "$second_file" > "$diff_file" 2> "$report_file"
    assertEquals 1 $?
    assertEquals 2 "$(wc -l < "$report_file" | tr -d ' ')"
    assertContains "$(sed -n '1p' "$report_file")" '"changed":false'
    assertContains "$(sed -n '2p' "$report_file")" '"changed":true'
    assertContains "$(sed -n '2p' "$report_file")" '"presentation":"preserved"'
    assertContains "$(sed -n '2p' "$report_file")" '"path":".name"'

    ./ysh --diff '.name = "ready"' "$first_file" "$invalid_file" > "$diff_file" 2> "$report_file"
    assertEquals 2 $?
    assertEquals 0 "$(wc -c < "$diff_file" | tr -d ' ')"
    assertContains "$(cat "$report_file")" 'transaction aborted before writing any files'

    ./ysh --diff -i '.name = "ready"' "$first_file" >/dev/null 2>&1
    assertEquals 2 $?
    ./ysh --diff -e '.name = "ready"' "$first_file" >/dev/null 2>&1
    assertEquals 2 $?

    rm -f "$report_file" "$diff_file" "$invalid_file" "$second_file" "$first_file"
}

testDiffReportsMissingFinalNewline() {
    diff_input=test/.tmp-diff-newline-$$.yml
    diff_output=test/.tmp-diff-newline-$$.out
    printf '%s' 'name: old' > "$diff_input"

    ./ysh --diff '.name = "new"' "$diff_input" > "$diff_output"
    assertEquals 1 $?
    grep -F -- '-name: old' "$diff_output" >/dev/null
    assertEquals 0 $?
    grep -F -- '+name: new' "$diff_output" >/dev/null
    assertEquals 0 $?
    grep -F -- '\ No newline at end of file' "$diff_output" >/dev/null
    assertEquals 0 $?
    assertEquals 9 "$(wc -c < "$diff_input" | tr -d ' ')"

    ./ysh --diff '.name = "temporary" | .name = "old"' "$diff_input" > "$diff_output"
    assertEquals 1 $?
    grep -F -- '-name: old' "$diff_output" >/dev/null
    assertEquals 0 $?
    grep -F -- '+name: old' "$diff_output" >/dev/null
    assertEquals 0 $?
    grep -F -- '\ No newline at end of file' "$diff_output" >/dev/null
    assertEquals 0 $?

    rm -f "$diff_output" "$diff_input"
}

testDiffSeparatesDistantHunks() {
    diff_input=test/.tmp-diff-hunks-$$.yml
    diff_output=test/.tmp-diff-hunks-$$.out
    printf '%s\n' 'a: old' 'b: keep' 'c: keep' 'd: keep' 'e: keep' 'f: keep' 'g: keep' 'h: keep' 'i: keep' 'j: old' > "$diff_input"

    ./ysh --diff '.a = "new" | .j = "new"' "$diff_input" > "$diff_output"
    assertEquals 1 $?
    assertEquals 2 "$(grep -c '^@@' "$diff_output")"
    grep -F -- '-a: old' "$diff_output" >/dev/null
    assertEquals 0 $?
    grep -F -- '+j: new' "$diff_output" >/dev/null
    assertEquals 0 $?
    assertEquals 'a: old' "$(sed -n '1p' "$diff_input")"
    assertEquals 'j: old' "$(sed -n '10p' "$diff_input")"

    rm -f "$diff_output" "$diff_input"
}

testPreserveOnlyRefusesRegeneration() {
    preserve_file=test/.tmp-preserve-only-$$.yml
    preserve_backup=test/.tmp-preserve-only-backup-$$.yml
    preserve_output=test/.tmp-preserve-only-output-$$
    preserve_error=test/.tmp-preserve-only-error-$$
    alias_file=test/.tmp-preserve-only-alias-$$.yml
    flow_file=test/.tmp-preserve-only-flow-$$.yml
    printf '%s\n' 'service:' '  name: api # keep' '  labels:' '    tier: web' 'items: # keep order' '  - one' 'tail: kept' > "$preserve_file"
    cp "$preserve_file" "$preserve_backup"

    ./ysh --preserve-only -i '.service.labels style = "flow"' "$preserve_file" > "$preserve_output" 2> "$preserve_error"
    assertEquals 2 $?
    assertContains "$(cat "$preserve_error")" 'preserve-only edit would regenerate YAML presentation'
    cmp -s "$preserve_backup" "$preserve_file"
    assertEquals 0 $?

    ./ysh --preserve-only --check '.service.labels style = "flow"' "$preserve_file" >/dev/null 2> "$preserve_error"
    assertEquals 2 $?
    ./ysh --preserve-only --diff '.service.labels style = "flow"' "$preserve_file" > "$preserve_output" 2> "$preserve_error"
    assertEquals 2 $?
    assertEquals 0 "$(wc -c < "$preserve_output" | tr -d ' ')"

    ./ysh --preserve-only -i '.service += {region: "west"} | .items += ["two"]' "$preserve_file"
    assertEquals 0 $?
    result=$(cat "$preserve_file")
    assertContains "$result" 'name: api # keep'
    assertContains "$result" 'region: "west"'
    assertContains "$result" '  - "two"'
    assertContains "$result" 'tail: kept'

    printf '%s\n' 'defaults: &defaults' '  retries: 3' 'service:' '  inherited: *defaults' > "$alias_file"
    ./ysh --preserve-only --diff '.service += {region: "west"}' "$alias_file" > "$preserve_output" 2> "$preserve_error"
    assertEquals 2 $?
    assertContains "$(cat "$preserve_error")" 'preserve-only edit would regenerate YAML presentation'
    assertContains "$(cat "$alias_file")" 'inherited: *defaults'

    printf '%s\n' 'meta: {enabled: false}' 'items: [{name: one, score: 4}]' 'tail: kept' > "$flow_file"
    ./ysh --preserve-only --diff '.meta.checked = true | .items |= map(.score += 1)' "$flow_file" > "$preserve_output" 2> "$preserve_error"
    assertEquals 1 $?
    assertEquals 0 "$(wc -c < "$preserve_error" | tr -d ' ')"
    assertContains "$(cat "$preserve_output")" '+meta: {"enabled": false, "checked": true}'
    assertContains "$(cat "$preserve_output")" '+items: [{"name": "one", "score": 5}]'
    ./ysh --preserve-only -i '.meta.checked = true | .items |= map(.score += 1)' "$flow_file"
    assertEquals 0 $?
    assertEquals '{"enabled":false,"checked":true}' "$(./ysh --json '.meta' "$flow_file")"
    assertEquals '[{"name":"one","score":5}]' "$(./ysh --json '.items' "$flow_file")"
    assertEquals kept "$(./ysh '.tail' "$flow_file")"

    ./ysh --preserve-only '.service.name = "worker"' "$preserve_file" >/dev/null 2>&1
    assertEquals 2 $?

    rm -f "$flow_file" "$alias_file" "$preserve_error" "$preserve_output" "$preserve_backup" "$preserve_file"
}

testInplaceTransactionRollsBackCommitFailure() {
    first_file=test/.tmp-inplace-rollback-first-$$.yml
    second_file=test/.tmp-inplace-rollback-second-$$.yml
    state_file=test/.tmp-inplace-rollback-state-$$
    report_file=test/.tmp-inplace-rollback-report-$$
    printf '%s\n' 'name: first' > "$first_file"
    printf '%s\n' 'name: second' > "$second_file"
    real_mv=$(command -v mv)
    real_awk=$(command -v awk)

    PATH="$(pwd)/test/fault-bin:$PATH" YSH_REAL_AWK=$real_awk YSH_REAL_MV=$real_mv YSH_FAIL_MV_AT=2 YSH_MV_STATE=$state_file \
        ./ysh -i --explain=json '.name = "changed"' "$first_file" "$second_file" >/dev/null 2> "$report_file"
    assertNotEquals 0 $?
    assertEquals 'name: first' "$(cat "$first_file")"
    assertEquals 'name: second' "$(cat "$second_file")"
    assertNotContains "$(cat "$report_file")" '"input"'

    rm -f "$report_file" "$state_file" "$second_file" "$first_file"
}

testInplaceTransactionRefusesEvaluationDrift() {
    target_file=test/.tmp-inplace-evaluation-drift-$$.yml
    report_file=test/.tmp-inplace-evaluation-drift-report-$$
    printf '%s\n' 'name: original' > "$target_file"
    real_awk=$(command -v awk)

    PATH="$(pwd)/test/fault-bin:$PATH" YSH_REAL_AWK=$real_awk \
        YSH_AWK_MUTATE_FILE=$target_file YSH_AWK_MUTATE_CONTENT='name: external' \
        ./ysh -i '.name = "candidate"' "$target_file" >/dev/null 2> "$report_file"
    assertNotEquals 0 $?
    assertEquals 'name: external' "$(cat "$target_file")"
    assertContains "$(cat "$report_file")" 'input changed during evaluation'
    assertContains "$(cat "$report_file")" 'no files written'

    set -- "test/.$(basename "$target_file").ysh-new."* "test/.$(basename "$target_file").ysh-snapshot."*
    assertFalse "transaction files must be removed" "[ -e \"$1\" ]"
    assertFalse "transaction files must be removed" "[ -e \"$2\" ]"
    rm -f "$report_file" "$target_file"
}

testInplaceTransactionRefusesCommitDriftAndRollsBack() {
    first_file=test/.tmp-inplace-commit-drift-first-$$.yml
    second_file=test/.tmp-inplace-commit-drift-second-$$.yml
    state_file=test/.tmp-inplace-commit-drift-state-$$
    report_file=test/.tmp-inplace-commit-drift-report-$$
    printf '%s\n' 'name: first' > "$first_file"
    printf '%s\n' 'name: second' > "$second_file"
    real_mv=$(command -v mv)
    real_awk=$(command -v awk)

    PATH="$(pwd)/test/fault-bin:$PATH" YSH_REAL_AWK=$real_awk YSH_REAL_MV=$real_mv YSH_MV_STATE=$state_file \
        YSH_MUTATE_AFTER_MV_AT=1 YSH_MUTATE_FILE=$second_file YSH_MUTATE_CONTENT='name: external' \
        ./ysh -i '.name = "candidate"' "$first_file" "$second_file" >/dev/null 2> "$report_file"
    assertNotEquals 0 $?
    assertEquals 'name: first' "$(cat "$first_file")"
    assertEquals 'name: external' "$(cat "$second_file")"
    assertContains "$(cat "$report_file")" 'changed before replacement'

    rm -f "$report_file" "$state_file" "$second_file" "$first_file"
}

testInplaceTransactionKeepsLogicalFilenamesAndRejectsAliases() {
    target_file=test/.tmp-inplace-logical-file-$$.yml
    alias_file=./test/../test/.tmp-inplace-logical-file-$$.yml
    printf '%s\n' 'name: original' > "$target_file"

    ./ysh -i '.source = filename' "$target_file"
    assertEquals 0 $?
    assertEquals "$target_file" "$(./ysh '.source' "$target_file")"

    result=$(./ysh -i '.name = "duplicate"' "$target_file" "$alias_file" 2>&1)
    assertEquals 2 $?
    assertContains "$result" 'same input more than once'
    assertEquals original "$(./ysh '.name' "$target_file")"

    rm -f "$target_file"
}

testInplaceTransactionRejectsNewlineFilenames() {
    target_file=$(printf 'test/.tmp-inplace-newline-%s\ncontinued.yml' "$$")
    printf '%s\n' 'name: original' > "$target_file"

    result=$(./ysh -i '.name = "candidate"' "$target_file" 2>&1)
    assertEquals 2 $?
    assertContains "$result" 'does not support newlines in filenames'
    assertEquals 'name: original' "$(cat "$target_file")"

    rm -f "$target_file"
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

testInplaceEditsPresentationMetadata() {
    inplace_file=test/.tmp-inplace-metadata-$$.yml
    printf '%s\n' 'service:' '  name: api # old comment' '  labels:' '    tier: web' > "$inplace_file"
    ./ysh -i '.service.name line_comment = "release managed" | .service.name style = "double"' "$inplace_file"
    assertEquals 0 $?
    assertContains "$(cat "$inplace_file")" 'name: "api" # release managed'

    ./ysh -i '.service.labels style = "flow"' "$inplace_file"
    assertEquals 0 $?
    assertContains "$(cat "$inplace_file")" '"labels": {"tier": "web"}'

    printf '%s\n' 'before: x' 'a: value' 'items:' '  - one' '  - two' 'after: z' > "$inplace_file"
    ./ysh --preserve-only -i \
        '.a head_comment = "value head" | (.a | key) head_comment = "key head" | .a foot_comment = "value foot" | .items[0] head_comment = "item head"' \
        "$inplace_file"
    assertEquals 0 $?
    result=$(cat "$inplace_file")
    assertContains "$result" '# key head'
    assertContains "$result" '# value head'
    assertContains "$result" '# value foot'
    assertContains "$result" '  # item head'

    printf '%s\n' 'before: x' '# old key' 'a: value' '# old key foot' '' 'items:' '  # old item head' '  - one' '  # old item foot' '' '  - two' > "$inplace_file"
    ./ysh --preserve-only -i \
        '(.a | key) head_comment = "changed key" | (.a | key) foot_comment = "" | .items[0] head_comment = "changed item" | .items[0] foot_comment = ""' \
        "$inplace_file"
    assertEquals 0 $?
    result=$(cat "$inplace_file")
    assertContains "$result" '# changed key'
    assertContains "$result" '  # changed item'
    assertNotContains "$result" '# old key'
    assertNotContains "$result" '# old item'
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

testInplacePreservesIndentlessSequenceMaps() {
    inplace_file=test/.tmp-inplace-indentless-$$.yml
    printf '%s\n' 'meta:' '  enabled: false' 'items:' '- name: first' '  score: 4' '- name: second' '  score: 8' 'tail: kept' > "$inplace_file"

    ./ysh --preserve-only -i '.meta.checked = true | .items |= map(.score += 1)' "$inplace_file"
    assertEquals 0 $?
    expected=$(printf '%s\n' 'meta:' '  enabled: false' '  checked: true' 'items:' '- name: first' '  score: 5' '- name: second' '  score: 9' 'tail: kept')
    assertEquals "$expected" "$(cat "$inplace_file")"

    ./ysh --preserve-only -i '.items += [{name: "third", score: 12}]' "$inplace_file"
    assertEquals 0 $?
    assertEquals 1 "$(grep -c 'name: first' "$inplace_file")"
    assertEquals 1 "$(grep -c 'name: second' "$inplace_file")"
    assertEquals 3 "$(./ysh '.items | length' "$inplace_file")"
    assertEquals third "$(./ysh '.items[2].name' "$inplace_file")"
    assertEquals 'tail: kept' "$(tail -1 "$inplace_file")"

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

testInplaceCompilesOwnedMultilineSourceEdits() {
    inplace_file=test/.tmp-inplace-owned-spans-$$.yml
    expected_file=test/.tmp-inplace-owned-spans-expected-$$.yml
    diff_file=test/.tmp-inplace-owned-spans-diff-$$
    printf '%s\n' \
        'meta: {' \
        '  enabled: false,' \
        '  labels: [one, two]' \
        '} # flow tail' \
        'title: "old' \
        '  value" # quoted tail' \
        'note: |- # block tail' \
        '  old line' \
        '  second' \
        'after: kept' > "$inplace_file"
    printf '%s\n' \
        'meta: {"enabled": true, "labels": ["one", "two", "three"]} # flow tail' \
        'title: "new value" # quoted tail' \
        'note: |- # block tail' \
        '  new line' \
        '  second new' \
        'after: kept' > "$expected_file"

    ./ysh --preserve-only --diff \
        '.meta.enabled = true | .meta.labels += ["three"] | .note = "new line\nsecond new" | .title = "new value"' \
        "$inplace_file" > "$diff_file"
    assertEquals 1 $?
    assertContains "$(cat "$diff_file")" '+meta: {"enabled": true, "labels": ["one", "two", "three"]} # flow tail'
    assertContains "$(cat "$diff_file")" '+  new line'
    assertContains "$(cat "$diff_file")" '+title: "new value" # quoted tail'
    assertContains "$(cat "$inplace_file")" 'enabled: false'

    ./ysh --preserve-only -i \
        '.meta.enabled = true | .meta.labels += ["three"] | .note = "new line\nsecond new" | .title = "new value"' \
        "$inplace_file"
    assertEquals 0 $?
    assertEquals "$(cat "$expected_file")" "$(cat "$inplace_file")"
    assertEquals kept "$(./ysh '.after' "$inplace_file")"

    commented_flow=test/.tmp-inplace-commented-flow-$$.yml
    commented_backup=test/.tmp-inplace-commented-flow-backup-$$.yml
    printf '%s\n' 'meta: {' '  # attached inside flow' '  enabled: false' '}' 'after: kept' > "$commented_flow"
    cp "$commented_flow" "$commented_backup"
    ./ysh --preserve-only --diff '.meta.enabled = true' "$commented_flow" > "$diff_file" 2>/dev/null
    assertEquals 2 $?
    assertEquals 0 "$(wc -c < "$diff_file" | tr -d ' ')"
    cmp -s "$commented_backup" "$commented_flow"
    assertEquals 0 $?

    rm -f "$commented_backup" "$commented_flow" "$diff_file" "$expected_file" "$inplace_file"
}

testInplaceMovesAndDeletesOwnedRecordSpans() {
    inplace_file=test/.tmp-inplace-record-spans-$$.yml
    expected_file=test/.tmp-inplace-record-spans-expected-$$.yml
    printf '%s\n' \
        'settings: # header' \
        '  # zed setting' \
        '  z: 1' \
        '  # alpha setting' \
        '  a:' \
        '    nested: yes' \
        'items:' \
        '  # first record' \
        '  - name: one' \
        '    score: 1' \
        '  # second record' \
        '  - name: two' \
        '    score: 2' \
        'tail: kept' > "$inplace_file"
    printf '%s\n' \
        'settings: # header' \
        '  # alpha setting' \
        '  a:' \
        '    nested: yes' \
        '  # zed setting' \
        '  z: 1' \
        'items:' \
        '  # second record' \
        '  - name: two' \
        '    score: 2' \
        'tail: kept' > "$expected_file"

    ./ysh --preserve-only -i '.settings = sort_keys(.settings) | del(.items[0])' "$inplace_file"
    assertEquals 0 $?
    assertEquals "$(cat "$expected_file")" "$(cat "$inplace_file")"

    rm -f "$expected_file" "$inplace_file"
}

testInplacePreservesAliasAndMergeSourceOwnership() {
    inplace_file=test/.tmp-inplace-shared-source-$$.yml
    printf '%s\n' \
        'defaults: &defaults {retries: 3, mode: safe} # source owner' \
        'service:' \
        '  <<: *defaults # merge stays' \
        '  inherited: *defaults # alias stays' \
        'tail: kept' > "$inplace_file"

    ./ysh --preserve-only -i '.service.inherited.retries = 5 | .service.mode = "strict"' "$inplace_file"
    assertEquals 0 $?
    result=$(cat "$inplace_file")
    assertContains "$result" 'defaults: &defaults {"retries": 5, "mode": "strict"} # source owner'
    assertContains "$result" '<<: *defaults # merge stays'
    assertContains "$result" 'inherited: *defaults # alias stays'
    assertContains "$result" 'tail: kept'
    assertEquals '{"retries":5,"mode":"strict"}' "$(./ysh --json '.service.inherited' "$inplace_file")"

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

    for query in now 'load_xml("neighbor.xml")'; do
        result=$(./ysh -n "$query" 2>&1)
        assertNotEquals 0 $?
        assertContains "$result" "unknown expression operator"
    done
    for query in from_xml @xmld; do
        result=$(./ysh -n "$query" 2>&1)
        assertNotEquals 0 $?
        assertContains "$result" 'expected XML element'
    done
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

testExpressionYamlGraphOperators() {
    assertEquals "defaults" "$(./ysh '.defaults | anchor' test/workflows/deployment.yml)"
    assertEquals "defaults" "$(./ysh '.shared | alias' test/workflows/deployment.yml)"
    assertEquals "" "$(./ysh '.shared | anchor' test/workflows/deployment.yml)"
    assertEquals "" "$(./ysh '.defaults | alias' test/workflows/deployment.yml)"
    assertEquals '["us-west-2","us-west-2"]' "$(./ysh --json 'explode(.) | [.shared.region, .production.region]' test/workflows/deployment.yml)"
    assertEquals "" "$(./ysh 'explode(.) | .shared | alias' test/workflows/deployment.yml)"
}

testExpressionWritableYamlGraphMetadata() {
    graph_file=test/.tmp-graph-metadata-$$.yml
    printf '%s\n' 'source: &old one' 'copy: *old' 'target: two' > "$graph_file"

    result=$(./ysh -o=yaml '.source anchor = "current" | .source tag = "!!str" | .target alias = "current"' "$graph_file")
    assertEquals 0 $?
    assertEquals 'current' "$(printf '%s\n' "$result" | ./ysh '.source | anchor')"
    assertEquals 'current' "$(printf '%s\n' "$result" | ./ysh '.copy | alias')"
    assertEquals 'current' "$(printf '%s\n' "$result" | ./ysh '.target | alias')"
    assertEquals '!!str' "$(printf '%s\n' "$result" | ./ysh '.source | tag')"
    assertEquals '{"source":"one","copy":"one","target":"one"}' "$(printf '%s\n' "$result" | ./ysh --json '.')"

    ./ysh -i '.source anchor = "current" | .source tag = "!!str" | .target alias = "current"' "$graph_file"
    assertEquals 0 $?
    assertEquals '{"source":"one","copy":"one","target":"one"}' "$(./ysh --json '.' "$graph_file")"
    assertEquals 'current' "$(./ysh '.copy | alias' "$graph_file")"

    result=$(./ysh -o=yaml '.source anchor = ""' "$graph_file" 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" 'aliases still reference it'

    result=$(printf '%s\n' 'first: one' 'later: &later two' | ./ysh -o=yaml '.first alias = "later"' 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" 'forward alias'
    rm -f "$graph_file"
}

testExpressionPresentationMetadata() {
    assertEquals "promoted by CI" "$(./ysh '.spec.template.spec.containers[0].image | line_comment' test/workflows/kubernetes.yml)"
    assertEquals "double" "$(./ysh '.metadata.annotations["deployment.kubernetes.io/revision"] | style' test/workflows/kubernetes.yml)"
    assertEquals "flow" "$(./ysh '.on.push.branches | style' test/workflows/github-actions.yml)"
    assertEquals "" "$(./ysh '.spec.replicas | style' test/workflows/kubernetes.yml)"
    styles=$(printf '%s\n' "single: 'one'" 'double: "two"' 'literal: |-' '  three' 'folded: >' '  four' | \
        ./ysh '.single | style, .double | style, .literal | style, .folded | style')
    assertEquals "$(printf '%s\n' single double literal folded)" "$styles"
    assertEquals '"new note"' "$(printf '%s\n' 'name: api # old' | ./ysh --json '.name line_comment = "new note" | .name | line_comment')"
    assertEquals '"single"' "$(printf '%s\n' 'name: api' | ./ysh --json '.name style = "single" | .name | style')"
    assertEquals '"items": ["one", "two"]' "$(printf '%s\n' 'items: [one, two]' | ./ysh -o yaml '.items style = "flow"')"
}

testExpressionBlockStylesAndOutputControls() {
    literal=$(printf '%s\n' 'value: one' | ./ysh -o=yaml '.value = "hello\nworld" | .value style = "literal"')
    folded=$(printf '%s\n' 'value: one' | ./ysh -o=yaml '.value = "hello\nworld" | .value style = "folded"')
    assertContains "$literal" '|-'
    assertContains "$folded" '>-'
    assertEquals '"hello\nworld"' "$(printf '%s\n' "$literal" | ./ysh --json '.value')"
    assertEquals '"hello\nworld"' "$(printf '%s\n' "$folded" | ./ysh --json '.value')"

    result=$(printf '%s\n' 'root:' '  child: value' | ./ysh -I4 -o=yaml '.')
    assertContains "$result" '    "child": "value"'
    assertEquals '"Things" # note' "$(printf '%s\n' 'value: "Things" # note' | ./ysh --unwrap-scalar=false '.value')"

    style_file=test/.tmp-block-style-$$.yml
    printf '%s\n' 'value: one # note' > "$style_file"
    ./ysh -i '.value = "hello\nworld" | .value style = "folded"' "$style_file"
    assertEquals 0 $?
    assertEquals '"hello\nworld"' "$(./ysh --json '.value' "$style_file")"
    assertEquals 'folded' "$(./ysh '.value | style' "$style_file")"
    rm -f "$style_file"
}

testExplainSelectionsAndMutations() {
    explain_out=test/.tmp-explain-out-$$
    explain_err=test/.tmp-explain-err-$$

    ./ysh --explain '.metadata.name' test/workflows/kubernetes.yml > "$explain_out" 2> "$explain_err"
    assertEquals 0 $?
    assertEquals "storefront" "$(cat "$explain_out")"
    result=$(cat "$explain_err")
    assertContains "$result" 'documents=1 parsed_nodes='
    assertContains "$result" 'results=1 mutations=0 replacements=0 insertions=0 deletions=0 presentation=not-requested'

    ./ysh --explain '.metadata.channel = "stable" | del(.metadata.annotations["deployment.kubernetes.io/revision"])' \
        test/workflows/kubernetes.yml > "$explain_out" 2> "$explain_err"
    assertEquals 0 $?
    result=$(cat "$explain_err")
    assertContains "$result" 'mutations=2 replacements=0 insertions=1 deletions=1'
    assertContains "$result" 'Explain: insert .metadata.channel'
    assertContains "$result" 'Explain: delete .metadata.annotations["deployment.kubernetes.io/revision"]'
    assertNotContains "$result" 'stable'

    ./ysh --explain '.metadata.name style = ""' test/workflows/kubernetes.yml > "$explain_out" 2> "$explain_err"
    assertEquals 0 $?
    assertContains "$(cat "$explain_err")" 'mutations=0 replacements=0 insertions=0 deletions=0'

    rm -f "$explain_out" "$explain_err"
}

testExplainPresentationDecision() {
    explain_file=test/.tmp-explain-inplace-$$.yml
    explain_err=test/.tmp-explain-inplace-$$.err
    cp test/workflows/kubernetes.yml "$explain_file"

    ./ysh -i --explain '(.spec.template.spec.containers[] | select(.name == "api") | .image) = "ghcr.io/example/api:1.5.0"' \
        "$explain_file" 2> "$explain_err"
    assertEquals 0 $?
    result=$(cat "$explain_err")
    assertContains "$result" 'presentation=preserved'
    assertContains "$result" 'Explain: replace .spec.template.spec.containers[0].image'
    assertContains "$(cat "$explain_file")" '# promoted by CI'

    ./ysh -i --explain '(.spec.template.spec.containers[] | select(.name == "metrics") | .env) += [{"name":"FEATURE_FLAG","value":"true"}]' \
        "$explain_file" 2> "$explain_err"
    assertEquals 0 $?
    result=$(cat "$explain_err")
    assertContains "$result" 'presentation=preserved'
    assertContains "$result" 'source_edits=1'
    assertContains "$result" 'Explain: replace .spec.template.spec.containers[1].env'

    rm -f "$explain_file" "$explain_err"
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

testConfigurationPointersAndPatches() {
    input=$(printf '%s\n' 'a/b: tilde' 'items: [one, two]' 'object:' '  keep: 1' '  remove: true')

    assertEquals '"tilde"' "$(printf '%s\n' "$input" | ./ysh --json 'pointer("/a~1b")')"
    assertEquals '"two"' "$(printf '%s\n' "$input" | ./ysh --json '.items[1] | root | pointer("/items/1")')"
    assertEquals '"aml.s"' "$(printf '%s\n' 'name: yaml.sh' | ./ysh --json '.name[1:-1]')"

    patch='[{op:"test",path:"/object/keep",value:1},{op:"replace",path:"/object/keep",value:2},{op:"copy",from:"/object/keep",path:"/object/copied"},{op:"move",from:"/items/0",path:"/items/1"},{op:"remove",path:"/object/remove"},{op:"add",path:"/items/-",value:"three"}]'
    assertEquals '{"a/b":"tilde","items":["two","one","three"],"object":{"keep":2,"copied":2}}' \
        "$(printf '%s\n' "$input" | ./ysh --json "apply_patch($patch)")"

    assertEquals '{"items":["one","two"],"object":{"keep":3,"added":true}}' \
        "$(printf '%s\n' "$input" | ./ysh --json 'merge_patch({"a/b":null,object:{keep:3,remove:null,added:true}})')"

    target='{items:["one","two"],object:{keep:4},added:true}'
    generated=$(printf '%s\n' "$input" | ./ysh --json "diff_patch($target)")
    assertEquals '[{"op":"remove","path":"/a~1b"},{"op":"remove","path":"/object/remove"},{"op":"replace","path":"/object/keep","value":4},{"op":"add","path":"/added","value":true}]' "$generated"
    assertEquals '{"items":["one","two"],"object":{"keep":4},"added":true}' \
        "$(printf '%s\n' "$input" | ./ysh --json "diff_patch($target) as \$patch | apply_patch(\$patch)")"

    result=$(printf '%s\n' "$input" | ./ysh 'apply_patch([{op:"test",path:"/object/keep",value:9}])' 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "JSON Patch test failed"
    result=$(printf '%s\n' "$input" | ./ysh 'pointer("missing")' 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "must be empty or start with /"
}

testConfigurationPatchSourceEdits() {
    patch_file=test/.tmp-config-patch-$$.yml
    printf '%s\n' 'service:' '  name: api # keep this' '  obsolete: true' > "$patch_file"

    ./ysh --preserve-only -i \
        'apply_patch([{op:"replace",path:"/service/name",value:"worker"},{op:"remove",path:"/service/obsolete"},{op:"add",path:"/service/enabled",value:true}])' \
        "$patch_file"
    assertEquals "service:
  name: worker # keep this
  enabled: true" "$(cat "$patch_file")"

    rm -f "$patch_file"
}

testConfigurationSchemaContracts() {
    schema='{"$defs":{port:{type:"integer",minimum:1,maximum:65535}},type:"object",required:["name","port"],properties:{name:{type:"string",minLength:3,pattern:"^[a-z]+$"},port:{"$ref":"#/$defs/port"},tags:{type:"array",items:{type:"string"},uniqueItems:true,minItems:1},mode:{oneOf:[{const:"api"},{const:"worker"}]}},dependentRequired:{mode:["tags"]},additionalProperties:false}'
    valid=$(printf '%s\n' 'name: service' 'port: 8080' 'tags: [web, stable]' 'mode: api')
    invalid=$(printf '%s\n' 'name: X' 'port: 70000' 'tags: [web, web]' 'mode: other' 'extra: true')

    assertEquals 'true' "$(printf '%s\n' "$valid" | ./ysh --json "schema_valid($schema)")"
    assertEquals '{"name":"service","port":8080,"tags":["web","stable"],"mode":"api"}' \
        "$(printf '%s\n' "$valid" | ./ysh --json "validate($schema)")"
    errors=$(printf '%s\n' "$invalid" | ./ysh --json "schema_errors($schema)")
    assertContains "$errors" '"instancePath":"/name"'
    assertContains "$errors" '"schemaPath":"#/$defs/port/maximum"'
    assertContains "$errors" '"keyword":"uniqueItems"'
    assertContains "$errors" '"keyword":"oneOf"'
    assertContains "$errors" '"keyword":"additionalProperties"'
    assertEquals 'false' "$(printf '%s\n' "$invalid" | ./ysh --json "schema_valid($schema)")"

    collection_schema='{type:"object",patternProperties:{"^x-":{type:"string"}},additionalProperties:false,properties:{values:{type:"array",contains:{type:"integer",minimum:10},minContains:2,maxContains:3}}}'
    errors=$(printf '%s\n' 'x-name: 3' 'values: [10, 2]' | ./ysh --json "schema_errors($collection_schema)")
    assertContains "$errors" '"schemaPath":"#/patternProperties/^x-/type"'
    assertContains "$errors" '"keyword":"contains"'

    assertEquals 'true' "$(printf '%s\n' 'value: {kind: service, port: 8080}' 'schema: {if: {properties: {kind: {const: service}}}, then: {required: [port]}, else: {required: [path]}}' | ./ysh --json '.value | schema_valid(root.schema)')"
    assertEquals 'false' "$(printf '%s\n' 'value: {bad-key: 1}' 'schema: {propertyNames: {pattern: "^[a-z]+$"}}' | ./ysh --json '.value | schema_valid(root.schema)')"
    assertEquals 'false' "$(printf '%s\n' 'value: {card: true}' 'schema: {dependentSchemas: {card: {required: [billing]}}}' | ./ysh --json '.value | schema_valid(root.schema)')"

    result=$(printf '%s\n' "$invalid" | ./ysh "validate($schema)" 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" 'schema validation failed at /name'
    result=$(printf '%s\n' 'value: 1' | ./ysh 'schema_valid({"$ref":"https://example.com/schema"})' 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" 'local $ref values only'
    result=$(printf '%s\n' 'value: 1' | ./ysh 'schema_valid({unevaluatedProperties:false})' 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" 'outside the focused profile'
}

testConfigurationFormatCodecs() {
    toml='title = "yaml.sh"
enabled = true
ports = [80, 443]
"key=part" = "safe"
multiline = """hash # stays
second line""" # comment
[owner]
name = "Justin"
[database.settings]
retries = 3
[[servers]]
name = "alpha"
[[servers]]
name = "beta"'
    decoded=$(printf '%s\n' 'document: |' "$(printf '%s\n' "$toml" | sed 's/^/  /')" | ./ysh --json '.document | from_toml')
    assertEquals '{"title":"yaml.sh","enabled":true,"ports":[80,443],"key=part":"safe","multiline":"hash # stays\nsecond line","owner":{"name":"Justin"},"database":{"settings":{"retries":3}},"servers":[{"name":"alpha"},{"name":"beta"}]}' "$decoded"
    encoded=$(printf '%s\n' "$decoded" | ./ysh -r 'to_toml')
    assertEquals "$decoded" "$(printf '%s\n' 'document: |' "$(printf '%s' "$encoded" | sed 's/^/  /')" | ./ysh --json '.document | from_toml')"

    ini='name = yaml.sh
[database]
host = "localhost"
[database.pool]
size = 4'
    assertEquals '{"name":"yaml.sh","database":{"host":"localhost","pool":{"size":"4"}}}' \
        "$(printf '%s\n' 'document: |' "$(printf '%s\n' "$ini" | sed 's/^/  /')" | ./ysh --json '.document | from_ini')"
    assertContains "$(printf '%s\n' 'name: yaml.sh' 'database:' '  host: localhost' | ./ysh -r 'to_ini')" '[database]'

    xml='<root id="7"><name>yaml.sh</name><item>a</item><item>b</item><![CDATA[tail]]></root>'
    assertEquals '{"root":{"+@id":"7","name":"yaml.sh","item":["a","b"],"+content":"tail"}}' \
        "$(printf '%s\n' "xml: '$xml'" | ./ysh --json '.xml | from_xml')"
    assertEquals '<root id="7">tail<name>yaml.sh</name><item>a</item><item>b</item></root>' \
        "$(printf '%s\n' "xml: '$xml'" | ./ysh -r '.xml | from_xml | to_xml')"
    assertEquals '<root><empty/></root>' \
        "$(printf '%s\n' "xml: '<root><empty/></root>'" | ./ysh -r '.xml | from_xml | to_xml')"

    result=$(printf '%s\n' "xml: '<!DOCTYPE root [<!ENTITY x SYSTEM \"file:///etc/passwd\">]><root>&x;</root>'" | ./ysh '.xml | from_xml' 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" 'DTDs and entity declarations are disabled'

    result=$(printf '%s\n' "xml: '<root>&#1;</root>'" | ./ysh '.xml | from_xml' 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" 'invalid XML character reference'

    result=$(printf '%s\n' '"bad<name": value' | ./ysh 'to_xml' 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" 'invalid XML element name'
}

testConfigurationCliContracts() {
    prefix=test/.tmp-config-cli-$$
    toml_file=$prefix.toml
    schema_file=$prefix.schema.json
    patch_file=$prefix.patch.json
    merge_file=$prefix.merge.json
    target_file=$prefix.target.yml
    yaml_file=$prefix.yml
    printf '%s\n' 'title = "yaml.sh"' '[service]' 'port = 8080' > "$toml_file"
    printf '%s\n' '{"type":"object","required":["service"],"properties":{"service":{"type":"object","required":["port"],"properties":{"port":{"type":"integer","minimum":1,"maximum":65535}}}}}' > "$schema_file"
    printf '%s\n' '[{"op":"replace","path":"/service/port","value":9090},{"op":"add","path":"/service/enabled","value":true}]' > "$patch_file"
    printf '%s\n' '{"service":{"port":7070,"enabled":true}}' > "$merge_file"
    printf '%s\n' 'service:' '  port: 6060' '  enabled: true' > "$target_file"
    printf '%s\n' 'service:' '  port: 8080 # keep' > "$yaml_file"

    assertEquals '8080' "$(./ysh --json '.service.port' "$toml_file")"
    assertContains "$(./ysh -p toml -o toml '.' "$toml_file")" '[service]'
    assertEquals '{"service":{"port":8080}}' "$(./ysh --json --schema "$schema_file" '.' "$yaml_file")"
    assertEquals '{"service":{"port":8080}}' "$(./ysh --security-disable-file-ops --json --schema "$schema_file" '.' "$yaml_file")"
    assertEquals '{"service":{"port":9090,"enabled":true}}' "$(./ysh --json --apply-patch "$patch_file" '.' "$yaml_file")"
    assertEquals '{"service":{"port":7070,"enabled":true}}' "$(./ysh --json --merge-patch "$merge_file" '.' "$yaml_file")"
    assertEquals '[{"op":"replace","path":"/service/port","value":6060},{"op":"add","path":"/service/enabled","value":true}]' \
        "$(./ysh --json --generate-patch "$target_file" '.' "$yaml_file")"

    ./ysh --preserve-only -i --apply-patch "$patch_file" '.' "$yaml_file"
    assertEquals "service:
  port: 9090 # keep
  enabled: true" "$(cat "$yaml_file")"

    printf '%s\n' 'service:' '  port: 70000' > "$yaml_file"
    result=$(./ysh --schema "$schema_file" '.' "$yaml_file" 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" 'schema validation failed at /service/port'

    rm -f "$toml_file" "$schema_file" "$patch_file" "$merge_file" "$target_file" "$yaml_file"
}

testCliErrors() {
    ./ysh ".key" does-not-exist.yml >/dev/null 2>&1
    assertEquals 1 $?
    ./ysh --document nope ".key" test/test.yml >/dev/null 2>&1
    assertEquals 2 $?
    ./ysh --output bogus ".key" test/test.yml >/dev/null 2>&1
    assertEquals 2 $?
    ./ysh --unknown ".key" test/test.yml >/dev/null 2>&1
    assertEquals 2 $?
    ./ysh -i '.key = "value"' </dev/null >/dev/null 2>&1
    assertEquals 2 $?
    ./ysh -i -n '.key = "value"' test/test.yml >/dev/null 2>&1
    assertEquals 2 $?
    result=$(PATH=/nonexistent ./ysh --check '.key = "value"' test/test.yml 2>&1)
    assertEquals 2 $?
    assertContains "$result" "edit transactions require command: mktemp"
}

testRunsWithPosixShell() {
    assertEquals "value" "$(/bin/sh ./ysh ".key_value.key" test/test.yml)"
}

testReleaseArtifactsStayInSync() {
    if command -v sha256sum >/dev/null 2>&1; then
        release_sha256=$(sha256sum ysh)
    else
        release_sha256=$(shasum -a 256 ysh)
    fi
    release_sha256=${release_sha256%% *}
    assertContains "$(cat _static/_www/install)" "v1.17.1/ysh"
    assertContains "$(cat _static/_www/install)" "expected_sha256=$release_sha256"
    assertContains "$(cat _static/_www/install)" "checksum verification failed"
    assertContains "$(cat _static/_www/index.html)" "data-ysh-version>v1.17.1"
    assertContains "$(cat _static/_www/story/index.html)" "One POSIX shell file"
    assertNotContains "$(cat _static/_www/story/index.html)" "story-timeline"
    assertNotContains "$(cat _static/_www/story/index.html)" "releases/tag/"
    assertNotContains "$(cat _static/_www/story/index.html)" "YAML.sh v1.17"
    assertNotContains "$(cat _static/_www/index.html)" "class=\"cursor\""
    assertNotContains "$(cat _static/_www/index.html)" "A real parser this time"
    assertNotContains "$(cat _static/_www/css/style.css)" "transform: rotate(1.25deg)"
    assertContains "$(cat _static/_www/docs/index.html)" "/docs/docs.css"
    assertContains "$(cat _static/_www/docs/index.html)" "/docs/docs.js"
    assertNotContains "$(cat _static/_www/docs/index.html)" "docsify"
    assertContains "$(cat README.md)" "brand/hero.svg"
    assertContains "$(cat _static/_www/index.html)" "og.png"
    assertNotContains "$(cat README.md)" "og-v1.8.png"
    assertTrue "evergreen social preview image must exist" "[ -s _static/_www/og.png ]"
    assertTrue "evergreen SVG hero must exist" "[ -s _static/_www/brand/hero.svg ]"
    assertContains "$(cat _static/_www/docs/operators.md)" "# Operator reference"
    assertContains "$(cat _static/_www/docs/operators.md)" "array_to_map"
    assertContains "$(cat _static/_www/docs/operators.md)" "split_doc"
    assertNotContains "$(cat _static/_www/docs/operators.md)" "testExpression"
    assertContains "$(cat _static/_www/docs/contracts.md)" "# Validate, patch & convert"
    assertContains "$(cat _static/_www/docs/supported_yml.md)" "# YAML support"
    assertNotContains "$(cat _static/_www/docs/supported_yml.md)" "Date/time, XML"
    operator_tab=$(printf '\t')
    assertContains "$(cat test/operator-manifest.tsv)" "operator${operator_tab}Array to map${operator_tab}supported"
    assertContains "$(cat test/operator-manifest.tsv)" "operator${operator_tab}Split into documents${operator_tab}focused"
    assertNotContains "$(cat _static/_www/index.html)" "35/35"
    assertNotContains "$(cat README.md)" "35/35"
}

# shellcheck source=/dev/null
. ./test/shunit2
