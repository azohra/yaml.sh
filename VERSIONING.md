# Versioning YAML.sh

YAML.sh follows [Semantic Versioning 2.0.0](https://semver.org/): `MAJOR.MINOR.PATCH`.

The version describes compatibility, not effort, velocity, parser completeness, or how exciting a release feels.

## The public contract

Once a behavior is documented and covered by the release tests, users may depend on it. The compatibility contract includes:

- CLI names, flags, argument order, and exit behavior.
- The documented query and transformation language.
- Output values and formats for supported input.
- The supported YAML syntax and its documented interpretation.
- The one-file POSIX `/bin/sh` plus AWK runtime requirement.

Undocumented internals, diagnostics explicitly marked unstable, and newly rejected malformed or unsupported input are not compatibility promises.

## Choosing a release number

| Change | Release | Example |
| --- | --- | --- |
| Compatible bug or security fix | Patch | `1.3.0` → `1.3.1` |
| Compatible parser, query, output, or tooling capability | Minor | `1.3.0` → `1.4.0` |
| Intentional incompatibility in the public contract | Major | `1.x` → `2.0.0` |

A release may contain enormous internal changes and remain a minor release when existing supported programs keep working. A tiny CLI incompatibility may require a major release.

## Major-release gate

YAML.sh will not publish v2 merely because it becomes more complete. A v2 proposal must:

1. Name the public behavior that must break and why a compatible design is not supportable.
2. Include migration documentation and tests for the old and new behavior.
3. Spend at least one prerelease as `2.0.0-rc.1` for real-world validation.
4. Be approved as a deliberate contract change, not an aspirational milestone.

## Release mechanics

- Releases are built from `main` after required GitHub Actions checks pass.
- Release tags are signed and use the exact form `vMAJOR.MINOR.PATCH`.
- The executable, installer, README, docs, website metadata, cache keys, and release imagery carry the same version.
- Capability progress is reported with tests and compatibility measurements rather than major-version numbers.

## The v1.3 correction

The compatible feature set now released as `v1.3.0` was briefly tagged `v2.0.0` on 2026-08-02. No v1 public contract had broken, so that number did not follow this policy. The Git history remains intact; the premature release and tag were withdrawn, and `v1.3.0` is canonical.
