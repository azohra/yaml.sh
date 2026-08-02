#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
BASE=${YQ_DIFFERENTIAL_BASE:-$SCRIPT_DIR/yq-corpus-base.tsv}

awk -F '\t' '
function classify(query) {
    if (index(query, "\\(")) return "interpolation"
    if (query ~ /(^|[| ])(test|sub)\(/) return "regex"
    if (query ~ /\[[^]]*:[^]]*\]/) return "slices"
    if (query ~ /(group_by|sort_by|unique_by|min_by|max_by)/) return "grouping"
    if (query ~ /(^|[ |])(del\(|[^=!<>][+*|]?=)/) return "mutation"
    if (query ~ /(map|entries|sort|unique|flatten|reverse|min|max|any|all|add|keys|length)/) return "collections"
    if (query ~ /([+*%]| - | \/ )/) return "arithmetic"
    if (query ~ /(select|==|!=|>=|<=| and | or | not)/) return "selection"
    if (query ~ /(^|[ |])\{|(^|[ |])\[/) return "construction"
    return "paths"
}
BEGIN {
    OFS = "\t"
    slash = sprintf("%c", 92)
    print "# family", "fixture", "query"
}
$1 != "" && $1 !~ /^#/ {
    print classify($2), $1, $2
}
END {
    for (i = 1; i <= 140; i++) {
        a = i % 17
        values = sprintf("[%d,%d,%d,%d,%d]", a, a + 1, a + 2, a + 3, a + 4)
        mode = i % 4
        if (mode == 0) query = values "[1:4]"
        else if (mode == 1) query = values "[:-1]"
        else if (mode == 2) query = values "[-3:]"
        else query = values "[0:0]"
        print "slices", "expressions.yml", query
    }
    for (i = 1; i <= 120; i++) {
        query = sprintf("\"case-%d %s(%d + %d)\"", i, slash, i, (i % 13) + 1)
        print "interpolation", "expressions.yml", query
    }
    for (i = 1; i <= 100; i++) {
        mode = i % 4
        if (mode == 0) query = sprintf("\"item-%d\" | test(\"^item-[0-9]+$\")", i)
        else if (mode == 1) query = sprintf("\"ITEM-%d\" | test(\"^[A-Z]+-[0-9]+$\")", i)
        else if (mode == 2) query = sprintf("\"api.worker-%d\" | test(\"^[a-z]+%s%s.[a-z]+-[0-9]+$\")", i, slash, slash)
        else query = sprintf("\"node_%d\" | test(\"^(node|item)_[0-9]+$\")", i)
        print "regex", "expressions.yml", query
    }
    for (i = 1; i <= 100; i++) {
        mode = i % 5
        if (mode == 0) query = sprintf("\"item-%d-item-%d\" | sub(\"item\"; \"node-%d\")", i, i + 1, i)
        else if (mode == 1) query = sprintf("\"abbb-%d\" | sub(\"b*\"; \"_\")", i)
        else if (mode == 2) query = sprintf("\"x%d\" | sub(\"\"; \"-\")", i)
        else if (mode == 3) query = sprintf("\"item-%d\" | sub(\"[0-9]+\"; \"n\")", i)
        else query = sprintf("\"item-%d\" | sub(\"^item\"; \"node\")", i)
        print "regex", "expressions.yml", query
    }
    for (i = 1; i <= 100; i++) {
        query = sprintf("[{\"k\": 0, \"v\": %d}, {\"k\": 0, \"v\": %d}, {\"k\": 1, \"v\": %d}] | group_by(.k) | map(map(.v))", i, i + 1, i + 2)
        print "grouping", "expressions.yml", query
    }
    for (i = 1; i <= 120; i++) {
        if (i % 3 == 0) query = sprintf("%d + %d * 2", i, i + 1)
        else if (i % 3 == 1) query = sprintf("(%d + %d) * 2", i, i + 1)
        else query = sprintf("%d * %d", i, (i % 9) + 1)
        print "arithmetic", "expressions.yml", query
    }
    for (i = 1; i <= 100; i++) {
        a = i % 23
        mode = i % 5
        if (mode == 0) query = sprintf("[%d,%d,%d,%d] | sort", a + 3, a, a + 2, a + 1)
        else if (mode == 1) query = sprintf("[%d,%d,%d,%d] | unique", a, a + 1, a, a + 2)
        else if (mode == 2) query = sprintf("[%d,%d,%d] | reverse", a, a + 1, a + 2)
        else if (mode == 3) query = sprintf("[%d,%d,%d] | length", a, a + 1, a + 2)
        else query = sprintf("[%d,%d,%d] | map(. + 1)", a, a + 1, a + 2)
        print "collections", "expressions.yml", query
    }
}
' "$BASE"
