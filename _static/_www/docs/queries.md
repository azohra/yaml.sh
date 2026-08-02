# Queries

Version 1.2 evaluates a focused yq-style expression language over streams of writable node references. Paths select exact nodes; iteration and pipes let one input become many results; assignments change the graph those references belong to.

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

## Recursive and optional traversal

`..` walks the current node and all of its descendants. Add `?` to a path or iterator when a missing value or incompatible type should produce no result instead of null or an error:

```sh
ysh '.. | select(has("name")) | .name' config.yml
ysh '.metadata.owner[]?' config.yml
ysh '.possibly_missing?' config.yml
```

Recursive descent follows resolved aliases and merge keys once per node, so shared graph nodes are not repeated forever.

## Select

`select(EXPRESSION)` keeps the current node when its predicate is truthy:

```sh
ysh '.services[] | select(.enabled) | .name' config.yml
ysh '.services[] | select(.port >= 8000) | .name' config.yml
```

Null and false are falsey. Every other scalar and collection is truthy.

## Comparisons, booleans, and arithmetic

The expression language supports:

- Equality: `==` and `!=`.
- Ordering: `>`, `>=`, `<`, and `<=` for two numbers or two strings.
- Boolean composition: `and`, `or`, and the `not` filter.

```sh
ysh '.services[] | select(.enabled and .tier == "backend") | .name' config.yml
ysh '.services[] | .enabled | not' config.yml
```

Numeric comparisons normalize integers and finite floats. Like yq, equality comparisons operate on scalar values rather than treating whole collections as identical values.

Arithmetic uses normal precedence with `+`, `-`, `*`, `/`, and `%`. `+` also concatenates strings and sequences, shallow-merges mappings, and treats null as an identity value.

```sh
ysh '.replicas + 1' config.yml
ysh -n --json '2 + 3 * 4'
ysh -n --json '[1, 2] + [3]'
```

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

## Construct values

Array and object literals can collect results from the current input. Unquoted identifier keys are accepted as a friendly extension; quoted keys work too.

```sh
ysh --json '[.services[].name]' config.yml
ysh --json '{owner: .metadata.owner, count: (.services | length)}' config.yml
ysh -n -o=yaml '{name: "api", enabled: true}'
```

`-n` supplies one null input without reading standard input, which makes it useful for creating a new document.

## Assign and delete

`=` evaluates its right side against the original input. `|=` evaluates it relative to each selected node. Missing mapping paths are created as needed.

```sh
ysh -o=yaml '.release.channel = "stable"' config.yml
ysh -o=yaml '.services[].enabled |= not' config.yml
ysh -o=yaml '.services[0].port += 20' config.yml
ysh -o=yaml 'del(.metadata.internal)' config.yml
```

The compound forms `+=`, `-=`, `*=`, `/=`, and `%=` are relative arithmetic updates. Parenthesized streamed selections can update several nodes:

```sh
ysh -o=yaml '(.services[] | select(.enabled) | .tier) = "active"' config.yml
```

Use `-i` to replace a real single-document input file after a successful transform. In-place mode always emits YAML, cannot be combined with standard input or `-n`, and rejects multi-document streams in v1.2.

## Merged and aliased nodes

Expressions follow aliases and mapping merge sources automatically. Explicit entries override merged entries; in a merge sequence, the first source containing a key wins.

Aliases are genuine shared graph references. Updating through an alias or an inherited merge value therefore updates the referenced source node too. Use construction to materialize an independent value when shared identity is not what you want.

## Current expression boundary

This is a useful yq-shaped language, not the complete yq language. Version 1.2 does not implement variables, string interpolation, regular expressions, dynamic object keys, slices, reduce/ireduce, sort/group/unique operators, file operators, date operators, XML/CSV/TOML codecs, style/comment operators, or yq's full deep-merge and cross-document semantics.

Supported transformations are tested against their expected graph behavior. For automation that needs arbitrary yq programs, use yq; YAML.sh is for the delightfully constrained machine where installing yq is the problem you are trying to solve.
