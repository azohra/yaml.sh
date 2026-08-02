# YAML support

YAML.sh is a query-oriented YAML implementation with a tested support contract. Supported syntax is represented in the node graph and exercised by the suite; limitations are intentional boundaries rather than silent guesses.

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

- `%YAML` directives, with duplicate and malformed directives rejected.
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
- Source lines retained on nodes.
- Anchor, alias, scalar/flow style, and line-comment metadata available to queries.

## Intentional limitations

- Aliases must refer to an earlier anchor in the same document.
- Recursive object graphs are rejected because value and JSON output cannot represent cycles safely.
- Anchor names may contain Unicode and punctuation except whitespace and flow delimiters.
- Collection-valued mapping keys are rejected. Explicit scalar keys are supported.
- Tags and anchors before scalar keys are accepted, but mapping keys remain text in the graph.
- Full YAML 1.1/1.2 schema resolution and application-specific construction are not implemented.
- Semantic YAML emission preserves data, node kinds, tags, anchors, aliases, merge edges, recorded line comments, and supported scalar/flow styles where representable. It does not reconstruct original spacing or head/foot comments.
- Common in-place replacements, direct block inserts/deletes, and pure sequence reorders preserve comments, whitespace, quoting, block/flow style, anchors, tags, and directives. Other structural changes fall back to semantic YAML.
- Updating through an alias or inherited merge value follows shared node identity and can change the anchor or merge source.
- Sequence slices, scalar interpolation, grouping, `ireduce`, computed object keys, `setpath`/`delpaths`, and POSIX-ERE `test`/global `sub` are supported. Regex flags, captures, and backreferences are not portable and remain outside the contract.
- `style` can inspect all recognized styles and set plain/single/double scalar or flow collection styles. `line_comment` can inspect and set line comments. Literal/folded conversion and head/foot comment operators remain outside the writer.
- The expression language does not implement file-loading operators, date operators, dynamic evaluation, or yq's non-YAML codecs.

YAML.sh does not evaluate YAML as shell code. Input size, node count, and depth have configurable limits. Use a maintained full YAML library when application-specific construction or certification beyond this contract is required.

## Measured boundary

Pinned release gates:

| Gate | v1.8 |
| --- | ---: |
| YAML Test Suite expected outcomes | 282/282 |
| YAML Test Suite strict-invalid inputs rejected | 91/91 |
| Categorized programs matching yq v4.53.3 | 2,610/2,610 |
| Real-world workflow programs matching yq v4.53.3 | 35/35 |
| Cross-file programs matching yq v4.53.3 | 8/8 |
| Behavioral tests | 90 |
| Grammar-guided generated properties | 12,000/12,000 |
| Exact presentation mutations | 400/400 |
| Scale contract | 125,000 payload nodes; 1,500 documents; at most 224 MiB RSS |

Three YAML Test Suite cases contain partial-event JSON but are marked errors; YAML.sh correctly counts their rejection rather than imitating a partial AST. These measurements are not a claim of universal YAML or yq compliance. CI spans macOS AWK, mawk, original AWK, POSIX-mode gawk, BusyBox AWK, and multiple POSIX shells.

## Fixtures

The focused fixtures cover parser syntax, graph semantics, query behavior, presentation preservation, and rejection boundaries. A separate workflow corpus exercises Kubernetes, Compose, GitHub Actions, GitLab CI, and deployment overlays against yq.

See [`test/test.sh`](https://github.com/azohra/yaml.sh/blob/main/test/test.sh), [`test/conformance.sh`](https://github.com/azohra/yaml.sh/blob/main/test/conformance.sh), [`test/differential.sh`](https://github.com/azohra/yaml.sh/blob/main/test/differential.sh), [`test/fuzz.sh`](https://github.com/azohra/yaml.sh/blob/main/test/fuzz.sh), and [`bench/scale.sh`](https://github.com/azohra/yaml.sh/blob/main/bench/scale.sh).
