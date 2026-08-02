# Versioning YAML.sh

YAML.sh follows [Semantic Versioning 2.0.0](https://semver.org/). Versions describe compatibility, not effort or completeness.

## The public contract

The compatibility contract includes documented:

- CLI arguments and exit behavior
- queries and transformations
- output values and formats
- supported YAML interpretation
- the one-file POSIX `/bin/sh` plus AWK runtime

Undocumented internals and rejected malformed or unsupported input are outside that contract.

## Choosing a release number

| Change | Release | Example |
| --- | --- | --- |
| Compatible fix | Patch | `1.3.0` → `1.3.1` |
| Compatible capability | Minor | `1.3.0` → `1.4.0` |
| Intentional contract break | Major | `1.x` → `2.0.0` |

## Major-release gate

Version 2 requires:

1. A necessary, named incompatibility.
2. Migration docs and compatibility tests.
3. A `2.0.0-rc.1` prerelease.

## Release mechanics

Releases come from tested `main` commits and use signed `vMAJOR.MINOR.PATCH` tags. The executable, installer, docs, site, and imagery must agree. Tests and compatibility measurements report capability progress.

## The v1.3 correction

The compatible feature set released as `v1.3.0` was briefly tagged `v2.0.0` on 2026-08-02. The premature release and tag were withdrawn; Git history remains intact.
