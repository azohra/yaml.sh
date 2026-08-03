# Coming from yq

YAML.sh uses familiar yq-style paths, pipes, filters, construction, and assignment. Many everyday expressions transfer directly; YAML.sh is not a drop-in replacement for every yq program or CLI flag.

## Expressions that usually transfer

```sh
ysh '.services[].name' config.yml
ysh '.services[] | select(.enabled) | .name' config.yml
ysh '.image.tag = "stable"' config.yml
ysh '.metadata | with_entries(.value |= upcase)' config.yml
```

The closest overlap covers:

- paths, indexes, optional and recursive traversal, pipes, unions, and sequence slices;
- filters, scalar comparisons, boolean operators, defaults, and error guards;
- arrays, objects, variables, reducers, assignment, deletion, scoped updates, and deep merges;
- mapping and sequence helpers for entries, sorting, grouping, uniqueness, selection, and reshaping;
- environment values, file and document context, aliases, anchors, tags, styles, and comments;
- multi-document and multi-file evaluation, including writable `eval-all`.

Check the [operator reference](operators.md) before moving a large expression. A familiar operator name may have a deliberately smaller set of accepted inputs.

## Important differences

| Area | YAML.sh behavior |
|---|---|
| Collections and equality | `==` and `!=` compare scalar values; mappings and sequences do not use structural equality. |
| Regular expressions | `test` and global `sub` use the host AWK's POSIX ERE engine. Flags, capture objects, and replacement backreferences are not supported. |
| Date and time | Date/time query operators are not currently implemented. TOML date/time values can still be decoded and encoded. |
| XML | XML is a data codec with a documented `+@attribute` / `+content` shape, not XPath or yq's full XML flag surface. |
| Other formats | TOML, INI, and XML are semantic one-document codecs. Presentation-preserving in-place edits are YAML-only. |
| System execution | Expressions do not launch commands. |
| CLI surface | YAML.sh does not reproduce yq's color, shell-completion, XML-tuning, or complete format-specific flag surface. |

If a form is absent from the [query guide](queries.md) and [operator reference](operators.md), treat it as unsupported even when a nearby yq form works.

## What is specifically YAML.sh

YAML.sh's main constraint is also its main difference: the complete executable is one readable POSIX shell file with portable AWK inside.

For in-place YAML edits, `--diff`, `--check`, and `-i` use the same prepared candidate. Common changes preserve comments and unrelated formatting, while `--preserve-only` turns preservation into a requirement. Multi-file edits are prepared from snapshots before writing and refuse files that change during the run. See [documents and file edits](documents.md) for the exact behavior.

`--ast` and `--events` expose how YAML was parsed. Input size, graph size, and nesting have configurable limits, and environment access, query-selected file reads, and dynamic evaluation can be disabled separately.

Use yq when a script needs its complete language, flags, packaging, or ecosystem. Use YAML.sh when the one-file implementation, portable runtime, YAML-preserving edits, or inspectable parser is the interesting part.
