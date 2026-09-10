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

Changes on main trigger a release, followed by website deployment. The workflow
selects current main when it starts; pending runs may combine several merges.
Git-cliff calculates the version once and renders the notes using that version.
The existing Make recipe builds the executable, which is smoke-tested before
publication. The website is generated from the same source and executable.

Each release contains `ysh`, `ysh.sha256` and `site.tar.gz`. The website archive
contains the generated pages, documentation and installer. GitHub CLI uploads
these files to a draft, then publishes it. No source version file or generated
changelog commit is required.

The same operations are available locally:

```sh
mise run release
```

Release requires a clean checkout of current main and prints its published tag.
Repeating it for already-published source returns that tag without rebuilding.
If publication is interrupted, inspect the draft and its assets before retrying;
use GitHub CLI to finish an incomplete draft. Existing tags and published assets
must not be replaced. Local publication should not run alongside the workflow.

Deployment consumes a published website archive. It neither rebuilds the site
nor calculates a version. A failed deployment leaves the release available.
To retry it, select the release tag and run the deployment task:

```sh
git checkout --detach <release-tag>
mise run deploy <release-tag> --dry-run
mise run deploy <release-tag>
```

Replace `<release-tag>` with the desired published tag. The checkout supplies
its Wrangler configuration; the archive supplies its website files. Releases
created before website archives were introduced cannot use this deployment task.

PR checks use development builds identified as `vdev`; release builds embed the
calculated version. Homebrew's updater follows the published executable and
checksum independently of website deployment.
