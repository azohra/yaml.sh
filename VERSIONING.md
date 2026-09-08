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

## Changes and validation

The reviewed PR title and body become the squash commit. Its Conventional title
sets aggregate impact using git-cliff's default bump rules: a breaking header or
`BREAKING CHANGE:` footer produces a major, `feat` produces a minor, and other
Conventional changes produce patches. Non-Conventional commits are excluded.
Nested Conventional headings in the body are ordinary prose.

PR checks build and test the proposed merge. Main requires passing checks against
the current base before merging. The full suite runs before merge; publication
smoke-tests the versioned artifact.

```sh
mise run changelog
```

This renders recorded changes and releases from Git, followed by the historical
entries in `CHANGELOG.md`. New entries use the reviewed title and link to the
full commit. Breaking-change notes retain migration instructions. Published
release notes are available in [GitHub Releases](https://github.com/azohra/yaml.sh/releases).
Versions and notes are calculated without rewriting source or opening a version PR.

## Publish the executable

From a clean checkout of current main:

```sh
mise run release
```

Release fetches main and its tags, checks the source commit, and calculates the
version once. It builds the executable with that version, smoke-tests it, and
writes its checksum and notes. GitHub CLI then creates the tag and publishes
those artifacts from the same run. The outputs are in `.release/`; source files
remain unchanged.

PR checks build and test the development executable without calculating a release
version from branch commits. Development builds identify themselves as `vdev`;
published builds embed the calculated version. Use `make ysh` for a local build.

Publication is explicit. Documentation and build changes can be released as
patches; merging their PRs does not publish a release.
An existing release is not overwritten. If an upload is interrupted, inspect
its draft with `gh release view`, upload missing assets with GitHub CLI, and
publish the draft after verifying its files. Do not move an existing tag.

Dispatch the Release workflow to run the same release command on main. After
successful publication it runs the website deployment. Homebrew's daily updater reads the
published executable and checksum and proposes the formula update; its manual
workflow can run that update immediately.

## Deploy the website

The website deploys on merges to main, independently of executable releases.
Its documentation follows main. Its installer and displayed release version
always refer to the latest published GitHub release.

```sh
mise run deploy -- --dry-run
mise run deploy
```

Deployment resolves one published tag, downloads its executable and checksum,
and verifies them. It builds the site into `.release/site`, filling the installer
URL, checksum and homepage version from that release. Wrangler deploys that
output. Source templates contain no release pins to update.

A missing or corrupt release asset stops deployment. An unsuccessful executable
release leaves the installer on the previous published version. After a release,
redeploying promotes its installer without a source commit. Local publication
and deployment are separate commands; the Release workflow performs both in order.
