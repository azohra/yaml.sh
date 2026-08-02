# Versions that mean something

YAML.sh uses `MAJOR.MINOR.PATCH` according to [Semantic Versioning 2.0.0](https://semver.org/). The number describes compatibility—not parser completeness, development speed, or ambition.

| Change | Release |
| --- | --- |
| Compatible fix | Patch: `1.3.0` → `1.3.1` |
| Compatible new capability | Minor: `1.3.0` → `1.4.0` |
| Intentional public-contract break | Major: `1.x` → `2.0.0` |

The public contract includes documented CLI behavior, queries and transformations, output formats, supported YAML interpretation, and the one-file POSIX `/bin/sh` plus AWK runtime.

## What earns v2

More YAML syntax, more yq-shaped operators, more tests, and better presentation preservation are all compatible minor releases. They can make YAML.sh dramatically more capable without changing the major.

Version 2 is reserved for a change that cannot reasonably preserve a supported v1 behavior. It needs a named incompatibility, a migration guide, compatibility tests, and at least one `2.0.0-rc.1` prerelease. It is a contract decision, not a finish line.

## Release identity

Every release keeps these in sync:

- `ysh --version`
- signed Git tag and GitHub release
- pinned installer URL
- README badge and examples
- website and docs labels
- social and README imagery

Capability is reported with measured conformance and differential tests. That is where the ambition belongs.

The full maintainer policy lives in [`VERSIONING.md`](https://github.com/azohra/yaml.sh/blob/main/VERSIONING.md).
