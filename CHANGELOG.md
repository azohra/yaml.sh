# Changelog

All notable changes to YAML.sh are documented here.

## [0.4.0] - 2026-08-01

### Added

- Backward scalar, mapping, and sequence anchors and aliases with document scoping and recursion checks.
- Mapping merge keys from aliases, inline alias lists, and flow mappings with YAML merge precedence.
- `%YAML` and `%TAG` directives, scalar tag syntax, and explicit scalar mapping keys.
- `--type` inspection for core scalar types while preserving text output.
- An advanced conformance fixture plus explicit rejection tests for every documented boundary.

### Fixed

- Reject undefined, forward, recursive, and non-mapping merge aliases with actionable errors.
- Reject duplicate keys and ambiguous flattened query paths instead of returning competing values.
- Reject unknown directives, collection-valued complex keys, block merge lists, and multiline flow collections instead of misparsing them.

### Changed

- Buffer parser records so merge precedence and explicit overrides are deterministic.
- Replace the blanket feature disclaimer with a tested support contract and precise intentional limitations.
- Update GitHub Actions checkout to v7 and bound CI jobs to ten minutes.

## [0.3.0] - 2026-08-01

### Added

- Nested flow mappings and flow lists.
- Literal and folded multiline scalar values.
- Indentationless block lists.
- Source line lookup with `--line`.
- Tests for every previously open issue, CRLF input, quoted values, comments, malformed YAML, and indexes above 9.
- GitHub Actions coverage on Ubuntu and macOS.

### Fixed

- Preserve and decode quotes, backslashes, tabs, and newlines in scalar values.
- Treat query paths literally instead of as regular expressions.
- Count and read lists with multi-digit indexes.
- Reject malformed YAML instead of silently dropping the parser validation rules during the build.
- Report missing CLI arguments and unsafe unquoted transpiled input clearly.
- Update the installer and documentation to the current release.

### Changed

- The standalone build now embeds the readable AWK parser without the lossy minification step.
- `-T` is documented as accepting one quoted intermediate-data argument.
- The default GitHub branch and all three Cloudflare Pages production branches are now `main`.

## [0.2.1] - 2022-02-23

- Report missing files and make the help flag exit successfully.

[0.4.0]: https://github.com/azohra/yaml.sh/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/azohra/yaml.sh/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/azohra/yaml.sh/releases/tag/v0.2.1
