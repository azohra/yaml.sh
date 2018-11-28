#!/bin/bash
# shellcheck source=/dev/null
# Query API
q() {
    grep -E "^$2" <<< "$1" | sed 's/^.*=//'
}

q_sub() {
    grep -E "^$2" <<< "$1" | sed "s/^$2//"
}

q_count() {
    q_sub "$1" "$2" | grep -oE "^\\.\\[[0-9]+\\]" | uniq | wc -l
}

# Helper for config
q_config() {
    q "$json" "$1" | sed 's/^.*=//'
}

q_config_sub() {
    grep -E "$1" <<< "$json" | sed "s/^$1//"
}
