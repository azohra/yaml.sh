# Supported YAML

YAML.sh is a query-oriented YAML subset. This page is its support contract: syntax listed as supported is covered by the test suite, while the limitations below are expected behavior rather than undocumented parser gaps.

## Supported syntax

- Nested mappings using space indentation.
- Block lists in indented and indentationless styles.
- Flow lists (`[one, two]`) and nested flow mappings (`{name: feature, details: {priority: medium}}`).
- Expanded and flow-style objects inside lists.
- Plain, single-quoted, and double-quoted scalar values.
- Common literal (`|`) and folded (`>`) block scalars, including `-` and `+` chomping indicators.
- Comments, blank lines, CRLF input, and multiple documents separated by `---` and `...`.
- Backward scalar, mapping, and sequence aliases. Anchors are scoped to one document and may be redefined for later aliases.
- Merge keys from a mapping alias, an inline alias list, or a flow mapping. Earlier aliases in a merge list take precedence; explicit keys take precedence over merged keys.
- `%YAML 1.1`, `%YAML 1.2`, and syntactically valid `%TAG` directives.
- Standard and application tag syntax on scalar nodes.
- Explicit scalar mapping keys using `? key` and `: value`.
- Duplicate-key and flattened-path collision detection.

```yaml
---
project:
  name: yaml.sh
  maintainers: [one, two]
  metadata: {language: shell, parser: awk}
defaults: &defaults
  enabled: true
production:
  <<: *defaults
  replicas: 3
indented:
  - first
  - second
indentless:
- first
- second
objects:
  - name: expanded
    enabled: true
  - {name: flow, enabled: true}
literal: |-
  This value
  spans lines.
folded: >-
  This value is folded
  onto one line.
---
project: another document
```

## Scalar values and types

All query values are returned as text. YAML.sh does not construct language-native nulls, booleans, numbers, timestamps, or application objects. For YAML read from a file or standard input, `--type PATH` reports `string`, `null`, `bool`, `int`, `float`, `timestamp`, or `tagged`.

Standard scalar tags such as `!!str`, `!!bool`, and `!!int` affect this type report. Application tags are accepted and reported as `tagged`; `%TAG` handles are not expanded and application-specific constructors are not run. A `%YAML` directive is validated but does not switch the resolver between YAML schemas.

## Intentional limitations

- Aliases must refer to an earlier anchor in the same document. Forward, undefined, and recursive aliases are rejected.
- Anchor names are limited to letters, digits, `_`, and `-`.
- Merge sources must be mappings. Block-style merge sequences are rejected; use `<<: [*first, *second]`.
- Explicit scalar keys are supported, but collection-valued complex keys such as `? [one, two]` are rejected because they cannot be represented safely in the flattened query path.
- Flow collections must fit on one line. Multiline flow collections are rejected.
- Empty collections produce no scalar records in the flattened output.
- Mapping keys containing `.`, `[` or `]` can collide with query-path syntax and should be avoided; detected collisions are rejected.
- The complete YAML escape repertoire, application tag construction, directives other than `%YAML` and `%TAG`, and full YAML 1.1/1.2 schema resolution are not implemented.
- YAML.sh is not intended as a validator or as a parser for untrusted, specification-heavy input. Use a maintained full YAML library for those cases.
