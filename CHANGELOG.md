# Changelog

All notable changes to YAML.sh are documented here.

## [1.7.0] - 2026-08-02

Version 1.7 makes YAML.sh useful for real configuration composition while keeping the runtime to one auditable POSIX shell and AWK file.

### Added

- `env`, `strenv`, and `envsubst` with defaults, validation options, and a security disable switch.
- `path`, `parent`, `key`, `line`, `tag`, `filename`, `fileIndex`, and `documentIndex` context.
- `with`, `filter`, `first`, `pick`, `omit`, `pivot`, `sort_keys`, and `to_number`.
- Multiple-file evaluation, `--all-documents`, focused `eval-all`/`ea`, and `-e` exit status.
- An explicit yq capability map and 2,610/2,610 ordinary plus 8/8 cross-file differential cases against yq v4.53.3.

### Changed

- The deterministic property gate now covers five families and 12,000 cases; presentation grows to 400 cases; scale grows to 125,000 payload nodes and 1,500 documents.
- Sparse node metadata, conditional source retention, and single-pass flow detection reduce large-query peak memory by roughly one quarter; the enforced RSS ceiling tightens from 256 MiB to 224 MiB.
- The shell launcher now has one shared AWK invocation contract, and the repeatable benchmark reports sub-second timing instead of rounding short runs to zero.
- Versioned site, docs, installer, README, and social artwork now identify v1.7 consistently.

### Known boundaries

- `eval-all` covers slurp, metadata, filtering, construction, and practical cross-file merges; it is not yq's complete general stream engine.
- Load, dynamic eval, date/time, non-YAML codecs, comment/style queries, and advanced regex captures remain deliberately outside the portable runtime.

## [1.6.0] - 2026-08-02

Version 1.6 adds a useful slice of missing yq syntax and makes the evidence substantially harder to fake.

### Added

- End-exclusive sequence slices with omitted and negative bounds.
- Scalar string interpolation plus POSIX-ERE `test` and global `sub`.
- A reproducible 1,110-program categorized differential corpus with 1,110/1,110 parity against yq v4.53.3.
- 10,000 grammar-guided parser/query/mutation properties with seed replay and valid-form shrinking.
- A 250-case exact presentation mutation matrix.
- An enforced 100,000-payload-node, 1,000-document time and memory contract.

### Changed

- Query source now reaches AWK losslessly through the POSIX environment, so backslashes are not rewritten before expression lexing.
- CI gives modern Linux the complete generated and scale gates while retaining cross-version, cross-AWK, and cross-shell coverage.

## [1.5.0] - 2026-08-02

Version 1.5 closes the pinned parser corpus, triples yq differential coverage, and hardens the one-file runtime.

### Added

- Full expected outcomes for 282/282 pinned YAML Test Suite fixtures and rejection of all 91/91 strict-invalid fixtures.
- A 330-program differential corpus with 330/330 parity against yq v4.53.3.
- Input-byte, node-count, and depth limits with CLI controls.
- 250 deterministic round-trip/query properties, adversarial limit tests, and a repeatable benchmark.
- CI coverage for macOS AWK, mawk, original AWK, POSIX-mode gawk, BusyBox AWK, and several POSIX shells.

### Changed

- Block and quoted scalar handling, explicit entries, flow state, indentation validation, tab handling, anchor punctuation, and document boundaries now cover the complete pinned outcome corpus.
- Compound in-place edits preserve directives, tags, anchors, aliases, comments, block/flow layout, and quote style across replacements, inserts, deletes, and sequence reorders.
- Optional lookups, empty-sequence `length`, and negative-index `has(...)` now match yq.

## [1.4.0] - 2026-08-02

Version 1.4 is a measured compatibility release: more YAML, more yq-shaped programs, safer writes, same one-file runtime.

### Added

- Negative indexes; `sort_by`, `group_by`, `unique_by`, `min`/`max`, `min_by`/`max_by`, `any`/`all`, `any_c`/`all_c`, and `add`.
- Broader multiline scalars and flows, escapes, properties, directives, explicit entries, block sequences, anchors, and invalid-input checks.
- Comment-preserving direct inserts/deletes and pure sequence reorders.
- Pinned YAML Test Suite and yq differential gates.

### Changed

- In-place writes now use an atomic sibling replacement, preserve permissions, clean up failures, and refuse symlinks.
- The embedded AWK program is fed through a here-document, avoiding small argument limits on BusyBox systems.
- Measured gates: 70 behavioral tests, 245/282 valid YAML fixtures, 56/91 invalid fixtures rejected, and 110/110 programs matching yq v4.53.3.

## [1.3.0] - 2026-08-02

Version 1.3 completes the journey from a path reader to a compact YAML programming tool. It adds collection programming, lexical variables, reducers, broader YAML syntax, multi-document updates, and a hybrid presentation-preserving in-place editor while remaining one portable `/bin/sh` + AWK file.

This compatible feature release was briefly tagged `v2.0.0`. The tag and release were withdrawn before wider adoption because the public v1 contract did not break; the preserved code history is identical, and `v1.3.0` is the canonical release.

### Added

- Comma streams plus `map(...)` and `map_values(...)` collection transforms.
- `to_entries`, `from_entries`, and `with_entries(...)` mapping workflows.
- `sort`, stable `unique`, `reverse`, and recursive `flatten` sequence helpers.
- `upcase`, `downcase`, `contains`, `startswith`, `endswith`, `split`, and `join` string helpers.
- Lexical variables with `as $name`, variable references, and dynamic mapping/sequence indexes.
- A yq-shaped `reduce SOURCE as $item (INITIAL; UPDATE)` evaluator.
- Recursive mapping merge with `*`, while retaining numeric multiplication.
- Unicode `\u` and `\U` escapes, multiline flow collections, and explicit block-scalar indentation indicators.
- Multi-document in-place transformations evaluated independently against every document.
- Hybrid presentation preservation: safe scalar replacements retain comments, blank lines, layout, and plain/single/double quote style.
- Seven new behavioral groups covering the evaluator, parser, multi-document writer, and presentation layer, bringing the suite to 64 tests.

### Changed

- Pipe parsing is right-associative so variable binding receives the correct current input.
- Structural in-place changes use the deterministic semantic YAML emitter; scalar-only changes patch the original source.
- `unique` preserves first-occurrence order, matching yq v4.53.3.

### Known boundaries

- Presentation preservation currently applies to scalar replacements. Construction, deletion, deep merge, flow-node edits, and other structural changes intentionally fall back to semantic YAML.
- Collection-valued mapping keys, recursive aliases, full schema-dependent resolution, every block-folding edge case, and complete YAML specification validation remain outside the parser contract.
- Regexes, string interpolation, slices, date/time operators, file-loading operators, comment/style mutation operators, and non-YAML codecs remain outside the expression language.
- In-place mode uses POSIX `cp` and `rm`; all other operation continues to require only `/bin/sh` and AWK.

## [1.2.0] - 2026-08-01

Version 1.2 turns the expression stream into a writable graph and adds a semantic YAML emitter. YAML.sh can now construct, transform, and safely rewrite documents while keeping its one-file `/bin/sh` + AWK runtime.

### Added

- Recursive descent with `..` and optional traversal with `?`.
- Array and object construction, including streamed values inside array literals.
- Arithmetic with `+`, `-`, `*`, `/`, and `%`; `+` also concatenates strings and sequences, shallow-merges mappings, and treats null as an identity value.
- Direct assignment with `=`, relative update with `|=`, and compound `+=`, `-=`, `*=`, `/=`, and `%=` updates.
- Missing mapping-path creation, multi-node streamed assignments, and `del(...)` for mappings and sequences.
- Semantic YAML output through `-y` and `-o=yaml`, with valid document separators for multi-result streams.
- Null-input construction with `-n` and permission-preserving in-place file updates with `-i`.
- Transformation, round-trip, arithmetic, error, and in-place coverage, bringing the behavioral suite to 57 tests.

### Changed

- Assignment binds before a following pipe, matching yq transformation flow such as `.value = 2 | .value`.
- Help, README, website, and docs now distinguish semantic YAML preservation from presentation preservation.
- The generated YAML emitter uses deterministic block collections and quoted string/key output.

### Known boundaries

- YAML emission does not preserve comments, blank lines, original scalar quoting, flow-vs-block style, directive spelling, or exact presentation.
- Variables, interpolation, regexes, reducers, dynamic keys, slices, deep-merge operators, style/comment operators, file operators, and yq's non-YAML codecs are not implemented.
- Aliases are shared graph references. Updating through an alias or inherited merge key may update its anchor or merge source.
- In-place mode requires a real single-document file, rejects multi-document streams before replacement, and uses the POSIX `cp` and `rm` utilities in addition to the normal `/bin/sh` + AWK runtime.

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

[1.6.0]: https://github.com/azohra/yaml.sh/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/azohra/yaml.sh/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/azohra/yaml.sh/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/azohra/yaml.sh/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/azohra/yaml.sh/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/azohra/yaml.sh/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/azohra/yaml.sh/compare/v0.4.0...v1.0.0
[0.4.0]: https://github.com/azohra/yaml.sh/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/azohra/yaml.sh/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/azohra/yaml.sh/releases/tag/v0.2.1
