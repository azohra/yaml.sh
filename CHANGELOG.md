# Changelog

All notable changes to YAML.sh are documented here.

## Unreleased

## [1.17.1] - 2026-08-03

Version 1.17.1 is a refinement round: dead code, duplication, and stale claims are removed without changing documented v1 behavior.

### Fixed

- The README object-construction example now quotes its array values, and the alternate-directory install command shows the full pipe form.
- Documentation no longer conflates CLI input/output formats with expression-only codecs, and the operator quick reference no longer lists `delpaths` twice.

### Maintenance

- Parser, codec, evaluator, and CLI sources drop unused variables, unreachable branches, a no-op TOML escape wrapper, and the flow-piece save/restore apparatus in favor of per-call locals; repeated slice, quote-run, document-root, and explain-mutation logic moved into shared helpers.
- Codec entry points follow one `codec_` naming convention, and the unified-diff renderer drops its duplicate line-number arrays.
- CI lints the docs tooling and the AWK fault shim, verifies the committed `ysh` matches a fresh build from `src/`, and conformance gates honor `YSH_BINARY` like their siblings.
- Test summaries are computed from what actually ran instead of hard-coded strings, and fuzz failure bundles only include edit artifacts for the mutation property.

### Compatibility

- No documented CLI, query, output, or YAML interpretation changes. The rebuilt artifact is behaviorally identical; all release gates were rerun.

## [1.17.0] - 2026-08-03

Version 1.17 makes YAML.sh easier to understand, restrict, and maintain without changing documented v1 behavior.

### Added

- `--security-disable-eval`, so environment reads, query-selected file reads, and dynamic expression evaluation are independently controllable.
- Edit-mode dependency preflight with a precise diagnostic for missing host file utilities.

### Changed

- Help and documentation lead with useful YAML work, explain the runtime dependencies plainly, and distinguish trusted documents from query programs and optional local access.
- The website and project story centre the one-file YAML tool instead of release machinery, corpus totals, or comparison with another product.

### Maintenance

- Development AWK is organized into ordered parser, graph, evaluator, validation, emitter, and source-edit modules while the release remains one executable.
- Explicit operator-family dispatch replaces the evaluator's central 1,200-line branch. Sparse graph metadata lowers peak memory on the 125,000-node parser workload by about 10 MiB on the release machine without slowing it.
- `DESIGN.md`, contributor guidance, and a machine-readable capability map make product decisions and their exact evidence easier to inspect.
- A case-by-case YAML Test Suite outcome manifest replaces separate pass-count lists, and the structural fuzz matrix no longer repeats identical shapes with different scalar values.

### Compatibility

- The v1 CLI and documented query behavior remain compatible. The new security switch is opt-in.

## [1.16.0] - 2026-08-02

Version 1.16 turns the node graph into a portable configuration contract engine.

### Added

- RFC 6901 JSON Pointer; RFC 6902 patch application and deterministic generation, verified by 108 external corpus assertions; RFC 7396 Merge Patch.
- A fail-closed JSON Schema 2020-12 profile with local references, path-aware value-free errors, 701 focused official assertions, and shared depth/node limits.
- TOML 1.0, nested INI, and secure XML data codecs. The TOML decoder and encoder each pass all 205 official valid fixtures; the decoder rejects 462/474 invalid fixtures, with the raw-byte boundary documented and pinned.
- `-p/--input-format`, TOML/INI/XML output, `--schema`, `--apply-patch`, `--merge-patch`, and `--generate-patch`.
- `root`, plus explicit evidence for existing string slicing.

### Changed

- Patch, schema, and codec paths operate directly on the existing graph rather than converting through an external runtime.
- CLI patches feed the source-aware YAML edit compiler, including strict comment-preserving in-place changes and transactional multi-file writes.
- Release evidence now includes pinned TOML 1.0 and JSON Schema 2020-12 suites. The weekly evidence job owns those networked oracles; ordinary page edits do not run them.

### Boundaries

- Non-YAML input is semantic, one-document conversion; source-aware in-place editing remains YAML-only.
- XML rejects DTDs and custom entities and uses the documented `+@attribute` / `+content` data shape.
- JSON Schema uses POSIX ERE, local `$ref`, and the documented validation vocabulary; remote/dynamic references and annotation-driven unevaluated vocabularies are not implied.
- The portable baseline excludes twelve TOML invalid fixtures that require raw-byte distinctions unavailable consistently across AWK record/string APIs: bare CR, embedded NUL, invalid UTF-8, and UTF-16 input. Hosts that expose NUL reject five more.

## [1.15.0] - 2026-08-02

Version 1.15 closes the portable utility layer without adding a runtime.

### Added

- JSON, YAML, properties, CSV, TSV, Base64, URI, and shell encode/decode forms, including the yq shorthand aliases.
- Bounded dynamic `eval`; byte-limited `load`, `load_str`, `load_base64`, and `load_props`; `--security-disable-file-ops`.
- Portable `shuffle` with reproducible `--shuffle-seed`, plus writable `ref` bindings.
- Exact block and multiline-flow value/key columns; readable and writable value/key head, line, and foot comments.
- Strict source plans for inserting, replacing, and removing full-line block comments.

### Changed

- Utility evaluation is isolated from the core traversal/update path and every embedded parser shares the graph and resource ceilings.
- The operator manifest, query guide, security model, compatibility map, site, README, and story now describe the expanded contract directly.
- Real-workload profiling retains the 125,000-node, 1,500-document, and exact large-file edit contracts without adding arbitrary gates.

### Boundaries

- XML, date/time, system execution, regex capture objects, and yq's format-heavy CLI remain explicit boundaries.
- Properties use dotted paths; CSV and TSV decode header-row objects. Full yq format flags are not implied.

## [1.14.0] - 2026-08-02

Version 1.14 closes the useful portable operator surface and makes its boundary auditable.

### Added

- `trim`, `to_string`, `column`, `array_to_map`, and `split_doc`.
- Recursive `sort_keys(..)` and whole-stream `ireduce` in `eval-all`.
- An operator manifest covering every YAML-oriented yq area as supported, focused, or deliberately excluded, with named evidence for every row.
- A parser-boundary gate for valid neighboring syntax and fail-closed rejections.

### Changed

- Source-context and string evaluators are isolated from the central dispatch.
- Fast paths skip comment and flow scans on ordinary lines; the 5,000-record benchmark is roughly twice as fast on the release machine.
- README, docs, site, and story describe useful jobs and guarantees instead of using corpus size as product copy.

### Boundaries

- `column` covers block value/key nodes; generated nodes return 0 and flow-child columns remain focused.
- `split_doc` is explicit and idempotent because YAML.sh already separates every YAML stream result into a valid document.
- Dates, codecs, loads, dynamic evaluation, system execution, regex capture objects, and random shuffle remain excluded.

## [1.13.0] - 2026-08-02

Version 1.13 makes source fidelity a compiled edit plan rather than a mutation-time guess.

### Added

- Post-evaluation source-edit compilation validates non-overlapping replacements, deletions, moves, and insertions before a candidate is emitted.
- Strict source edits for single- and multiline flow collections, literal/folded block scalars, and multiline quoted scalars.
- Comment-carrying block mapping reorders and block sequence-record deletions.
- `source_edits` in text and JSON explanations reports the prepared source operation count without exposing values.

### Changed

- Flow edits rewrite only their owned collection span; source outside that span remains byte-identical. Flow whitespace and key quoting inside the changed span may normalize.
- Attached comments move with reordered mapping entries and are removed with deleted sequence records.
- Updates through aliases and merge keys retain shared node ownership, so the anchor source changes while alias and merge occurrences remain intact.
- The presentation evidence gate now covers exact preview and commit for flow, block scalar, reorder, and record spans in addition to scalar-style combinations.

### Boundaries

- Head/foot comments and mapping-key nodes are still not writable graph objects.
- Strict mode refuses multiline flow compaction when the owned span contains internal comments; trailing comments after the closing delimiter are preserved.
- A structural edit without a safe, non-overlapping source plan still uses semantic YAML, or fails before candidate output under `--preserve-only`.

## [1.12.0] - 2026-08-02

Version 1.12 makes repository updates conditional on the files that were actually evaluated.

### Added

- `error(MESSAGE)` matches yq's explicit query-abort behavior and composes with short-circuiting `and`/`or` for validation guards.
- Content-drift checks before candidate reporting, before commit, and immediately before each changed file is replaced.

### Changed

- Check, diff, and in-place operations parse preserved source snapshots. Candidates and rollback material now come from the same evaluated bytes.
- Rollback restores the pre-evaluation snapshots instead of copying possibly changed live inputs during commit.
- Equivalent path spellings are detected as duplicate transaction inputs; newline-containing input names are rejected explicitly.

### Boundaries

- Each sibling-file rename is atomic; a multi-file commit is preflighted and rollback-capable, not one globally atomic filesystem operation.
- An unrelated writer can still race after the final comparison, and POSIX shell cannot promise power-loss durability. Use version control and normal backups.

## [1.11.0] - 2026-08-02

Version 1.11 makes edits reviewable before they become writes.

### Added

- `--diff` renders the exact prepared transaction as unified diffs without changing a file. It returns clean `0`, drift `1`, or error `2`.
- `--preserve-only` rejects an edit when YAML.sh cannot retain the source presentation instead of silently regenerating it.
- Presentation-preserving append support for block sequences and ordinary block mappings.

### Changed

- `--check`, `--diff`, `--explain`, and `-i` now consume the same prepared candidates. A mutation that returns to the original bytes is a true no-op, reported as `"changed":false` in JSON explanations.
- The built-in diff renderer uses a bounded trace and an exact large-change fallback, keeping the one-file POSIX shell + AWK runtime.
- Property, presentation, transaction, and existing scale gates now exercise no-write previews and strict edits.

### Boundaries

- Strict mode intentionally rejects flow-layout rewrites and transformations that materialize shared aliases. Run `--diff` without `--preserve-only` when semantic YAML regeneration is acceptable.
- Unified diff output contains the changed values. `--explain=json` remains the value-free audit format.

## [1.10.0] - 2026-08-02

Version 1.10 makes the repository the unit of work: one compiled query, one AWK process, and one preflighted transaction.

### Added

- `--check` runs the real write path without writing and returns clean `0`, drift `1`, or error `2`.
- Writable `eval-all` can bind data from one file, update several others, and commit every mutation together.
- Merge policies for appended arrays (`*+`), arrays merged by index (`*d`), existing fields only (`*?`), and new fields only (`*n`).

### Changed

- Ordinary multi-file reads and repository transactions parse and compile once instead of launching AWK for every file.
- No-op assignments produce no mutation record, candidate, rollback copy, or file replacement.
- Empty inputs retain correct file indexes inside combined operations.
- Generated evidence now covers an explicit 672-cell grammar/property matrix and a 9-cell presentation matrix. Scheduled runs rotate four value sweeps instead of repeating thousands of equivalent shapes.

### Boundaries

- Writable `eval-all` covers cross-file selection, binding, merging, and updates; it is not yq's complete stream engine.
- Merge tag clobbering (`*c`) remains outside the focused merge-policy set.

## [1.9.0] - 2026-08-02

Version 1.9 makes YAML.sh safe at repository scale: one transaction can update several files, YAML graph metadata is writable, and CI can retain machine-readable change evidence without retaining values.

### Added

- Preflighted multi-file `-i`: every input parses and transforms before the first replacement; commit failure or interruption rolls changed files back from preserved siblings.
- `--explain=json` emits one JSON Lines audit record per input with counts, paths, mutation kinds, and the presentation decision, never changed values.
- Writable `tag`, `anchor`, and `alias` properties. Anchor renames keep referring aliases valid; unsafe removal and recursive references fail explicitly.
- Literal and folded scalar style conversion, collection style reset, `-I`/`--indent`, and `--unwrap-scalar=false`.
- A YAML-metadata differential family covering 22/22 graph and presentation programs against yq v4.53.3.

### Changed

- The categorized yq corpus grows to 2,620/2,620 programs and the behavioral suite to 94 tests.
- In-place writes reject duplicate inputs and symlinks before committing. Single-file updates use the same transaction path as repository-wide edits.
- Transaction preparation, cleanup, rollback, and interruption handling are explicit shell functions while the released runtime remains one readable POSIX shell + AWK file.

### Boundaries

- Head/foot comments and key-node presentation remain outside the graph. Line comments and scalar/collection styles are writable.
- Codecs, file loading, dynamic evaluation, date/time, regex captures, and randomized operators remain deliberate non-goals.

## [1.8.0] - 2026-08-02

Version 1.8 makes YAML-aware automation more surgical: computed transformations, explicit graph and presentation controls, and explainable in-place edits remain portable to plain POSIX shell and AWK.

### Added

- `ireduce`, computed object keys, `setpath`, and `delpaths` for dynamic configuration transforms.
- `anchor`, `alias`, and `explode` for inspecting and materializing YAML graph relationships.
- `style` and `line_comment` inspection; scalar quote style, collection flow style, and line comments can be edited with yq-shaped property assignments.
- `--explain` reports result counts, mutation kinds and paths, generated nodes, and whether an in-place edit preserved or regenerated presentation. It never prints changed values.
- A 35-case real-world corpus spanning Kubernetes, Compose, GitHub Actions, GitLab CI, and deployment overlays, compared directly with yq v4.53.3.

### Changed

- Replaced Docsify, hash routing, CDN scripts, and runtime Markdown rendering with committed static HTML generated by portable shell and AWK.
- Rebuilt documentation navigation, local search, code copying, mobile layout, real URL paths, sticky-header anchor offsets, and regression checks.
- Rewrote the README around the premise, useful tasks, measured trust, and honest boundaries; added recipe and security guides.
- Replaced per-release artwork with an evergreen SVG identity and one timeless `POSIX` social card; release numbers are generated text.
- Generated installers now receive the release artifact checksum from the docs build, removing a manual release-sync trap.

### Boundaries

- Style editing covers plain, single-quoted, and double-quoted scalars plus flow collections. Literal/folded block-style conversion and head/foot comment operators remain outside the current writer.
- Load, dynamic evaluation, date/time, non-YAML codecs, and advanced regex captures remain outside the portable runtime.

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
- The hosted installer downloads the release artifact and verifies its pinned SHA-256 digest before writing anything to the install directory.
- Pull requests and main run the fast cross-OS, cross-AWK portability matrix; exhaustive conformance, differential, fuzz, presentation, adversarial, and scale evidence runs on demand before releases and on a weekly schedule.
- Versioned site, docs, installer, README, and social artwork identified v1.7 consistently at release time.

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

[1.17.1]: https://github.com/azohra/yaml.sh/compare/v1.17.0...v1.17.1
[1.17.0]: https://github.com/azohra/yaml.sh/compare/v1.16.0...v1.17.0
[1.16.0]: https://github.com/azohra/yaml.sh/compare/v1.15.0...v1.16.0
[1.15.0]: https://github.com/azohra/yaml.sh/compare/v1.14.0...v1.15.0
[1.14.0]: https://github.com/azohra/yaml.sh/compare/v1.13.0...v1.14.0
[1.13.0]: https://github.com/azohra/yaml.sh/compare/v1.12.0...v1.13.0
[1.12.0]: https://github.com/azohra/yaml.sh/compare/v1.11.0...v1.12.0
[1.11.0]: https://github.com/azohra/yaml.sh/compare/v1.10.0...v1.11.0
[1.10.0]: https://github.com/azohra/yaml.sh/compare/v1.9.0...v1.10.0
[1.9.0]: https://github.com/azohra/yaml.sh/compare/v1.8.0...v1.9.0
[1.8.0]: https://github.com/azohra/yaml.sh/compare/v1.7.0...v1.8.0
[1.7.0]: https://github.com/azohra/yaml.sh/compare/v1.6.0...v1.7.0
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
