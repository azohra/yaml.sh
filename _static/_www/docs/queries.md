# Queries

Version 2 evaluates a focused yq-style programming language over streams of writable node references. Paths select exact nodes; pipes and comma expressions shape streams; assignments change the graph those references belong to.

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

## Collection programming

Comma expressions emit both sides. `map` always produces a sequence; `map_values` preserves a mapping or sequence while transforming its values.

```sh
ysh '.metadata.owner, .metadata.region' config.yml
ysh --json '.services | map(.name)' config.yml
ysh --json '.metadata | map_values(upcase)' config.yml
```

Mappings and sequences can move through the familiar entry representation:

```sh
ysh --json '.metadata | to_entries' config.yml
ysh --json '.metadata | with_entries(.value |= upcase)' config.yml
ysh --json '.metadata | to_entries | from_entries' config.yml
```

Sequence helpers include `sort`, stable first-occurrence `unique`, `reverse`, and recursive `flatten`. String helpers include `upcase`, `downcase`, `contains(...)`, `startswith(...)`, `endswith(...)`, `split(...)`, and `join(...)`.

```sh
ysh -n --json '[3, 1, 2, 1] | unique'
ysh -n --json '[[1, 2], [3, [4]]] | flatten'
ysh -n --json '["yaml", "sh"] | join(".")'
```

## Variables, dynamic indexes, and reduce

Bind a result with `as $name`. The expression after the pipe keeps the original current input and can refer to that value repeatedly:

```sh
ysh '.metadata as $meta | {owner: $meta.owner, region: $meta.region}' config.yml
ysh '.key as $key | .data[$key]' config.yml
```

Dynamic brackets accept a computed string key or integer index. `reduce` folds a stream into one value:

```sh
ysh 'reduce .services[].port as $port (0; . + $port)' config.yml
```

The `*` operator recursively merges two mappings; at non-mapping leaves, the right side wins. It remains numeric multiplication for two numbers.

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

Use `-i` to replace a real input file after every document transforms successfully. It cannot be combined with standard input or `-n`. Scalar-only edits preserve the original presentation; structural edits use stable semantic YAML. Multi-document files are evaluated document by document.

## Merged and aliased nodes

Expressions follow aliases and mapping merge sources automatically. Explicit entries override merged entries; in a merge sequence, the first source containing a key wins.

Aliases are genuine shared graph references. Updating through an alias or an inherited merge value therefore updates the referenced source node too. Use construction to materialize an independent value when shared identity is not what you want.

## Current expression boundary

This is a useful yq-shaped language, not the complete yq language. Version 2 does not implement string interpolation, regular expressions, slices, grouping, ireduce, date operators, file-loading operators, XML/CSV/TOML codecs, comment/style mutation operators, or yq's complete cross-document and flag surface.

Supported transformations are tested against their expected graph behavior. For automation that needs arbitrary yq programs, use yq; YAML.sh is for the delightfully constrained machine where installing yq is the problem you are trying to solve.
