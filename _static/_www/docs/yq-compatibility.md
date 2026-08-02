# yq compatibility

YAML.sh follows yq syntax where that syntax can stay readable in one POSIX shell and portable AWK program. This is a capability map, not a claim that YAML.sh is a drop-in yq replacement.

## The useful core

| Area | Status | Included |
|---|---|---|
| Traverse and streams | Strong | paths, dynamic keys, indexes, optional traversal, recursive descent, pipes, unions, slices |
| Select and logic | Strong | `select`, `filter`, comparisons, `and`, `or`, `not`, `//`, `any`, `all` |
| Build and mutate | Strong | arrays, computed keys, reducers, `=`, `|=`, compound updates, `setpath`, `delpaths`, `del`, `with`, deep merge and `*+`/`*d`/`*?`/`*n` policies |
| Collections | Strong | `map`, `map_values`, entries, sort/group/unique/min/max families, flatten, reverse, add, first, pick, omit, pivot |
| Context | Strong | `path`, `parent`, `key`, `line`, `tag`, `filename`, `fileIndex`, `documentIndex` |
| Environment | Strong | `env`, `strenv`, `envsubst`, defaults, `nu`/`ne`/`ff`, security disable switch |
| Files and documents | Strong | one-process multi-file evaluation; all-document mode; writable cross-file `eval-all`; no-write checks; preflighted transactions |
| Strings | Focused | interpolation, split/join, case, contains/prefix/suffix, POSIX `test` and `sub` |
| YAML graph | Strong | anchors and aliases retain identity; `tag`, `anchor`, and `alias` are writable; `explode` materializes relationships |
| YAML presentation | Focused | comments and styles survive common edits; line comments and scalar/collection styles are writable |

“Strong” means the common forms documented and tested here. It does not mean every polymorphic combination accepted by yq.

## Where YAML.sh wins

YAML.sh is not trying to outgrow yq. It is optimized for a different boundary:

- The executable is readable source: one POSIX shell file with its portable AWK engine embedded.
- It runs where `/bin/sh` and AWK already exist, including BusyBox, old macOS, and minimal recovery systems.
- Input bytes, graph nodes, and collection depth are bounded; file-loading and dynamic-code operators do not exist, and environment access can be disabled.
- `--ast` and `--events` expose the parser directly when a strange document needs explaining.
- `--check` uses the real write path and reports clean, drift, or error without touching files.
- Multi-file queries compile once. Writable `eval-all` can read one file, mutate several others, preflight the complete set, skip no-ops, and roll back commit failures.
- `--explain=json` produces one value-free audit record per input for CI.
- Parser outcomes, invalid input, yq comparisons, presentation edits, and useful scale are covered by repeatable tests.

yq remains the better choice for its complete operator surface, many codecs, polished platform packaging, and broad ecosystem. YAML.sh is strongest when inspectability, runtime reach, and a deliberately narrow security model matter more than total surface area.

## Deliberate boundary

| Not implemented | Why |
|---|---|
| XML, CSV, TSV, TOML, INI, properties, Base64, URI codecs | YAML.sh is a YAML tool; codecs would add a second product and substantial code. |
| `load*`, dynamic `eval`, system execution | File and code execution widen the security model and audit surface. |
| Date/time and timezone operators | Portable AWK has no reliable cross-platform date library. |
| Head/foot comments and key-node presentation | The graph stores mapping keys as edges rather than full nodes; pretending to support their metadata would be misleading. |
| `match` captures, named captures, regex flags | AWK regex is intentionally the portable POSIX intersection. |
| `shuffle` | Portable deterministic behavior would not match yq's randomized output. |
| Complete yq CLI flag parity | Format conversion, colors, XML flags, splitting, shell completion, and similar surfaces are out of scope. |

Some areas remain partial: `eval-all` supports combined reads, bindings, merges, and cross-file transactions but is not a general clone of yq's stream engine. Anchor renames deliberately keep existing aliases valid, even where yq leaves their displayed alias name unchanged.

## Compared with yq

The suite compares canonical JSON with mikefarah/yq v4.53.3 across 2,628 categorized programs plus Kubernetes, Compose, GitHub Actions, GitLab CI, deployment-overlay, metadata, and cross-file workflows. See [YAML support](supported_yml.md) for parser coverage and limits.

If a form is not in the query guide or tests, treat it as unsupported even when a nearby form works.
