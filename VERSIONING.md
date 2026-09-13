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

The reviewed PR title and body become the squash commit. release-drafter keeps
one draft release. `skip-changelog` excludes a pull request from both notes and
version calculation, including titles with a `!` marker. Tooling types
(`build`, `chore`, `ci`, `docs`, `style`, `test`) receive that label
automatically; other changes can be explicitly excluded too.

For included changes, labels group features under Added and fixes under Fixed.
Release Drafter resolves a breaking title to a major, `feat` to a minor, and
`fix` to a patch. Exclusion is decided first. The draft records what is
unreleased and is where release notes are edited.

A version names a change to the program. Publishing a draft whose `ysh` is
byte-identical to the previous release fails and returns to draft; a change to
the program needs a `feat` or `fix` title, and a site or documentation change
deploys on merge without a version.

PR checks build and test the proposed merge. Main requires passing checks against
the current base before merging.

```sh
mise run changelog
```

This renders recorded changes and releases from Git, followed by the historical
entries in `CHANGELOG.md`. Each entry shows the reviewed title and PR link, with
the body, migration instructions and footers visible. Published release notes
are the drafts as they were published, in
[GitHub Releases](https://github.com/azohra/yaml.sh/releases). Changelog
rendering uses GitHub PR metadata for links, with commit links when no
associated PR is available. Set `GITHUB_TOKEN` for authenticated GitHub access;
the shared git-cliff config named in `mise.toml` is downloaded for every
invocation.

`mise run changelog -- --json` exports git-cliff's structured context, including
bodies, footers and available GitHub metadata. It covers Git history only; it
does not convert the Markdown archive. Redirect either output to a file when needed.

## Build, release and deploy

`mise run build [tag]` produces the executable and its checksum in `.release/`
and the website in `.release/site`. Without a tag it builds `vdev` for local
checks. The executable is smoke-tested, documentation is generated from
Markdown, and the installer and homepage use that executable's version.
Generated output is not committed.

Every merge to main deploys the website, built for the latest published
release, so documentation changes go live on merge and the installer always
points at the current `ysh`.

Publishing the draft creates the tag. That runs the Release workflow, which is
`mise run release`: build `ysh` for the tag, refuse if it is byte-identical to
the previous release, attach `ysh` and `ysh.sha256` to the release, deploy the
website stamped with the new version, and open a pull request in
homebrew-tools that moves the formula to the release, verified against the
release's own checksum, using a token minted from the Bosun app. Assets appear
a minute or two after publishing; if the build fails, the release returns to
draft and its tag is removed, so the previous release stays latest.
