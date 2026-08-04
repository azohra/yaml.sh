#!/usr/bin/awk -f

BEGIN {
    split(version, version_parts, ".")
    series = version_parts[1] "." version_parts[2]
}

/^expected_sha256=/ {
    if (sha256 != "") {
        print "expected_sha256=" sha256
        next
    }
}

/https:\/\/raw.githubusercontent.com\/azohra\/yaml.sh\/v[0-9]+\.[0-9]+\.[0-9]+\/ysh/ {
    sub(/https:\/\/raw.githubusercontent.com\/azohra\/yaml.sh\/v[0-9]+\.[0-9]+\.[0-9]+\/ysh/, "https://raw.githubusercontent.com/azohra/yaml.sh/v" version "/ysh")
    print
    next
}
/https:\/\/github.com\/azohra\/yaml.sh\/releases\/download\/v[0-9]+\.[0-9]+\.[0-9]+\/ysh/ {
    sub(/https:\/\/github.com\/azohra\/yaml.sh\/releases\/download\/v[0-9]+\.[0-9]+\.[0-9]+\/ysh/, "https://github.com/azohra/yaml.sh/releases/download/v" version "/ysh")
    print
    next
}
/data-ysh-version/ {
    sub(/>v[0-9]+\.[0-9]+\.[0-9]+</, ">v" version "<")
}
/data-ysh-series/ {
    sub(/>v[0-9]+\.[0-9]+</, ">v" series "<")
}
{print}
