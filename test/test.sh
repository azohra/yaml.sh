#!/bin/sh

testVersion() {
    assertEquals "v1.2.0" "$(./ysh --version)"
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
}

testBlockScalars() {
    assertEquals "$(printf "This value\ncan span multiple lines")" "$(./ysh ".literal" test/issues.yml)"
    assertEquals "This value folds onto one line" "$(./ysh ".folded" test/issues.yml)"
}

testBlockAndIndentlessSequences() {
    assertEquals '["item1","item2"]' "$(./ysh ".indented" test/issues.yml)"
    assertEquals '["item1","item2"]' "$(./ysh ".indentless" test/issues.yml)"
    assertEquals "ten" "$(./ysh ".long_list[10]" test/issues.yml)"
}

testScalarAndCollectionAliases() {
    assertEquals "hello" "$(./ysh ".scalar_alias" test/advanced.yml)"
    assertEquals "true" "$(./ysh ".mapping_alias.nested.enabled" test/advanced.yml)"
    assertEquals '["first","second"]' "$(./ysh ".list_alias" test/advanced.yml)"
    assertEquals "b" "$(./ysh ".flow_alias.y[1]" test/advanced.yml)"
    assertEquals "1" "$(./ysh ".sequence_aliases[1].x" test/advanced.yml)"
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
    assertEquals "" "$(./ysh '.missing?' test/expressions.yml)"
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

testInplaceRejectsMultiDocumentStreamsWithoutChanges() {
    inplace_file=test/.tmp-inplace-multi-$$.yml
    original_file=test/.tmp-inplace-original-$$.yml
    cp test/test.yml "$inplace_file"
    cp test/test.yml "$original_file"
    result=$(./ysh -i '.key = "changed"' "$inplace_file" 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "does not yet support multi-document streams"
    cmp "$original_file" "$inplace_file"
    assertEquals 0 $?
    rm -f "$inplace_file" "$original_file"
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

testEmptyDocumentsAreNull() {
    assertEquals "null" "$(printf "" | ./ysh "." --json)"
    assertEquals "null" "$(printf "%s\n" "---" "..." | ./ysh "." --json)"
    assertEquals "null" "$(printf "%s\n" "---" "---" "key: value" | ./ysh -d 0 "." --json)"
    assertEquals "value" "$(printf "%s\n" "---" "---" "key: value" | ./ysh -d 1 ".key")"
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
    result=$(printf "%s\n" "not yaml" "another root" | ./ysh "." 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "unknown syntax"

    result=$(printf "%s\n" "items: [one," "  two]" | ./ysh ".items" 2>&1)
    assertNotEquals 0 $?
    assertContains "$result" "multiline or unclosed flow collection"
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

testReleaseArtifactsStayInSync() {
    assertContains "$(cat README.md)" "v1.2.0/ysh"
    assertContains "$(cat _static/_www/docs/getting-started.md)" "v1.2.0/ysh"
    assertContains "$(cat _static/_www/install)" "v1.2.0/ysh"
    assertContains "$(cat _static/_www/index.html)" "Install v1"
    assertContains "$(cat _static/_www/index.html)" "style.css?v=1.2.0"
    assertContains "$(cat _static/_www/docs/index.html)" "theme.css?v=1.2.0"
    assertContains "$(cat _static/_www/docs/index.html)" "docsify@4/lib/themes/vue.css"
    assertTrue "social preview image must exist" "[ -s _static/_www/og.png ]"
}

# shellcheck source=/dev/null
. ./test/shunit2
