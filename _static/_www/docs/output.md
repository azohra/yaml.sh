# Output & metadata

The same query can return a value, JSON, YAML, a node type, its expanded tag, or its source line.

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

For edits, evaluation finishes before YAML.sh compiles a source plan. The plan must contain non-overlapping owned spans; only then is a candidate emitted.

| Edit | Source behavior |
| --- | --- |
| Scalar replacement | Keeps surrounding spacing, quote style, properties, and line comment |
| Flow mapping or sequence | Rewrites the changed collection span; keeps bytes and closing comments outside it |
| Literal/folded scalar | Keeps block style, indentation, and header comment while replacing content |
| Head or foot comment | Inserts, replaces, or removes the owned full-line block comment span |
| Block insert, append, delete, or reorder | Moves or removes the complete record span with its attached comments |
| Alias or merged value | Updates the owned anchor source; alias and merge occurrences stay intact |

Stable flow formatting may normalize whitespace and key quoting inside a changed flow span. Multiline flow spans with internal comments are refused in strict mode because compacting them would discard comment ownership. A structural change without a safe source plan uses the semantic emitter, or fails before candidate output under `--preserve-only`.

With several inputs, source snapshots are evaluated and every changed candidate is built before the first replacement. Live files must still match those snapshots before reporting or commit, and each changed target is checked again immediately before replacement. No-op files are not replaced. The snapshots allow rollback if a later commit fails or the process is interrupted. Permission bits survive; symlinks, duplicate paths, and newline-containing names are refused.

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

For `eval-all`, `parsed_nodes`, results, and mutations belong to each input; `generated_nodes` is transaction-wide because the query is evaluated once across the combined stream.

Use `--explain=json` for JSON Lines, with one value-free audit record per input:

```sh
ysh --explain=json -i '.image.tag = "stable"' services/*.yml 2>changes.jsonl
```

Transaction reports are released only after every file commits. An aborted or rolled-back transaction emits an error and no audit records.

Add `--check` to run the same transformation without writing. JSON explain mode remains pure JSON Lines; exit status reports clean `0`, drift `1`, or error `2`.

Use `--diff` to put the prepared unified diff on stdout while keeping the value-free explanation on stderr:

```sh
ysh --diff --explain=json '.image.tag = "stable"' services/*.yml 2>changes.jsonl
```

Unlike the explain record, a diff necessarily contains changed values.
