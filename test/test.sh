#!/bin/bash
YSH_LIB=1

source ysh

testLoadFile() {
    file=$(ysh -f test/test.yml)
    assertNotNull file
}

testKeyValueFromFile() {
    result=$(ysh -f test/test.yml -q key_value.key)
    assertEquals "\"value\"" "${result}"
}

testKeyValueTranspiled() {
    result=$(ysh -T "${file}" -q key_value.key)
    assertEquals "\"value\"" "${result}"
}

testLooseQuery() {
    result=$(ysh -T "${file}" -q loose_query)
    assertContains "key=\"value\"" "${result}"
    assertContains "level1.top_key=\"another_value\"" "${result}"
    assertEquals 2 $(wc -l <<< "${result}")

    result=$(ysh -T "${file}" -q loose_query.key)
    assertEquals "\"value\"" "${result}"
}

testSafeQuery() {
    result=$(ysh -T "${file}" -Q loose_query)
    assertNull "${result}"

    result=$(ysh -T "${file}" -Q loose_query.key)
    assertEquals "value" "${result}"
}

testSubtree() {
    result=$(ysh -T "${file}" -s subtree)
    assertContains "lower1=\"value\"" "${result}"
    assertContains "lower2=\"another_value\"" "${result}"
    assertContains "lower3.upper1=\"upper_value\"" "${result}"
    assertContains "lower3.upper2.[0]=\"one\"" "${result}"
    assertContains "lower3.upper2.[1]=\"two\"" "${result}"
    assertEquals 5 $(wc -l <<< "${result}")
}

testSimpleList() {
    result=$(ysh -T "${file}" -l simple_list.list)
    assertContains "${result}" "\"one\""
    assertContains "${result}" "\"two\""
    assertContains "${result}" "\"three\""
    assertContains "${result}" "\"four\""
    assertEquals 4 $(wc -l <<< "${result}")
}


testSimpleListValues() {
    result=$(ysh -T "${file}" -L simple_list.list)
    assertContains "${result}" "one"
    assertContains "${result}" "two"
    assertContains "${result}" "three"
    assertContains "${result}" "four"
    assertNotContains "${result}" "\""
    assertEquals 4 $(wc -l <<< "${result}")
}

testSimpleCount() {
    result=$(ysh -T "$file" -c simple_list.list)
    assertEquals 4 $result
}

testObjectList() {
    result=$(ysh -T "$file" -l object_list.list)
    assertContains "${result}" '[0].name="one"'
    assertContains "${result}" '[0].value="1"'
    assertContains "${result}" '[1].name="two"'
    assertContains "${result}" '[1].value="2"'
    assertContains "${result}" '[2].name="three"'
    assertContains "${result}" '[2].value="3"'
    assertEquals 6 $(wc -l <<< "${result}")
}

testExpandedList() {
    result=$(ysh -T "$file" -l expanded_list.list)
    assertContains "${result}" '[0].name="one"'
    assertContains "${result}" '[0].value="1"'
    assertContains "${result}" '[1].name="two"'
    assertContains "${result}" '[1].value="2"'
    assertContains "${result}" '[2].name="three"'
    assertContains "${result}" '[2].value="3"'
    assertEquals 6 $(wc -l <<< "${result}")
}

testGetValueFromSimpleExpandedList() {
    result=$(ysh -T "$file" -l "simple_list.list" -I 2)
    assertEquals "three" "$result"
}

testGetValueFromComplexExpandedList() {
    result=$(ysh -T "$file" -l "object_list.list" -i 2)
    assertContains "${result}" 'name="three"'
    assertContains "${result}" 'value="3"'
    assertEquals 2 $(wc -l <<< "${result}")
}

testArrayIndexAccess() {
    result=$(ysh -T "$file" -q "simple_list.list[1]")
    assertEquals "\"two\"" "${result}"

    result=$(ysh -T "$file" -l object_list.list -i 1)
    assertContains "name=\"two\"" "${result}"
    assertContains "value=\"2\"" "${result}"
}

testSafeArrayIndexAccess() {
    result=$(ysh -T "$file" -Q "simple_list.list[1]")
    assertEquals "two" "${result}"

    result=$(ysh -T "$file" -l "object_list.list[1]")
    assertContains "name=two" "${result}"
    assertContains "value=2" "${result}"

}

testArraySafeIndexAccess() {
    result=$(ysh -T "$file" -Q "simple_list.list[1]")
    assertEquals "two" "${result}"

    result=$(ysh -T "$file" -Q "object_list.list[1]")
    assertNull "${result}"
}

testTopKeys() {
    result=$(ysh -T "$file" -s top_values -t)
    assertContains "lower1" "${result}"
    assertContains "lower2" "${result}"
    assertContains "lower3" "${result}"
    assertEquals 3 $(wc -l <<< "${result}")

    result=$(ysh -T "$file" -s top_values.lower2 -t)
    assertContains "upper1" "${result}"
    assertContains "upper2" "${result}"
    assertEquals 2 $(wc -l <<< "${result}")
}

testNextBlock() {
    result=$(ysh -T "$file" -Q key)
    assertEquals "value" "${result}"

    file2=$(ysh -T "$file" -n)
    result=$(ysh -T "$file2" -Q key)
    assertEquals "block_2_value" "${result}"

    file2=$(ysh -T "$file2" -n)
    result=$(ysh -T "$file2" -Q key)
    assertEquals "block_3_value" "${result}"
}

testEscapeLiteralListQuery() {
    assertEquals "simple_list.list.\[2\]" $(YSH_escape_query "simple_list.list[2]")
}

testEscapeComplexListItemQuery() {
    assertEquals "simple_list.list.\[2\].key" $(YSH_escape_query "simple_list.list[2].key")
}

testEscapeExpandedListItemQuery() {
    assertEquals "\[2\]" $(YSH_escape_query "[2]")
}

testSafeQueryWithListQuery() {
    result=$(ysh -T "$file" -Q "simple_list.list[2]")
    assertEquals "three" "$result"
}

testSubSupportsEscapedQueries() {
    result=$(ysh -T "$file" -s "object_list.list[2]")
    assertContains "$result" 'object_list.list.[2].name="three"'
    assertContains "$result" 'object_list.list.[2].value="3"'
    assertEquals 2 $(wc -l <<< "$result")
}

# From Issue https://github.com/azohra/yaml.sh/issues/13
testHelpFlagShouldNotBeAnError() {
    result=$(ysh -h)
    assertEquals 0 $?
}

testFileDoesNotExist() {
    result=$(ysh -f "does_not_exist.yaml" -s "doesnotmatter")
    assertEquals 1 $?
}

. ./test/shunit2
