# Parser internals

Version 1.6 is still one shell script, with a semantic graph and source-presentation layer working together.

```text
/bin/sh CLI
    ↓
AWK scanner + indentation parser
    ↓
YAML node graph
    ↓
alias + merge resolver
    ↓
expression parser
    ↓
node-stream evaluator
    ↓
presentation patcher or value / JSON / YAML / metadata / AST / events
```

## The shell layer

The `/bin/sh` launcher handles arguments, input, output mode, and atomic in-place replacement. It feeds the embedded program to AWK through a here-document, avoiding small `ARG_MAX` limits in minimal systems. Query text travels through the POSIX environment so AWK never rewrites backslashes before lexing interpolation or regex syntax.

The development sources remain separate:

```text
src/ysh.sh   portable CLI launcher
src/ysh.awk  parser, graph, resolver, queries, emitters
```

The build combines them into the released `ysh` file.

## The node graph

AWK arrays store node properties by numeric ID:

```text
node_kind[12]  = mapping
node_kind[13]  = scalar
node_value[13] = true
node_type[13]  = bool
node_line[13]  = 8
```

Mapping and sequence edges are separate arrays. Alias nodes point to an anchored target instead of copying paths. Tags, source lines, and scalar types remain attached to nodes.

This representation makes empty collections possible and removes ambiguity between a literal key named `a.b` and the query `.a.b`.

## Merge resolution

Merge entries remain marked edges in the graph. Lookup checks explicit entries first, then merge sources in declaration order. A collection pass produces the effective mapping keys for JSON output while preserving the same precedence.

## Expression streams

The expression parser builds an operator tree with explicit precedence for streams, lexical binding, pipes, assignment, alternatives, booleans, comparisons, arithmetic, and traversal. Evaluation passes numbered streams of node references between operators. Variables hold node identity; dynamic indexes evaluate computed keys; reducers repeatedly bind an item while feeding an accumulator through the update expression.

Because streams contain node IDs rather than copied values, type, tag, source line, alias identity, parentage, and merge behavior survive a pipeline. Assignments replace the selected graph nodes; missing mapping paths use attachable placeholders. Computed booleans, strings, numbers, constructed collections, and key lists are represented as temporary graph nodes and use the same output path as parsed YAML.

The semantic emitter walks the graph and produces stable block YAML. Separately, the v1.6 presentation tracker patches common replacements, block inserts/deletes, and sequence reorders into original source spans while retaining properties and attached comments. Other mutations use the semantic emitter.

## Diagnostics

Use the two structural outputs while developing:

```sh
ysh --ast input.yml
ysh --events input.yml
```

`--ast` is the storage view. `--events` is the parser-style structural view. Neither is a public serialization format intended for feeding back into YAML.sh.

## Why AWK

AWK provides portable text processing, associative arrays, recursion, and a small enough runtime model to ship the complete implementation as readable source. The constraint is the point: YAML.sh is a serious parser built in an intentionally mischievous medium.
