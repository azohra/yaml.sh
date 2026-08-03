# yq compatibility

YAML.sh follows yq syntax where that syntax can stay readable in one POSIX shell and portable AWK program. This is a capability map, not a claim that YAML.sh is a drop-in yq replacement.

## The useful core

| Area | Status | Included |
|---|---|---|
| Traverse and streams | Strong | paths, dynamic keys, indexes, optional traversal, recursive descent, pipes, unions, slices |
| Select and logic | Strong | `select`, `filter`, comparisons, short-circuiting `and`/`or`, `not`, `//`, `any`, `all`, `error` guards |
| Build and mutate | Strong | arrays, computed keys, reducers, `=`, `|=`, compound updates, `setpath`, `delpaths`, `del`, `with`, deep merge and `*+`/`*d`/`*?`/`*n` policies |
| Collections | Strong | `map`, `map_values`, entries, sort/group/unique/min/max families, recursive key sorting, flatten, reverse, `array_to_map`, add, first, pick, omit, pivot |
| Context | Strong | `path`, `parent`, `key`, exact block/flow `line` and `column`, `tag`, `filename`, `fileIndex`, `documentIndex` |
| Environment | Strong | `env`, `strenv`, `envsubst`, defaults, `nu`/`ne`/`ff`, security disable switch |
| Files and documents | Strong | one-process multi-file evaluation; all-document mode; whole-stream reduction; `split_doc`; writable cross-file `eval-all`; exact no-write diffs; snapshot-guarded transactions |
| Portable utilities | Focused | JSON, YAML, properties, CSV, TSV, Base64, URI, and shell codecs; dynamic `eval`; guarded loads; reproducible shuffle |
| Strings | Focused | interpolation, trim, string conversion, split/join, case, contains/prefix/suffix, POSIX `test` and `sub` |
| YAML graph | Strong | anchors and aliases retain identity; `tag`, `anchor`, and `alias` are writable; `explode` materializes relationships |
| YAML presentation | Strong | exact source coordinates; writable value/key head, line, and foot comments; compiled scalar, flow, block, record, comment, and reorder spans |

“Strong” means the common forms documented and tested here. It does not mean every polymorphic combination accepted by yq.

## Where YAML.sh wins

YAML.sh is not trying to outgrow yq. It is optimized for a different boundary:

- The executable is readable source: one POSIX shell file with its portable AWK engine embedded.
- It runs where `/bin/sh` and AWK already exist, including BusyBox, old macOS, and minimal recovery systems.
- Input bytes, graph nodes, collection depth, embedded parses, and dynamic evaluation are bounded. Environment and file operators have separate disable switches.
- `--ast` and `--events` expose the parser directly when a strange document needs explaining.
- `--check`, `--diff`, and `-i` share one prepared edit plan. Previewed bytes are committed bytes; net-zero updates are no-ops.
- `--preserve-only` turns source fidelity into an enforceable precondition instead of a best-effort promise.
- Source plans preserve bytes outside changed spans and carry record comments through mapping and sequence moves—useful behavior that ordinary semantic serialization cannot promise.
- Multi-file queries compile once. Writable `eval-all` can read one file, mutate several others, refuse detected source drift, skip no-ops, and roll back commit failures from the evaluated snapshots.
- `--explain=json` produces one value-free audit record per input for CI.
- Parser outcomes, invalid input, yq comparisons, presentation edits, and useful scale are covered by repeatable tests.

yq remains the better choice for complete XML/date/format support, polished platform packaging, and its broad ecosystem. YAML.sh is strongest when inspectability, runtime reach, exact source-aware repository edits, and a small controllable security model matter most.

## Deliberate boundary

| Boundary | Contract |
|---|---|
| XML, TOML, and INI codecs | No partial parser is advertised. These formats remain explicit errors. |
| Date/time and timezone operators | Portable AWK has no cross-platform timezone database or reliable host date API. |
| System execution | Expressions never launch commands. |
| Regex captures and flags | `test` and global `sub` use the platform's POSIX ERE engine. |
| Complete yq CLI flag parity | YAML.sh does not reproduce format-selection flags, colors, XML flags, shell completion, or plugin surfaces. |

Properties use dotted paths and CSV/TSV use header-row object decoding. XML-specific forms are rejected. Dynamic expressions speak YAML.sh's documented language, and file reads can be disabled with `--security-disable-file-ops`. Anchor renames keep existing aliases valid even where yq leaves their displayed alias name unchanged.

## Compared with yq

The [operator manifest](operators.md) audits every YAML-oriented yq area and names the evidence behind each status. The differential suite then compares those forms with pinned yq v4.53.3 across generated variations, configuration workflows, metadata, and cross-file programs. See [YAML support](supported_yml.md) for parser coverage and limits.

If a form is not in the query guide or tests, treat it as unsupported even when a nearby form works.
