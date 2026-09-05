#!/bin/sh
set -eu

if [ "$#" -ne 7 ]; then
    echo 'ci-result: expected classification result, three scope flags, and docs/runtime/portability results' >&2
    exit 1
fi
if [ "$1" != success ]; then
    echo "ci-result: classification did not succeed: $1" >&2
    exit 1
fi
for scope in "$2" "$3" "$4"; do
    case "$scope" in
        true|false) ;;
        *) echo "ci-result: invalid scope: $scope" >&2; exit 1 ;;
    esac
done

check_result() {
    case "$2:$3" in
        true:success|false:success|false:skipped) ;;
        *) echo "ci-result: $1 selected=$2 result=$3" >&2; exit 1 ;;
    esac
}

portability=false
if [ "$2" = true ] || [ "$4" = true ]; then
    portability=true
fi
check_result docs "$3" "$5"
check_result runtime "$2" "$6"
check_result portability "$portability" "$7"
echo 'ci-result: all selected checks passed'
