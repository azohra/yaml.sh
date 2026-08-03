#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
BASE=${YQ_DIFFERENTIAL_BASE:-$SCRIPT_DIR/yq-corpus-base.tsv}

# The hand-written corpus owns capability coverage. This generator adds stable
# family labels for reports; variation belongs in the property suite.
awk -F '\t' '
function classify(query) {
    if (index(query, "\\(")) return "interpolation"
    if (query ~ /(@(json|jsond|yaml|yamld|props|propsd|csv|csvd|tsv|tsvd|base64|base64d|uri|urid|sh)|to_(json|yaml|props|csv|tsv)|from_(json|yaml|props|csv|tsv))/) return "codecs"
    if (query ~ /(^|[ |])eval\(| ref \$/) return "dynamic"
    if (query ~ /(style|line_comment|tag|anchor|alias)/) return "yaml-metadata"
    if (query ~ /(^|[| ])(test|sub)\(/) return "regex"
    if (query ~ /(env\(|strenv\(|envsubst)/) return "environment"
    if (query ~ /(path|parent|fileIndex|documentIndex|filename)/) return "context"
    if (query ~ /(sort_keys|to_number|with\(|filter\(|first|pick\(|omit\(|pivot)/) return "practical"
    if ((substr(query, 1, 1) == "{" || substr(query, 1, 1) == "[") && query ~ / \*[+d?n]* /) return "merge"
    if (query ~ /\[[^]]*:[^]]*\]/) return "slices"
    if (query ~ /(group_by|sort_by|unique_by|min_by|max_by)/) return "grouping"
    if (query ~ /(^|[ |])(del\(|[^=!<>][+*|]?=)/) return "mutation"
    if (query ~ /(map|entries|sort|unique|flatten|reverse|min|max|any|all|add|keys|length)/) return "collections"
    if (query ~ /([+*%]| - | \/ )/) return "arithmetic"
    if (query ~ /(select|==|!=|>=|<=| and | or | not)/) return "selection"
    if (query ~ /(^|[ |])\{|(^|[ |])\[/) return "construction"
    return "paths"
}
BEGIN { OFS = "\t"; print "# family", "fixture", "query" }
$1 != "" && $1 !~ /^#/ { print classify($2), $1, $2 }
' "$BASE"
