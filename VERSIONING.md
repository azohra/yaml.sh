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
Its URL in `mise.toml` follows the shared configuration on main.

`mise run changelog -- --json` exports git-cliff's structured context, including
bodies, footers and available GitHub metadata. It covers Git history only; it
does not convert the Markdown archive. Redirect either output to a file when needed.
Release notes use the same template for the unreleased changes.

Versions and notes are calculated without rewriting source or opening a version PR.

## Build, release and deploy

`mise run build [tag]` produces the executable, its checksum and the deployable
website archive in `.release/`. Without a tag, it builds `vdev` for local checks.
The executable is smoke-tested, documentation is generated from Markdown, and
the installer and homepage use that executable's version. Generated pages are
build output and are not committed.

Each merge to main queues a release of that commit, followed by website
deployment. Git-cliff calculates the version once; the build receives it and
the release notes use it. PR checks exercise the same build with a development
version, including the generated site's links and deployment configuration.

`mise run release` publishes the checked-out main commit and prints its tag.
The release contains `ysh`, `ysh.sha256` and `site.tar.gz`. The archive contains
the generated website and its Wrangler configuration. No source version file
or generated changelog commit is required.

An interrupted draft upload can be retried with `mise run release` from the
same source: it rebuilds that version and replaces only draft assets before
publishing. A draft belonging to different source is refused. Once published,
repeating release returns its tag without rebuilding or replacing assets.
Local publication should not run alongside the workflow. New releases from
source older than an existing descendant release are refused.

```sh
mise run deploy <release-tag> --dry-run
mise run deploy <release-tag>
```

Deployment downloads and extracts the published archive and uses its Wrangler
configuration. It does not use the checkout's website files or rebuild the
product. The same command retries deployment or restores an earlier release,
without switching branches. Releases created before the website archive was
introduced do not contain this deployable bundle.

A failed deployment leaves the published release available. Homebrew's updater
follows the published executable and checksum independently of website deployment.
