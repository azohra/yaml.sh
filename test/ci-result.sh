#!/bin/sh

testSelectedChecksAndIntentionalSkips() {
    sh build/ci-result.sh success true true true success success success >/dev/null
    assertEquals 'mixed changes' 0 "$?"
    sh build/ci-result.sh success true false false skipped success success >/dev/null
    assertEquals 'runtime changes' 0 "$?"
    sh build/ci-result.sh success false true false success skipped skipped >/dev/null
    assertEquals 'docs-only changes' 0 "$?"
    sh build/ci-result.sh success false true true success skipped success >/dev/null
    assertEquals 'docs generator portability' 0 "$?"
    sh build/ci-result.sh success false false false skipped skipped skipped >/dev/null
    assertEquals 'unrelated paths' 0 "$?"
}

testIncompleteOrFailedProofIsRejected() {
    for result in failure cancelled skipped ''; do
        sh build/ci-result.sh "$result" false false false skipped skipped skipped >/dev/null 2>&1
        assertEquals "classification $result" 1 "$?"
    done
    for scope in '' unknown; do
        sh build/ci-result.sh success "$scope" false false skipped skipped skipped >/dev/null 2>&1
        assertEquals "invalid scope $scope" 1 "$?"
    done
    for result in failure cancelled skipped ''; do
        sh build/ci-result.sh success true true true "$result" success success >/dev/null 2>&1
        assertEquals "docs $result" 1 "$?"
        sh build/ci-result.sh success true true true success "$result" success >/dev/null 2>&1
        assertEquals "runtime $result" 1 "$?"
        sh build/ci-result.sh success true true true success success "$result" >/dev/null 2>&1
        assertEquals "portability $result" 1 "$?"
    done
    sh build/ci-result.sh success false false false failure skipped skipped >/dev/null 2>&1
    assertEquals 'an unselected job that ran and failed' 1 "$?"
    sh build/ci-result.sh >/dev/null 2>&1
    assertEquals 'missing inputs' 1 "$?"
}

# shellcheck source=/dev/null
. ./test/shunit2
