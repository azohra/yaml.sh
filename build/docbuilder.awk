#!/usr/bin/awk -f

/^release_url=/ && version != "" {
    print "release_url=https://github.com/azohra/yaml.sh/releases/download/v" version "/ysh"
    next
}
/^expected_sha256=/ && sha256 != "" {
    print "expected_sha256=" sha256
    next
}
/data-ysh-version/ && version != "" {
    sub(/data-ysh-version>[^<]*</, "data-ysh-version>v" version "<")
}
{ print }
