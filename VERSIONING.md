# Versioning

YAML.sh follows [Semantic Versioning 2.0.0](https://semver.org/). Versions describe compatibility, not effort or completeness.

## The public contract

The compatibility contract includes documented:

- CLI arguments and exit behavior
- queries and transformations
- output values and formats
- supported YAML interpretation
- the one-file POSIX `/bin/sh` plus AWK reader runtime
- the documented host file utilities used by file-edit modes

Undocumented internals and rejected malformed or unsupported input are outside that contract. The machine-readable public contract owns capability status and evidence.

## Choosing a release number

| Change | Release | Example |
| --- | --- | --- |
| Compatible fix | Patch | `1.3.0` → `1.3.1` |
| Compatible capability | Minor | `1.3.0` → `1.4.0` |
| Intentional contract break | Major | `1.x` → `2.0.0` |

## Release mechanics

Releases come from tested `main` commits and use signed `vMAJOR.MINOR.PATCH` tags. The executable, installer, and generated release text must agree.

Bumping the version touches an exact set:

1. `YSH_VERSION` in `src/ysh.sh`.
2. The three version assertions in `test/test.sh`: `--version`, the installer download URL, and the homepage version marker.
3. A dated `CHANGELOG.md` entry plus its compare-link definition at the file tail.
4. Build the release artifact, calculate its SHA-256 digest, and pass that digest to
   `make docs RELEASE_SHA256=...`; this updates the installer checksum, homepage
   version, and documentation pages together. Ordinary `make docs` runs preserve
   the checksum of the currently published immutable release asset.
5. `make all` and the focused gates for whatever changed.

Release notes carry the voice, not just the facts: the title ends with a
short per-release quip (never the site tagline), the body opens by showing
the change — one runnable example beats a paragraph — with one idea per
bullet, and evidence, changelog, and artifact SHA-256 close in a compact
footer.
