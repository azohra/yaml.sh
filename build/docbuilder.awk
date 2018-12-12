#!/bin/awk

/https:\/\/raw.githubusercontent.com\/azohra\/yaml.sh\/v[0-9]+.[0-9]+.[0-9]+\/ysh/ {
    sub(/https:\/\/raw.githubusercontent.com\/azohra\/yaml.sh\/v[0-9]+.[0-9]+.[0-9]+\/ysh/, "https://raw.githubusercontent.com/azohra/yaml.sh/v" version "/ysh")
    print
    next
}
{print}