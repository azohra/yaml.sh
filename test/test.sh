#!/usr/bin/env bash
# shellcheck disable=SC2034
YSH_LIB=1

# shellcheck source=/dev/null
source ./ysh

setUp() {
    file=$(ysh -f test/test.yml)
}

testVersion() {
    assertEquals 'v0.4.0' "$(ysh --version)"
}

testLoadFile() {
    assertNotNull "${file}"
}

testKeyValueFromFile() {
    assertEquals '"value"' "$(ysh -f test/test.yml -q key_value.key)"
    assertEquals 'value' "$(ysh -f test/test.yml -Q key_value.key)"
}

testKeyValueTranspiled() {
    assertEquals 'value' "$(ysh -T "${file}" -Q key_value.key)"
}

testLooseQuery() {
    result=$(ysh -T "${file}" -q loose_query)
    assertContains "${result}" 'key="value"'
    assertContains "${result}" 'level1.top_key="another_value"'
    assertEquals 2 "$(wc -l <<< "${result}" | tr -d ' ')"
}

testLiteralQueryDoesNotInterpretRegex() {
    assertEquals 'three' "$(ysh -T "${file}" -Q 'simple_list.list[2]')"
    assertNull "$(ysh -T "${file}" -Q 'simple_listXlist[2]')"
}

testSubtree() {
    result=$(ysh -T "${file}" -s subtree)
    assertContains "${result}" 'lower1="value"'
    assertContains "${result}" 'lower3.upper2.[1]="two"'
    assertEquals 5 "$(wc -l <<< "${result}" | tr -d ' ')"
}

testSimpleList() {
    result=$(ysh -T "${file}" -l simple_list.list)
    assertContains "${result}" '[0]="one"'
    assertContains "${result}" '[3]="four"'
    assertEquals 4 "$(wc -l <<< "${result}" | tr -d ' ')"
}

testSimpleListValues() {
    assertEquals $'one\ntwo\nthree\nfour' "$(ysh -T "${file}" -L simple_list.list)"
}

testSimpleCount() {
    assertEquals 4 "$(ysh -T "${file}" -c simple_list.list)"
}

testObjectList() {
    result=$(ysh -T "${file}" -l object_list.list)
    assertContains "${result}" '[0].name="one"'
    assertContains "${result}" '[2].value="3"'
    assertEquals 6 "$(wc -l <<< "${result}" | tr -d ' ')"
}

testExpandedList() {
    result=$(ysh -T "${file}" -l expanded_list.list)
    assertContains "${result}" '[0].name="one"'
    assertContains "${result}" '[2].value="3"'
    assertEquals 6 "$(wc -l <<< "${result}" | tr -d ' ')"
}

testChainedListAccess() {
    assertEquals 'three' "$(ysh -T "${file}" -l simple_list.list -I 2)"
    result=$(ysh -T "${file}" -l object_list.list -i 2)
    assertContains "${result}" 'name="three"'
    assertContains "${result}" 'value="3"'
}

testDirectListAccess() {
    assertEquals 'two' "$(ysh -T "${file}" -Q 'simple_list.list[1]')"
    assertEquals 'three' "$(ysh -T "${file}" -Q 'object_list.list[2].name')"
}

testTopKeys() {
    result=$(ysh -T "${file}" -s top_values -t)
    assertEquals $'lower1\nlower2\nlower3' "${result}"
}

testNextBlock() {
    assertEquals 'value' "$(ysh -T "${file}" -Q key)"
    file2=$(ysh -T "${file}" -n)
    assertEquals 'block_2_value' "$(ysh -T "${file2}" -Q key)"
    file2=$(ysh -T "${file2}" -n)
    assertEquals 'block_3_value' "$(ysh -T "${file2}" -Q key)"

    documents=$(printf '%s\n' '--- # first' 'key: first' '--- # second' 'key: second' | YSH_parse_stdin)
    assertEquals 'first' "$(ysh -T "${documents}" -Q key)"
    assertEquals 'second' "$(ysh -T "$(ysh -T "${documents}" --next)" -Q key)"
}

testComplexFlowObjectFromIssue1() {
    assertEquals 'feature' "$(ysh -f test/issues.yml -Q complex.name)"
    assertEquals 'request' "$(ysh -f test/issues.yml -Q complex.details.type)"
    assertEquals 'medium' "$(ysh -f test/issues.yml -Q complex.details.priority)"
}

testMultilineValuesFromIssue2() {
    assertEquals $'This value\ncan span multiple lines' "$(ysh -f test/issues.yml -Q literal)"
    assertEquals 'This value folds onto one line' "$(ysh -f test/issues.yml -Q folded)"
}

testInlineListFromIssue3() {
    assertEquals 4 "$(ysh -f test/issues.yml -c inline)"
    assertEquals 'three, four' "$(ysh -f test/issues.yml -Q 'inline[2]')"
    assertEquals 'item' "$(ysh -f test/issues.yml -Q 'inline[3].name')"
}

testListIndentationFromIssue5() {
    assertEquals $'item1\nitem2' "$(ysh -f test/issues.yml -L indented)"
    assertEquals $'item1\nitem2' "$(ysh -f test/issues.yml -L indentless)"
}

testCookbookQueriesFromIssue10() {
    assertEquals '0' "$(printf '%s\n' 'block_no: 0' | ysh -Q block_no)"
    assertEquals 'three' "$(ysh -f test/test.yml -Q 'expanded_list.list[2].name')"
}

testLinePointersFromIssue12() {
    assertEquals '2' "$(ysh -f test/issues.yml --line complex.details.type)"
    assertEquals '10' "$(ysh -f test/issues.yml --line literal)"
}

testQuotedTranspiledDataFromIssue15() {
    transpiled=$(ysh -f test/issues.yml)
    assertEquals 'rust' "$(ysh -T "${transpiled}" -Q lenguaje)"
    assertEquals 'make.toml' "$(ysh -T "${transpiled}" -Q 'fichero_tareas[0]')"
    assertEquals 'say "hello"' "$(ysh -T "${transpiled}" -Q quotes.double)"
    assertEquals "it's fine" "$(ysh -T "${transpiled}" -Q quotes.single)"
}

testListsSupportMultipleDigitIndexes() {
    assertEquals 12 "$(ysh -f test/issues.yml -c long_list)"
    assertEquals 'ten' "$(ysh -f test/issues.yml -Q 'long_list[10]')"
    assertEquals 'eleven' "$(ysh -f test/issues.yml -L long_list | tail -1)"
}

testCommentsAndCrLfInput() {
    assertEquals 'value' "$(ysh -f test/issues.yml -Q comment)"
    assertEquals 'value' "$(printf 'key: value\r\n' | ysh -Q key)"
    assertEquals 'https://yaml.sh' "$(ysh -f test/issues.yml -Q 'urls[0]')"
}

testBackwardScalarAndCollectionAliases() {
    assertEquals 'hello' "$(ysh -f test/advanced.yml -Q scalar_alias)"
    assertEquals 'red' "$(ysh -f test/advanced.yml -Q mapping_alias.color)"
    assertEquals 'true' "$(ysh -f test/advanced.yml -Q mapping_alias.nested.enabled)"
    assertEquals $'first\nsecond' "$(ysh -f test/advanced.yml -L list_alias)"
    assertEquals 'b' "$(ysh -f test/advanced.yml -Q 'flow_alias.y[1]')"
    assertEquals 'hello' "$(ysh -f test/advanced.yml -Q 'sequence_aliases[0]')"
    assertEquals '1' "$(ysh -f test/advanced.yml -Q 'sequence_aliases[1].x')"
}

testMergeKeysAndPrecedence() {
    assertEquals 'red' "$(ysh -f test/advanced.yml -Q merged.color)"
    assertEquals 'large' "$(ysh -f test/advanced.yml -Q merged.size)"
    assertEquals 'square' "$(ysh -f test/advanced.yml -Q merged.shape)"
    assertEquals 'green' "$(ysh -f test/advanced.yml -Q inline_merge.color)"
    assertEquals 'small' "$(ysh -f test/advanced.yml -Q inline_merge.size)"
    assertEquals 'flow' "$(ysh -f test/advanced.yml -Q literal_merge.from)"
    assertEquals 'true' "$(ysh -f test/advanced.yml -Q literal_merge.active)"
    assertEquals 'literal' "$(ysh -f test/advanced.yml -Q 'quoted_merge_key.<<')"
}

testDirectivesTagsAndExplicitScalarKeys() {
    assertEquals '123' "$(ysh -f test/advanced.yml -Q types.forced_string)"
    assertEquals 'payload' "$(ysh -f test/advanced.yml -Q types.custom)"
    assertEquals 'explicit value' "$(ysh -f test/advanced.yml -Q 'explicit key')"
    assertEquals 'value' "$(printf '%s\n' '%YAML 1.2' '---' 'key: value' | ysh -Q key)"
}

testScalarTypeInspection() {
    assertEquals 'string' "$(ysh -f test/advanced.yml --type types.string)"
    assertEquals 'string' "$(ysh -f test/advanced.yml --type types.quoted_number)"
    assertEquals 'null' "$(ysh -f test/advanced.yml --type types.null)"
    assertEquals 'bool' "$(ysh -f test/advanced.yml --type types.boolean)"
    assertEquals 'int' "$(ysh -f test/advanced.yml --type types.integer)"
    assertEquals 'int' "$(ysh -f test/advanced.yml --type types.binary)"
    assertEquals 'int' "$(ysh -f test/advanced.yml --type types.octal)"
    assertEquals 'int' "$(ysh -f test/advanced.yml --type types.hex)"
    assertEquals 'float' "$(ysh -f test/advanced.yml --type types.float)"
    assertEquals 'float' "$(ysh -f test/advanced.yml --type types.trailing_float)"
    assertEquals 'float' "$(ysh -f test/advanced.yml --type types.exponent)"
    assertEquals 'timestamp' "$(ysh -f test/advanced.yml --type types.timestamp)"
    assertEquals 'string' "$(ysh -f test/advanced.yml --type types.forced_string)"
    assertEquals 'tagged' "$(ysh -f test/advanced.yml --type types.custom)"
    assertEquals 'int' "$(printf '%s\n' 'answer: 42' | ysh --type answer)"
}

testAnchorsAreDocumentScopedAndCanBeRedefined() {
    second_document=$(ysh -f test/advanced.yml --next)
    assertEquals 'second' "$(ysh -T "${second_document}" -Q fresh_alias)"
}

testUnsupportedYamlFailsExplicitly() {
    result=$(printf '%s\n' 'value: *later' 'later: &later yes' | ysh -Q value 2>&1)
    assertNotEquals 0 $?
    assertContains "${result}" 'undefined alias *later'

    result=$(printf '%s\n' 'root: &root' '  child: *root' | ysh -Q root.child 2>&1)
    assertNotEquals 0 $?
    assertContains "${result}" 'recursive alias *root'

    result=$(printf '%s\n' '? [one, two]' ': value' | ysh -Q key 2>&1)
    assertNotEquals 0 $?
    assertContains "${result}" 'collection-valued complex keys are not supported'

    result=$(printf '%s\n' '%FOO bar' 'key: value' | ysh -Q key 2>&1)
    assertNotEquals 0 $?
    assertContains "${result}" 'unsupported or malformed directive'

    result=$(printf '%s\n' 'base: &base' '  key: value' 'target:' '  <<:' '    - *base' | ysh -Q target.key 2>&1)
    assertNotEquals 0 $?
    assertContains "${result}" 'block merge lists are not supported'

    result=$(printf '%s\n' 'items: [one,' '  two]' | ysh -Q items 2>&1)
    assertNotEquals 0 $?
    assertContains "${result}" 'multiline or unclosed flow collection'

    result=$(printf '%s\n' 'scalar: &scalar value' 'target:' '  <<: *scalar' | ysh -Q target 2>&1)
    assertNotEquals 0 $?
    assertContains "${result}" 'does not reference a mapping'

    result=$(printf '%s\n' 'key: first' 'key: second' | ysh -Q key 2>&1)
    assertNotEquals 0 $?
    assertContains "${result}" 'duplicate or ambiguous mapping path key'

    result=$(printf '%s\n' '? key' | ysh -Q key 2>&1)
    assertNotEquals 0 $?
    assertContains "${result}" 'explicit scalar key has no mapping value'
}

testInvalidYamlIsRejected() {
    result=$(printf '%s\n' 'not yaml' | ysh -Q key 2>&1)
    status=$?
    assertNotEquals 0 "${status}"
    assertContains "${result}" 'unknown syntax on line 1'
}

testCliErrors() {
    ysh -f does_not_exist.yaml -Q key >/dev/null 2>&1
    assertEquals 1 $?
    ysh -T "${file}" -Q >/dev/null 2>&1
    assertEquals 2 $?
    ysh -T "${file}" --line key >/dev/null 2>&1
    assertEquals 2 $?
    ysh -T "${file}" --type key >/dev/null 2>&1
    assertEquals 2 $?
}

testHelpIsSuccessful() {
    ysh --help >/dev/null
    assertEquals 0 $?
}

# shellcheck source=/dev/null
. ./test/shunit2
