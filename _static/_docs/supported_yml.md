# Supported YAML

YAML.sh supports the following practical subset:

- nested mappings using space indentation;
- block lists in indented and indentationless styles;
- flow lists (`[one, two]`) and nested flow mappings (`{name: feature, details: {priority: medium}}`);
- expanded and flow-style objects inside lists;
- plain, single-quoted, and double-quoted scalar values;
- literal (`|`) and folded (`>`) block scalars, including `-` and `+` chomping indicators;
- comments, blank lines, CRLF input, and multiple documents separated by `---`.

```yaml
---
project:
  name: yaml.sh
  maintainers: [one, two]
  metadata: {language: shell, parser: awk}
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

YAML.sh does not implement the entire YAML specification. Anchors, aliases, tags, directives, explicit complex keys, merge keys, and full schema/type resolution are outside its scope. Scalar values are returned as text.
