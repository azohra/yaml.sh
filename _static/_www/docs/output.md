# Output formats & inspection

The same query can return a value, JSON, YAML, TOML, INI, XML, a node type, its expanded tag, or its source line.

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

## YAML

Use `-y`, `-o=yaml`, or `--output-format=yaml` to serialize selected or transformed nodes:

```sh
ysh -o=yaml '.release.channel = "stable"' config.yml
```

Multiple results are separated with `---`, producing a valid YAML stream. Anchors, aliases, tags, and merge edges are emitted when they still exist in the selected graph.

Set YAML indentation from one through nine spaces with `-I N` or `--indent=N`. Use `--unwrap-scalar=false` when default value output should retain a scalar's YAML quoting, tag, and line comment.

The emitter is semantic. It uses a stable layout while retaining recorded head, line, and foot comments plus supported scalar/collection styles. Blank lines, spacing, directive spelling, and exact scalar formatting are not reconstructed unless a source edit owns that presentation.

In-place edits use the original source when a change has a safe, non-overlapping edit plan. See [documents and file edits](documents.md) for the preservation matrix, strict mode, and multi-file write behavior.

## TOML, INI, and XML

Use `-o toml`, `-o ini`, or `-o xml` for semantic conversion:

```sh
ysh -o toml '.service' config.yml
ysh -p toml -o yaml '.' config.toml
ysh -p xml -o json '.' catalog.xml
```

TOML and INI require a mapping root. XML requires one root-element mapping and uses the documented `+@attribute` / `+content` shape. These emitters do not reconstruct comments or original layout. See [validate, patch, and convert](contracts.md) for exact boundaries.

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

## Explain an edit

`--explain` leaves normal output on stdout and reports evaluation behavior on stderr:

```sh
ysh --explain -i '.image.tag = "stable"' deploy.yml
```

The report includes parsed/generated node counts, result and mutation counts, mutation paths, whether presentation was preserved or regenerated, the compiled `source_edits` count, and the final plan's `changed` boolean. Values are intentionally omitted. A mutate-then-revert expression may record operations while `changed` remains false.

For `eval-all`, `parsed_nodes`, results, and mutations belong to each input; `generated_nodes` covers the complete batch because the query is evaluated once across the combined stream.

Use `--explain=json` for JSON Lines, with one value-free audit record per input:

```sh
ysh --explain=json -i '.image.tag = "stable"' services/*.yml 2>changes.jsonl
```

Reports are emitted only after every file is written. An aborted or rolled-back batch emits an error and no audit records.

Add `--check` to run the same transformation without writing. JSON explain mode remains pure JSON Lines; exit status reports no change `0`, changes needed `1`, or error `2`.

Use `--diff` to put the prepared unified diff on stdout while keeping the value-free explanation on stderr:

```sh
ysh --diff --explain=json '.image.tag = "stable"' services/*.yml 2>changes.jsonl
```

Unlike the explain record, a diff necessarily contains changed values.
