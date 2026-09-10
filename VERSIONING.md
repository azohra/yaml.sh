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
Nested Conventional headings in the body are ordinary prose. The
[Conventional PR format](https://github.com/azohra/conventional-pr#bodies-and-annotations)
defines the validated message and optional annotations.

PR checks build and test the proposed merge. Main requires passing checks against
the current base before merging. The full suite runs before merge; publication
smoke-tests the versioned artifact.

```sh
mise run changelog
```

This renders recorded changes and releases from Git, followed by the historical
entries in `CHANGELOG.md`. Each entry shows the reviewed title and PR link, with
migration instructions and footers visible. Expand **Details** for the full
explanation, including Markdown lists and code examples. Published
release notes are available in [GitHub Releases](https://github.com/azohra/yaml.sh/releases).
Changelog rendering uses GitHub PR metadata for links, with commit links when no
associated PR is available. Set `GITHUB_TOKEN` for authenticated GitHub access;
the preset itself is downloaded for every invocation, including version calculation.
Its URL in `mise.toml` pins the shared configuration to a reviewed commit.

`mise run changelog -- --json` exports git-cliff's structured context, including
bodies, footers and available GitHub metadata. It covers Git history only; it
does not convert the Markdown archive. Redirect either output to a file when needed.
Release notes use the same template for the unreleased changes.

Versions and notes are calculated without rewriting source or opening a version PR.

## Releases and deployment

Merging a PR automatically releases its main revision. `release_base` in
`mise.toml` records the last revision before automatic releases; older changes
are collected in the first release rather than backfilled as separate versions. Git-cliff calculates the
version and notes; the release task builds and smoke-tests the executable,
writes its checksum, and publishes both assets in GitHub Releases. No version
file or generated changelog commit is required.

The Release workflow then checks out that published tag and deploys its website.
Pages, documentation and installer use the same release revision and executable.
A deployment failure leaves the published release available; retry the failed
job to deploy that same tag. A superseded release cannot replace the latest site.

The same operations are available through mise. Release requires a clean,
merged checkout and prints the tag it published or resumed:

```sh
mise run release
```

An interrupted publication resumes the tag at that commit, verifies existing
assets and uploads missing ones before publishing. Existing tags and published
assets are never replaced. If merges arrive out of order, finish the preceding
release and retry the waiting revision. Main may advance without changing the selected source.

To validate or deploy a release, check out its tag first:

```sh
git checkout --detach v1.18.2
mise run deploy v1.18.2 --dry-run
mise run deploy v1.18.2
```

Use the desired published tag in place of the example. Deployment downloads that
release's executable and checksum, builds `.release/site` from the checkout,
and publishes it with Wrangler. It verifies the live installer against the built
file. Deployment does not calculate a version or create a release.

PR checks use development builds identified as `vdev`; release builds embed the
calculated version. Homebrew's updater follows the published executable and
checksum independently of website deployment.
