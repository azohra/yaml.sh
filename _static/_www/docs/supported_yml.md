# YAML support

YAML.sh is a query-oriented YAML implementation with a tested support contract. Supported syntax is represented in the node graph and exercised by the suite; limitations are intentional boundaries rather than silent guesses.

## Collections

- Nested block mappings using space indentation.
- Block sequences in indented and indentationless styles.
- Single-line flow sequences and mappings.
- Expanded and flow mappings inside sequences.
- Empty flow mappings (`{}`) and sequences (`[]`).
- Duplicate mapping-key rejection.
- Scalar explicit keys using `? key` followed by `: value`.

## Scalars

- Plain, single-quoted, and double-quoted scalars.
- Common double-quoted escapes for newlines, tabs, returns, quotes, slashes, and backslashes.
- Literal (`|`) and folded (`>`) block scalars.
- Strip (`-`), clip, and keep (`+`) chomping behavior for common block scalars.
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

- `%YAML 1.1` and `%YAML 1.2` directives.
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
- Anchor names are limited to letters, digits, `_`, and `-`.
- Collection-valued mapping keys are rejected. Explicit scalar keys are supported.
- Anchors and tags on mapping keys are not implemented.
- Flow collections must fit on one line.
- The complete YAML Unicode escape repertoire and every block-folding edge case are not implemented.
- Full YAML 1.1/1.2 schema resolution and application-specific construction are not implemented.
- The query language does not yet provide pipes, wildcards, filters, assignments, or in-place updates.

YAML.sh does not evaluate YAML as shell code, but it is not a complete specification validator. Use a maintained full YAML library when exact conformance for arbitrary or hostile input is a hard requirement.

## Conformance fixture

The advanced fixture covers anchors, collection aliases, merge precedence, block merge lists, directives, expanded tags, scalar types, explicit keys, empty collections, punctuated keys, and document scoping. Rejection tests cover every limitation that could otherwise be misread as supported syntax.

See [`test/advanced.yml`](https://github.com/azohra/yaml.sh/blob/main/test/advanced.yml) and [`test/test.sh`](https://github.com/azohra/yaml.sh/blob/main/test/test.sh).
