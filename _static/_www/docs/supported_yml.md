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

## Intentional limitations

- Aliases must refer to an earlier anchor in the same document.
- Recursive object graphs are rejected because value and JSON output cannot represent cycles safely.
- Anchor names may contain Unicode and punctuation except whitespace and flow delimiters.
- Collection-valued mapping keys are rejected. Explicit scalar keys are supported.
- Tags and anchors before scalar keys are accepted, but mapping keys remain text in the graph.
- Several exact block-folding, chomping, indentation, tab, and document-boundary edge cases remain unsupported.
- Full YAML 1.1/1.2 schema resolution and application-specific construction are not implemented.
- Semantic YAML emission preserves data, node kinds, tags, anchors, aliases, and merge edges where representable, but not comments or original presentation style.
- In-place scalar edits, direct block inserts/deletes, and pure sequence reorders preserve surrounding presentation. Other structural changes fall back to semantic YAML.
- Updating through an alias or inherited merge value follows shared node identity and can change the anchor or merge source.
- The expression language does not implement interpolation, regular expressions, slices, grouping, ireduce, comment/style mutation operators, file-loading operators, or yq's non-YAML codecs.

YAML.sh does not evaluate YAML as shell code, but it is not a complete specification validator. Use a maintained full YAML library when exact conformance for arbitrary or hostile input is a hard requirement.

## Measured boundary

Pinned release gates:

| Gate | v1.4 |
| --- | ---: |
| YAML Test Suite semantic loads | 245/282 |
| YAML Test Suite invalid inputs rejected | 56/91 |
| Shared programs matching yq v4.53.3 | 110/110 |
| Behavioral tests | 70 |

These are compatibility measurements, not a claim of full YAML or yq compliance. CI runs them with mawk and BusyBox AWK; macOS also runs the behavioral suite.

## Fixtures

The advanced fixture covers anchors, collection aliases, merge precedence, block merge lists, directives, expanded tags, scalar types, explicit keys, empty collections, punctuated keys, and document scoping. The expression fixture covers streams, filters, construction, arithmetic, recursion, assignments, maps, entries, variables, dynamic indexes, reducers, deep merge, YAML round-tripping, multi-document updates, and presentation preservation. Rejection tests cover boundaries that could otherwise be misread as supported syntax.

See [`test/test.sh`](https://github.com/azohra/yaml.sh/blob/main/test/test.sh), [`test/conformance.sh`](https://github.com/azohra/yaml.sh/blob/main/test/conformance.sh), and [`test/differential.sh`](https://github.com/azohra/yaml.sh/blob/main/test/differential.sh).
