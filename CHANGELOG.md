# Changelog

All notable changes to YAML.sh are documented here.

## [1.1.0] - 2026-08-01

Version 1.1 moves beyond exact paths with a read-only expression engine modeled on the highest-value parts of yq.

### Added

- Sequence and mapping iteration with `[]`, including chained forms such as `.services[].name`.
- Pipe expressions that pass streams of node references between operations.
- `select(...)` filters with numeric and string comparisons using `==`, `!=`, `>`, `>=`, `<`, and `<=`.
- Boolean `and`, `or`, and `not` operations using YAML null/false truthiness.
- The `//` alternative operator for defaults when a result is null, false, or absent.
- `length`, `keys`, `has(...)`, `kind`, and yq-compatible `type` filters.
- Multi-result output with one value or compact JSON document per line.
- A focused expression fixture and ten new behavioral test groups, bringing the suite to 47 tests.

### Changed

- Missing mapping keys and out-of-range indexes now produce null, matching yq traversal semantics and enabling defaults.
- Queries may begin with a filter such as `length`; a leading `.` is no longer required.
- The evaluator retains node references, source metadata, aliases, and merge resolution throughout pipelines.

### Known boundaries

- Version 1.1 expressions are read-only. Assignment, deletion, construction, arithmetic, variables, recursive descent, optional traversal, and in-place updates remain future work.
- YAML output and presentation-preserving edits require an emitter and are not part of this release.

## [1.0.0] - 2026-08-01

Version 1 is a ground-up, intentionally breaking rebuild around a real YAML node graph and a yq-style command line.

### Added

- Direct queries such as `.server.host`, `.services[0].name`, and `.["key.with.dots"]`.
- Native mapping, sequence, scalar, and alias nodes with source lines, tags, anchors, parent-child edges, and document boundaries.
- JSON output for whole mappings and sequences, plus JSON-compatible core scalar resolution for nulls, booleans, integers, and finite floats.
- `--type`, `--tag`, `--line`, `--ast`, and `--events` inspection modes.
- Multi-document selection with `--document` and stdin input without a special flag.
- Empty mappings, empty sequences, root scalars, root flow collections, explicit scalar keys, primary and named tag handles, aliases, and mapping merges.
- A focused 37-test v1 suite and CI coverage for macOS AWK, Ubuntu AWK, BusyBox AWK, and POSIX shell syntax.
- A rebuilt website, documentation site, migration guide, parser internals guide, and tested support contract.

### Changed

- Require only POSIX `/bin/sh` and a standard AWK implementation; Bash is no longer required.
- Resolve the document graph before querying, avoiding the ambiguous flattened-path representation used by v0.x.
- Emit decoded scalar text by default and JSON for selected collections.
- Keep `ysh` and `src/ysh.awk` as the project and source names while clarifying that the delivered executable is a shell wrapper around an embedded AWK engine.

### Removed

- The v0.x `-f`, `-T`, `-q`, `-Q`, `-s`, `-l`, `-L`, `-c`, `-i`, `-I`, and `-p` command interface.
- The public transpiled-data format and chainable shell helper API.

### Known boundaries

- YAML.sh remains a deliberately scoped YAML implementation rather than a complete YAML 1.2 processor.
- Collection-valued explicit keys, recursive aliases, forward aliases, multiline flow collections, explicit block-scalar indentation indicators, and full schema-dependent resolution are not supported.
- The exact contract is maintained in [`_static/_www/docs/supported_yml.md`](_static/_www/docs/supported_yml.md).

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

[1.1.0]: https://github.com/azohra/yaml.sh/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/azohra/yaml.sh/compare/v0.4.0...v1.0.0
[0.4.0]: https://github.com/azohra/yaml.sh/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/azohra/yaml.sh/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/azohra/yaml.sh/releases/tag/v0.2.1
