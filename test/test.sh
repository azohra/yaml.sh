#!/usr/bin/env bash
# shellcheck disable=SC2034
YSH_LIB=1

# shellcheck source=/dev/null
source ./ysh

setUp() {
    file=$(ysh -f test/test.yml)
}

testVersion() {
    assertEquals 'v0.3.0' "$(ysh --version)"
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
}

testHelpIsSuccessful() {
    ysh --help >/dev/null
    assertEquals 0 $?
}

# shellcheck source=/dev/null
. ./test/shunit2
