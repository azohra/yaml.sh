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

The reviewed PR title and body become the squash commit. A version is cut only
when the assembled `ysh` differs from the published release; documentation,
website and tooling merges deploy the website and do not release. When it does
differ, the Conventional titles since the last release choose the number with
git-cliff's rules: a breaking header or `BREAKING CHANGE:` footer produces a
major, `feat` a minor, `fix` a patch. `build`, `chore`, `ci`, `docs`, `style`
and `test` never move the version, so a change to the program needs a `feat`
or `fix` title.

PR checks build and test the proposed merge. Main requires passing checks against
the current base before merging. The full suite runs before merge; publication
smoke-tests the versioned artifact.

```sh
mise run changelog
```

This renders recorded changes and releases from Git, followed by the historical
entries in `CHANGELOG.md`. Each entry shows the reviewed title and PR link, with
the body, migration instructions and footers visible. Published release notes are available in [GitHub Releases](https://github.com/azohra/yaml.sh/releases).
Changelog rendering uses GitHub PR metadata for links, with commit links when no
associated PR is available. Set `GITHUB_TOKEN` for authenticated GitHub access;
the shared git-cliff config named in `mise.toml` is downloaded for every
invocation, including version calculation.

`mise run changelog -- --json` exports git-cliff's structured context, including
bodies, footers and available GitHub metadata. It covers Git history only; it
does not convert the Markdown archive. Redirect either output to a file when needed.
Release notes use the same template for the unreleased changes.

Versions and notes are calculated without rewriting source or opening a version PR.

## Build, release and deploy

`mise run build [tag]` produces the executable and its checksum in `.release/`
and the website in `.release/site`. Without a tag it builds `vdev` for local
checks. The executable is smoke-tested, documentation is generated from
Markdown, and the installer and homepage use that executable's version.
Generated output is not committed.

Every merge to main runs the Release and deploy workflow. `mise run release`
builds `ysh` as the published version and compares checksums. Unchanged: it
prints the current tag and stops. Changed: it computes the next version, builds
it, publishes the release with `ysh`, `ysh.sha256` and generated notes, and
prints the new tag. An interrupted draft upload can be retried from the same
source; a draft belonging to different source is refused.

`mise run deploy <tag>` builds the website from the checkout for that published
release and deploys it to Cloudflare, tagged with the version and commit. The
installer on the site therefore always points at the latest published `ysh`,
and documentation changes go live on merge. Cloudflare keeps every deployed
version; to restore an earlier one, use `wrangler rollback` or check out the
commit and deploy again.

Homebrew's updater follows the published executable and checksum independently
of website deployment.
