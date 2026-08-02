# Queries

Version 1.1 evaluates a focused, read-only yq-style expression language over streams of node references. Paths still select exact nodes; iteration and pipes let one input become many results without flattening the YAML graph.

## Paths

`.` selects the document root. Mapping keys and zero-based sequence indexes compose naturally:

```sh
ysh '.' config.yml
ysh '.server.host' config.yml
ysh '.services[2].name' config.yml
ysh '.["key.with.dots"]' config.yml
```

Quoted bracket keys are required when query punctuation belongs to the key.

Missing keys and out-of-range indexes produce null, matching yq traversal semantics:

```sh
ysh --json '.missing' config.yml
# null
```

## Iterate

Empty brackets stream every sequence item or mapping value:

```sh
ysh '.services[].name' config.yml
ysh '.metadata[]' config.yml
```

Each result retains its node identity, type, tag, source line, parent, aliases, and resolved merge behavior.

## Pipe

The pipe passes every result on its left into the expression on its right:

```sh
ysh '.services[] | .name' config.yml
```

Streams print one scalar or compact JSON collection per line.

## Select

`select(EXPRESSION)` keeps the current node when its predicate is truthy:

```sh
ysh '.services[] | select(.enabled) | .name' config.yml
ysh '.services[] | select(.port >= 8000) | .name' config.yml
```

Null and false are falsey. Every other scalar and collection is truthy.

## Comparisons and booleans

Version 1.1 supports:

- Equality: `==` and `!=`.
- Ordering: `>`, `>=`, `<`, and `<=` for two numbers or two strings.
- Boolean composition: `and`, `or`, and the `not` filter.

```sh
ysh '.services[] | select(.enabled and .tier == "backend") | .name' config.yml
ysh '.services[] | .enabled | not' config.yml
```

Numeric comparisons normalize integers and finite floats. Like yq, equality comparisons operate on scalar values rather than treating whole collections as identical values.

## Defaults

The alternative operator `//` returns its right side when the left side is absent, null, or false:

```sh
ysh '.release.channel // "stable"' config.yml
```

## Collection helpers

```sh
ysh '.services | length' config.yml
ysh '.metadata | keys' config.yml
ysh '.metadata | has("owner")' config.yml
ysh '.services | has(2)' config.yml
```

- `length` counts mapping entries, sequence items, or scalar characters; null has length zero.
- `keys` returns mapping keys or sequence indexes.
- `has(KEY)` checks a mapping key or sequence index.
- `kind` returns `map`, `seq`, or `scalar`.
- `type` returns a yq-style tag such as `!!map`, `!!seq`, `!!str`, or `!!int`.

Filters can begin an expression when they operate on the root:

```sh
ysh 'length' config.yml
```

## Merged and aliased nodes

Expressions follow aliases and mapping merge sources automatically. Explicit entries override merged entries; in a merge sequence, the first source containing a key wins.

## Current expression boundary

Version 1.1 is deliberately read-only. It does not yet implement recursive descent, optional traversal, arithmetic, string interpolation, variables, construction, assignment, deletion, YAML serialization, or in-place editing.

Those features require a writable reference evaluator and a YAML emitter. They can now be added above the same node-stream architecture without replacing the parser.
