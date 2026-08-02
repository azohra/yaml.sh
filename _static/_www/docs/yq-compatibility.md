# yq compatibility

YAML.sh follows yq syntax where that syntax can stay readable in one POSIX shell and portable AWK program. This is a capability map, not a claim that YAML.sh is a drop-in yq replacement.

## The useful core

| Area | Status | Included |
|---|---|---|
| Traverse and streams | Strong | paths, dynamic keys, indexes, optional traversal, recursive descent, pipes, unions, slices |
| Select and logic | Strong | `select`, `filter`, comparisons, `and`, `or`, `not`, `//`, `any`, `all` |
| Build and mutate | Strong | arrays, computed keys, reducers, `=`, `|=`, compound updates, `setpath`, `delpaths`, `del`, `with`, deep merge |
| Collections | Strong | `map`, `map_values`, entries, sort/group/unique/min/max families, flatten, reverse, add, first, pick, omit, pivot |
| Context | Strong | `path`, `parent`, `key`, `line`, `tag`, `filename`, `fileIndex`, `documentIndex` |
| Environment | Strong | `env`, `strenv`, `envsubst`, defaults, `nu`/`ne`/`ff`, security disable switch |
| Files and documents | Focused | normal evaluation over many files; all-document mode; practical `eval-all`, slurp, metadata, and cross-file merge |
| Strings | Focused | interpolation, split/join, case, contains/prefix/suffix, POSIX `test` and `sub` |
| YAML graph | Focused | anchors and aliases retain identity; `anchor`, `alias`, and `explode` inspect or materialize relationships |
| YAML presentation | Focused | comments and styles survive common edits; `style` and `line_comment` inspect and edit the supported subset |

“Strong” still means the forms covered by the test suite, not every obscure polymorphic combination accepted by yq.

## Where YAML.sh wins

YAML.sh is not trying to outgrow yq. It is optimized for a different boundary:

- The executable is readable source: one POSIX shell file with its portable AWK engine embedded.
- It runs where `/bin/sh` and AWK already exist, including BusyBox, old macOS, and minimal recovery systems.
- Input bytes, graph nodes, and collection depth are bounded; file-loading and dynamic-code operators do not exist, and environment access can be disabled.
- `--ast` and `--events` expose the parser directly when a strange document needs explaining.
- Every release pins semantic YAML outcomes, strict-invalid rejection, differential programs, generated properties, presentation edits, and a time/memory scale contract.

yq remains the better choice for its complete operator surface, many codecs, polished platform packaging, and broad ecosystem. YAML.sh is strongest when inspectability, runtime reach, and a deliberately narrow security model matter more than total surface area.

## Deliberate boundary

| Not implemented | Why |
|---|---|
| XML, CSV, TSV, TOML, INI, properties, Base64, URI codecs | YAML.sh is a YAML tool; codecs would add a second product and substantial code. |
| `load*`, dynamic `eval`, system execution | File and code execution widen the security model and audit surface. |
| Date/time and timezone operators | Portable AWK has no reliable cross-platform date library. |
| Head/foot comments; literal/folded style conversion | Line comments and common scalar/flow styles are first-class; the remaining writer surface is deliberately smaller. |
| `match` captures, named captures, regex flags | AWK regex is intentionally the portable POSIX intersection. |
| `shuffle` | Portable deterministic behavior would not match yq's randomized output. |
| Complete yq CLI flag parity | Format conversion, colors, XML flags, splitting, shell completion, and similar surfaces are out of scope. |

Some areas remain partial: anchor and tag syntax is parsed and emitted, but anchor/alias/tag setters are not implemented; `eval-all` covers slurp, metadata, filtering, construction, and practical merges but is not a general clone of yq's stream engine.

## Measured, not hand-waved

The release suite pins mikefarah/yq v4.53.3 and compares canonical JSON across categorized, real-world workflow, and cross-file programs. See the [support contract](supported_yml.md) for current counts and the repository's test corpora for every query.

If a form is not in the query guide or tests, treat it as unsupported even when a nearby form works.
