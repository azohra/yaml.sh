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

Releases come from tested `main` commits and use `vMAJOR.MINOR.PATCH` tags. The executable, installer, and generated release text must agree.

Bumping the version touches an exact set:

1. `YSH_VERSION` in `src/ysh.sh`.
2. The version and installer checksum assertions in `test/test.sh`, plus the pinned installer URL in `test/docs.sh`.
3. A dated `CHANGELOG.md` entry plus its compare-link definition at the file tail.
4. Build the release artifact, calculate its SHA-256 digest, and pass that digest to
   `make docs RELEASE_SHA256=...`; this updates the installer checksum, homepage
   version, and documentation pages together. Ordinary `make docs` runs preserve
   the checksum of the currently published release asset.
5. `make all` and the focused gates for whatever changed.

Release notes carry the voice, not just the facts: the title ends with a
short per-release quip (never the site tagline), the body opens by showing
the change — one runnable example beats a paragraph — with one idea per
bullet, and evidence, changelog, and artifact SHA-256 close in a compact
footer.

## Publish and promote

Include reviewed release notes in the releases directory, named for the tag with a .md suffix in the version
PR. Its first line is `# YAML.sh vMAJOR.MINOR.PATCH — <quip>`; the remaining text
is the release body described above. The publisher appends the built artifact's
SHA-256. Keep claims about evidence tied to a real run.

After the version PR passes Check and merges, tag that commit and push the tag.
Tags do not need to be signed. Check out the tag and run:

```sh
mise run release -- vMAJOR.MINOR.PATCH
```

The task checks the source, runs the repository checks, builds `ysh` and
`ysh.sha256`, and publishes them with `gh release create`. The existing tag,
executable version, installer checksum, and release notes must agree. GitHub CLI
handles uploading the assets before publication. An existing release is not
overwritten; inspect an interrupted publication with `gh release view` and
finish its draft with GitHub CLI if needed.

The Release workflow runs the same task on the supplied tag with the repository
token, then deploys the site from current main. Pushing a tag alone does not
publish a release.

For local publication, run `mise run deploy` from current main afterward.
Ordinary site changes also deploy through that task or the manual Deploy
workflow. Merging alone does not deploy: a version PR can reference an asset
that has not been published yet. Deployment checks that the installer's pinned
download exists and matches its checksum before shipping.

Homebrew's daily YAML.sh updater reads `ysh` and `ysh.sha256` and proposes the
formula change. Its manual workflow provides an immediate update when needed.
