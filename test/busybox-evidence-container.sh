#!/bin/sh

set -eu

evidence_dir=${YSH_EVIDENCE_DIR:-/evidence}
[ -d "$evidence_dir/yaml-test-suite" ] || {
    printf '%s\n' "busybox-evidence: refusing — $evidence_dir/yaml-test-suite is unavailable" >&2
    exit 1
}
command -v busybox >/dev/null 2>&1 || {
    printf '%s\n' 'busybox-evidence: refusing — BusyBox is unavailable' >&2
    exit 1
}
command -v yq >/dev/null 2>&1 || {
    printf '%s\n' 'busybox-evidence: refusing — yq is unavailable' >&2
    exit 1
}

make ysh
busybox_dir=/tmp/ysh-busybox
[ ! -e "$busybox_dir" ] || {
    printf '%s\n' "busybox-evidence: refusing — $busybox_dir already exists" >&2
    exit 1
}
mkdir -p "$busybox_dir"
ln -s "$(command -v busybox)" "$busybox_dir/awk"
export PATH="$busybox_dir:$PATH"
export YAML_TEST_SUITE_DIR="$evidence_dir/yaml-test-suite"
export YQ_BINARY=/usr/local/bin/yq

make conformance
make differential
make fuzz
