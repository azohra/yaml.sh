# Versioning

YAML.sh follows [Semantic Versioning 2.0.0](https://semver.org/). Versions describe compatibility, not effort or completeness.

## The public contract

The compatibility contract includes documented:

- CLI arguments and exit behavior
- queries and transformations
- output values and formats
- supported YAML interpretation
- the one-file POSIX `/bin/sh` plus AWK reader runtime
- the documented host file utilities used by source-aware edit modes

Undocumented internals and rejected malformed or unsupported input are outside that contract.

## Choosing a release number

| Change | Release | Example |
| --- | --- | --- |
| Compatible fix | Patch | `1.3.0` → `1.3.1` |
| Compatible capability | Minor | `1.3.0` → `1.4.0` |
| Intentional contract break | Major | `1.x` → `2.0.0` |

## Release mechanics

Releases come from tested `main` commits and use signed `vMAJOR.MINOR.PATCH` tags. The executable, installer, and generated release text must agree. Brand artwork is evergreen rather than versioned. The machine-readable public contract owns capability status and evidence.
