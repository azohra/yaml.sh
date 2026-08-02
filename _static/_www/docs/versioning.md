# Versions that mean something

YAML.sh follows [Semantic Versioning](https://semver.org/). Versions describe compatibility, not effort or completeness.

| Change | Release |
| --- | --- |
| Compatible fix | Patch: `1.3.0` → `1.3.1` |
| Compatible capability | Minor: `1.3.0` → `1.4.0` |
| Intentional public-contract break | Major: `1.x` → `2.0.0` |

The public contract covers documented CLI behavior, queries, transformations, output, YAML interpretation, and the one-file POSIX `/bin/sh` plus AWK runtime.

## What earns v2

Version 2 needs a necessary, named incompatibility; migration docs and compatibility tests; and a `2.0.0-rc.1` prerelease. More syntax or operators alone do not require a major.

## Release identity

Every release keeps `ysh --version`, its signed tag, installer, generated docs, and release evidence in sync. The visual identity is evergreen SVG/HTML; a release number is ordinary generated text, never baked into a new logo or social image.

See the full [`VERSIONING.md`](https://github.com/azohra/yaml.sh/blob/main/VERSIONING.md) policy.
