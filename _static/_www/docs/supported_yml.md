# YAML support

YAML.sh parses the syntax below into a real node graph and exercises it in the test suite. The limitations section names the nearby forms it does not support.

## Collections

- Nested block mappings using space indentation.
- Block sequences in indented and indentationless styles.
- Single-line flow sequences and mappings.
- Multiline flow sequences and mappings.
- Expanded and flow mappings inside sequences.
- Empty flow mappings (`{}`) and sequences (`[]`).
- Duplicate mapping-key rejection.
- Scalar explicit keys using `? key` followed by `: value`.

## Scalars

- Plain, single-quoted, and double-quoted scalars.
- YAML double-quoted escapes, including `\x`, `\u`, and `\U` code points.
- Multiline plain and quoted scalar folding.
- Literal (`|`) and folded (`>`) block scalars.
- Strip (`-`), clip, and keep (`+`) chomping behavior for common block scalars.
- Explicit block-scalar indentation indicators from 1 through 9.
- Lexical recognition of strings, nulls, booleans, binary/octal/decimal/hexadecimal integers, floats, and timestamps.

Values remain text in default output. Type recognition is used by `--type` and JSON output.

## Anchors, aliases, and merges

- Backward scalar, mapping, and sequence aliases.
- Anchors scoped to one document.
- Anchor redefinition for later aliases.
- Merge keys from one mapping alias.
- Inline merge sequences such as `<<: [*first, *second]`.
- Block merge sequences.
- Flow mapping merge sources.
- Explicit-key precedence over merged keys.
- First-source precedence within merge sequences.
- Undefined, forward, recursive, and non-mapping merge-source validation.

Aliases retain node identity internally. JSON and normal value output resolve aliases to their target content.

## Tags and directives

- `%YAML` directives, with duplicates and malformed versions rejected.
- `%TAG` directives and handle expansion.
- Standard `!!` tags.
- Verbatim tags such as `!<tag:example.com,2026:widget>`.
- Local and application tags on scalar and collection nodes.
- `--tag` inspection using the expanded tag value.

YAML version directives are validated but do not switch between complete YAML 1.1 and YAML 1.2 schema resolvers. Application tags are metadata; YAML.sh does not run constructors or create language-specific objects.

## Streams and source details

- Blank lines and comments.
- Inline comments outside quoted and flow content.
- LF and CRLF input.
- Multiple documents using `---` and `...`.
- Empty explicit documents represented as null.
- Exact source lines and columns for block and multiline flow values and keys; generated nodes report 0.
- Anchor, alias, tag, scalar/collection style, and value/key head, line, and foot comments available to queries and setters.

## Intentional limitations

- Aliases must refer to an earlier anchor in the same document.
- Recursive object graphs are rejected because value and JSON output cannot represent cycles safely.
- Anchor names may contain Unicode and punctuation except whitespace and flow delimiters.
- Collection-valued mapping keys are rejected. Explicit scalar keys are supported.
- Tags and anchors before scalar keys are accepted, but mapping keys remain text in the graph.
- Full YAML 1.1/1.2 schema resolution and application-specific construction are not implemented.
- Semantic YAML emission preserves data, node kinds, tags, anchors, aliases, merge edges, recorded comments, and supported scalar/collection styles where representable. It does not reconstruct unowned spacing.
- In-place source plans cover scalar replacements, single- and multiline flow collections, block scalars, direct block inserts/appends/deletes, comment edits, and pure mapping or sequence reorders. Untouched spans remain byte-identical; changed flow spans use stable flow formatting.
- Updating through an alias or inherited merge value follows shared node identity and can change the anchor or merge source.
- Sequence slices, scalar interpolation, grouping, `ireduce`, computed object keys, `setpath`/`delpaths`, and POSIX-ERE `test`/global `sub` are supported. Regex flags, captures, and backreferences are not portable and remain outside the contract.
- `style` can inspect recognized styles; reset or set plain/single/double/literal/folded scalar styles; and reset or set flow collection styles. `head_comment`, `line_comment`, and `foot_comment` work on values and generated key references. Full-line block comment edits compile into source spans; ambiguous textual comment placement follows yq's emitter conventions.
- `tag`, `anchor`, and `alias` are writable properties. Anchor renames keep referring aliases valid; duplicate anchors, unsafe removal, missing or forward targets, and recursive aliases are rejected.
- Multi-file queries compile once. `--check` reports drift and `--diff` prints exact prepared candidates without writing. `--preserve-only` rejects candidates requiring presentation regeneration. File operations evaluate source snapshots, refuse detected live drift, skip no-ops, reject symlinks and duplicate paths, preserve permissions, and roll back commit failures or interrupts.
- Writable `eval-all` can bind data from one input and update every selected source file in the same transaction.
- Merge modifiers append arrays (`*+`), merge arrays by index (`*d`), update existing fields (`*?`), or add new fields (`*n`).
- The expression language includes bounded dynamic evaluation, policy-controlled YAML/text/Base64/properties loads, and JSON/YAML/properties/CSV/TSV/Base64/URI/shell codecs. Date/time, XML, system execution, and regex capture objects remain outside the contract.

YAML.sh does not evaluate YAML as shell code. Input size, node count, and depth have configurable limits. Use a maintained full YAML library when application-specific construction or certification beyond these tested behaviors is required.

## How it is tested

The pinned YAML Test Suite owns accepted and strict-invalid outcomes. The parser-boundary matrix sits beside it: valid neighboring forms must parse, while malformed directives, collection keys, reserved indicators, malformed escapes, indentation errors, invalid aliases, and merge sources must fail before producing a graph.

Focused fixtures then cover graph semantics, query behavior, presentation preservation, repository transactions, and resource limits. Configuration workflows exercise Kubernetes, Compose, GitHub Actions, GitLab CI, and deployment overlays against yq. The [operator manifest](operators.md) owns expression-language claims.

See [`test/parser-boundaries.sh`](https://github.com/azohra/yaml.sh/blob/main/test/parser-boundaries.sh), [`test/conformance.sh`](https://github.com/azohra/yaml.sh/blob/main/test/conformance.sh), [`test/test.sh`](https://github.com/azohra/yaml.sh/blob/main/test/test.sh), and [`bench/scale.sh`](https://github.com/azohra/yaml.sh/blob/main/bench/scale.sh).
