# Output & metadata

The same query can return a value, JSON, a node type, its expanded tag, or its source line.

## Default value output

Scalar nodes print decoded text:

```sh
ysh '.server.host' config.yml
# localhost
```

Mappings and sequences emit compact JSON because a collection cannot be represented safely as one unquoted shell value.

```sh
ysh '.server.ports' config.yml
# [8080,8443]
```

Expressions may return more than one node. Each scalar or compact JSON collection is written on its own line:

```sh
ysh '.services[] | select(.enabled) | .name' config.yml
# api
# web
```

## JSON

Use `--json`, `-o=json`, or `--output-format=json`:

```sh
ysh -o=json '.service' config.yml
```

Recognized nulls, booleans, integers, and finite floats become native JSON values. Strings, timestamps, and application-tagged scalars are JSON strings. Non-finite YAML floats are quoted because JSON has no equivalent value.

## Type

```sh
ysh --type '.release.date' config.yml
# timestamp
```

Possible reports are:

| Node | Types |
| --- | --- |
| Collections | `mapping`, `sequence` |
| Scalars | `string`, `null`, `bool`, `int`, `float`, `timestamp`, `tagged` |

Type recognition never changes the default text returned for a scalar.

## Tag

```sh
ysh --tag '.widget' config.yml
# tag:example.com,2026:widget
```

Standard `!!` tags and handles declared with `%TAG` are expanded. Application constructors are not executed.

## Source line

```sh
ysh --line '.server.host' config.yml
# 3
```

For an alias selection, the reported line is the alias occurrence. Type, tag, and value output resolve through the alias target.

Computed expression values such as comparison results, `length`, `keys`, `kind`, and literals have source line zero because they do not occur in the YAML stream.

## AST

`--ast` prints the node table and its edges:

```sh
ysh --ast config.yml
```

The output includes node IDs, kinds, scalar values and types, tags, anchors, alias targets, source lines, mapping keys, indexes, and merge markers.

## Events

`--events` prints a parser-style view:

```sh
ysh --events config.yml
```

This is useful while extending the parser or reducing an unexpected input to a minimal test case.
