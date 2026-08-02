# YAML without the luggage

YAML.sh is a yq-like query tool delivered as one portable shell script. It runs with the system `/bin/sh` and AWK, making it useful in bootstrap scripts, minimal containers, CI jobs, old machines, and every awkward environment where installing a language runtime feels absurd.

> Version 1.3 completes the architecture: YAML becomes a writable node graph, the expression engine programs streams of references, and in-place scalar edits can patch the original presentation.

```sh
ysh '.server.host' config.yml
# localhost

ysh -o=json '.services[0]' config.yml
# {"name":"api","enabled":true}

ysh '.services[] | select(.enabled) | .name' config.yml
# api
# web

ysh -i '.services[] | select(.enabled) | .tier = "active"' config.yml
```

## Why it exists

Sometimes `yq` is exactly the right answer. Sometimes you are writing the script that would install `yq`.

YAML.sh aims for the useful middle: familiar yq-style paths, streams, filters, construction, and updates; serious handling of common YAML structures; one auditable file; and no additional packages. It does not pretend that YAML is simple or claim complete specification compliance.

## What changed in v1

| Before | Version 1 |
| --- | --- |
| Flattened `path="value"` records | A real mapping, sequence, scalar, and alias graph |
| Chainable query flags | One yq-style query expression |
| Bash runtime | Portable `/bin/sh` launcher |
| Collection identity lost | Empty mappings and sequences preserved |
| Tag syntax mostly discarded | Expanded tags attached to nodes |
| Inline merge subset | Alias lists, flow mappings, and block merge sequences |

Version 1 made the graph writable. Version 1.3 adds maps, entries, variables, dynamic indexes, reducers, strings, sorting, deep merge, broader YAML syntax, multi-document mutation, and presentation-preserving scalar edits.

## Pick a path

- [Install YAML.sh and run the first query](getting-started.md)
- [Learn the query grammar](queries.md)
- [See exactly which YAML features work](supported_yml.md)
- [Migrate a v0.x command](migration.md)
- [Open the parser hood](internals.md)
- [See how releases are versioned](versioning.md)

YAML.sh is built for fun, but the support contract is serious.
