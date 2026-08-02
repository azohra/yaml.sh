# Queries

Version 1.8 evaluates a focused yq-style language over streams of writable node references. Paths select nodes; pipes and comma expressions shape streams; assignments change the graph.

## Paths

`.` selects the document root. Mapping keys and zero-based sequence indexes compose naturally:

```sh
ysh '.' config.yml
ysh '.server.host' config.yml
ysh '.services[2].name' config.yml
ysh '.services[-1].name' config.yml
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

Sequence helpers include `sort`, `sort_by`, `group_by`, `unique`, `unique_by`, `reverse`, `flatten`, `min`/`max`, `min_by`/`max_by`, and `add`. Quantifiers include `any`, `all`, `any_c`, and `all_c`. String helpers include `upcase`, `downcase`, `contains`, `startswith`, `endswith`, `split`, and `join`.

```sh
ysh -n --json '[3, 1, 2, 1] | unique'
ysh -n --json '[[1, 2], [3, [4]]] | flatten'
ysh -n --json '["yaml", "sh"] | join(".")'
```

Focused helpers cover common selection and reshaping jobs:

```sh
ysh '.services | filter(.enabled) | first' config.yml
ysh '.metadata | pick(["name", "owner"])' config.yml
ysh '.metadata | omit(["internal"]) | sort_keys(.)' config.yml
ysh -n --json '[["a", "b"], ["x"]] | pivot'
```

## Slices, interpolation, and regular expressions

Sequence slices use zero-based, end-exclusive bounds. Either bound may be omitted or negative:

```sh
ysh '.services[1:3]' config.yml
ysh '.services[:-1]' config.yml
```

Double-quoted expressions interpolate the first scalar result from `\(EXPRESSION)`. `test` and global `sub` use the POSIX extended regular expressions supplied by the platform AWK:

```sh
ysh '"\(.metadata.owner):\(.services | length)"' config.yml
ysh '.services[] | select(.name | test("^[a-z]+$"))' config.yml
ysh '.name | sub("-"; "_")' config.yml
```

This portable regex subset does not promise yq/RE2 flags, named captures, or replacement backreferences.

## Variables, dynamic keys, and reducers

Bind a result with `as $name`. The expression after the pipe keeps the original current input and can refer to that value repeatedly:

```sh
ysh '.metadata as $meta | {owner: $meta.owner, region: $meta.region}' config.yml
ysh '.key as $key | .data[$key]' config.yml
```

Dynamic brackets accept a computed string key or integer index. Parenthesized object keys are computed from the current input:

```sh
ysh '.services[] as $service ireduce ({}; . * {($service.name): $service.port})' config.yml
```

Both reducer forms fold a stream into one value:

```sh
ysh 'reduce .services[].port as $port (0; . + $port)' config.yml
ysh -n '[1, 2, 3][] as $item ireduce (0; . + $item)'
```

The `*` operator recursively merges two mappings; at non-mapping leaves, the right side wins. It remains numeric multiplication for two numbers.

## Context and environment

`path`, `parent`, `key`, `line`, and `tag` expose graph context. `filename`, `fileIndex`, and `documentIndex` identify input provenance:

```sh
ysh '.. | select(. == "api") | path' config.yml
ysh '.services[0].name | [filename, line, tag]' config.yml
```

`env(NAME)` parses the variable as YAML. `strenv(NAME)` always creates a string. `envsubst` expands `$NAME` and `${NAME}`, including `-` and `:-` defaults; `nu`, `ne`, and `ff` options are accepted. Use `--security-disable-env-ops` when expressions must not read the environment.

```sh
IMAGE_TAG=stable ysh '.image.tag = strenv(IMAGE_TAG)' deploy.yml
LIMITS='{cpu: 2}' ysh '.limits = env(LIMITS)' deploy.yml
ysh '.message | envsubst(nu, ff)' config.yml
```

`to_number` converts numeric strings. `with(PATH; UPDATE)` applies an update in a selected context while returning the original input.

## Files and documents

List files to evaluate the query independently over each one. `--all-documents` evaluates every document in one YAML stream. `eval-all`/`ea` evaluates once across all documents and files, enabling slurp and practical cross-file merge:

```sh
ysh '[filename, .name]' one.yml two.yml
ysh --all-documents '[documentIndex, .name]' stream.yml
ysh ea '[.]' one.yml two.yml
ysh ea 'select(fileIndex == 0) * select(fileIndex == 1)' defaults.yml production.yml
```

`eval-all` is intentionally focused; it is not a complete clone of yq's general stream algebra.

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

`setpath` creates a path from string keys and non-negative indexes. `delpaths` removes several paths in one transform:

```sh
ysh -o=yaml 'setpath(["spec", "replicas"]; 4)' deploy.yml
ysh -o=yaml 'delpaths([["metadata", "annotations"], ["metadata", "managedFields"]])' deploy.yml
```

Use `-i` to atomically replace a real, non-symlink input file after every document transforms successfully. Safe scalar edits, direct inserts/deletes, and pure sequence reorders preserve presentation; other structural edits use stable semantic YAML.

## Merged and aliased nodes

Expressions follow aliases and mapping merge sources automatically. Explicit entries override merged entries; in a merge sequence, the first source containing a key wins.

Aliases are genuine shared graph references. Updating through an alias or an inherited merge value therefore updates the referenced source node too. Use construction to materialize an independent value when shared identity is not what you want.

`anchor` and `alias` return a selected node's graph name. `explode(.)` clones the value with aliases and merge keys materialized.

## Presentation

`style` and `line_comment` inspect YAML presentation metadata. Their yq-shaped property forms edit it:

```sh
ysh '.image | line_comment' deploy.yml
ysh -i '.image line_comment = "promoted by release"' deploy.yml
ysh -i '.image style = "double" | .labels style = "flow"' deploy.yml
```

Style editing supports plain, single-quoted, and double-quoted scalars plus flow collections. Literal/folded conversion and head/foot comment operators are not implemented.

## Current expression boundary

This is a useful yq-shaped language, not the complete yq language. Version 1.8 does not implement date or load operators, non-YAML codecs, regex flags/captures, or yq's complete flag surface. Slices target sequences; interpolation is intentionally scalar-oriented. See the [yq compatibility map](yq-compatibility.md).

Supported transformations are tested against their expected graph behavior. For automation that needs arbitrary yq programs, use yq; YAML.sh is for the delightfully constrained machine where installing yq is the problem you are trying to solve.
