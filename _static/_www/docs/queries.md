# Queries

YAML.sh expressions select values, pass them through filters, build new results, and update documents. An expression may produce no result, one result, or a stream of results.

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

Missing keys and out-of-range indexes produce null:

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

Selected results retain their YAML type, tag, source location, aliases, and merge behavior.

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

Numeric comparisons normalize integers and finite floats. Equality compares scalar values; two mappings or sequences are not treated as equal merely because their contents match.

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
- `type` returns a YAML tag such as `!!map`, `!!seq`, `!!str`, or `!!int`.

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

The [operator reference](operators.md) lists every sequence, quantifier, and string helper with its accepted inputs.

```sh
ysh -n --json '[3, 1, 2, 1] | unique'
ysh -n --json '[[1, 2], [3, [4]]] | flatten'
ysh -n --json '["yaml", "sh"] | join(".")'
ysh -n --json '["zero", "one"] | array_to_map'
```

Additional helpers cover common selection and reshaping jobs:

```sh
ysh '.services | filter(.enabled) | first' config.yml
ysh '.metadata | pick(["name", "owner"])' config.yml
ysh '.metadata | omit(["internal"]) | sort_keys(.)' config.yml
ysh --json 'sort_keys(..)' config.yml
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

The portable regex subset does not include flags, named captures, or replacement backreferences.

## Variables, dynamic keys, and reducers

Bind a result with `as $name`. The expression after the pipe keeps the original current input and can refer to that value repeatedly:

```sh
ysh '.metadata as $meta | {owner: $meta.owner, region: $meta.region}' config.yml
ysh '.key as $key | .data[$key]' config.yml
```

Use `ref` when the variable is explicitly a writable path reference:

```sh
ysh '.service ref $service | $service.image = "app:stable" | $service.ready = true' deploy.yml
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

The `*` operator recursively merges two mappings; at non-mapping leaves, the right side wins. It remains numeric multiplication for two numbers. Merge modifiers cover the configuration cases where one policy is not enough:

| Operator | Merge policy |
| --- | --- |
| `*+` | Append arrays |
| `*d` | Merge arrays by index |
| `*?` | Update existing fields only |
| `*n` | Add new fields only |

Modifiers combine, as in `*?+` for existing fields with appended arrays.

## Encode, decode, evaluate, and load

String codecs cover embedded configuration and shell handoffs:

| Format | Decode | Encode |
| --- | --- | --- |
| YAML | `from_yaml`, `@yamld` | `to_yaml(INDENT)`, `@yaml` |
| JSON | `from_json`, `@jsond` | `to_json(INDENT)`, `@json` |
| TOML | `from_toml`, `@tomld` | `to_toml`, `@toml` |
| INI | `from_ini`, `@inid` | `to_ini`, `@ini` |
| XML data | `from_xml`, `@xmld` | `to_xml`, `@xml` |
| Properties | `from_props`, `@propsd` | `to_props`, `@props` |
| CSV | `from_csv`, `@csvd` | `to_csv`, `@csv` |
| TSV | `from_tsv`, `@tsvd` | `to_tsv`, `@tsv` |
| Base64 | `@base64d` | `@base64` |
| URI | `@urid` | `@uri` |
| Shell text | — | `@sh` |

```sh
ysh '.embedded | from_yaml | .image.tag' config.yml
ysh '.payload | from_json | .items | @csv' config.yml
ysh '.secret | @base64' config.yml
```

CSV and TSV decoding treats the first row as headers and parses scalar cells. Properties use dotted paths and decode values as strings. TOML, INI, and XML use the [data profiles](contracts.md) documented for each format.

`eval(EXPR)` runs a string through YAML.sh's expression parser. `load`, `load_str`, `load_base64`, and `load_props` read a named local file:

```sh
ysh -n 'load("defaults.yml") * load("production.yml")'
ysh '.query | eval(.)' request.yml
```

Loaded bytes share `--max-input-bytes`; dynamic expressions share the node and nesting ceilings. Use `--security-disable-file-ops` to reject every load. Treat dynamic expression strings as code even though YAML.sh has no system-execution operator.

`shuffle` uses a portable pseudo-random Fisher–Yates pass. Supply `--shuffle-seed N` when a build must reproduce the same order.

## Context and environment

`path`, `parent`, `root`, `key`, `line`, `column`, and `tag` expose graph context. `root` returns the complete graph from a descendant. `filename`, `fileIndex`, and `documentIndex` identify input provenance:

```sh
ysh '.. | select(. == "api") | path' config.yml
ysh '.services[0].name | [filename, line, column, tag]' config.yml
```

`env(NAME)` parses the variable as YAML. `strenv(NAME)` always creates a string. `envsubst` expands `$NAME` and `${NAME}`, including `-` and `:-` defaults; `nu`, `ne`, and `ff` options are accepted. Use `--security-disable-env-ops` when expressions must not read the environment.

```sh
IMAGE_TAG=stable ysh '.image.tag = strenv(IMAGE_TAG)' deploy.yml
LIMITS='{cpu: 2}' ysh '.limits = env(LIMITS)' deploy.yml
ysh '.message | envsubst(nu, ff)' config.yml
```

`to_number` converts numeric strings. `with(PATH; UPDATE)` applies an update in a selected context while returning the original input.

`error(MESSAGE)` aborts evaluation with the message. Combine it with short-circuiting boolean operators to make a precondition executable while `with` retains the document:

```sh
ysh -i 'with(.kind; select(. == "Deployment") or error("expected Deployment")) | .spec.replicas = 3' deploy.yml
```

If any input fails the guard, the command writes nothing.

## Files and documents

List files to evaluate the query independently over each one. `--all-documents` evaluates every document in one YAML stream. `eval-all`/`ea` evaluates once across all documents and files, enabling slurp and practical cross-file merge:

```sh
ysh '[filename, .name]' one.yml two.yml
ysh --all-documents '[documentIndex, .name]' stream.yml
ysh ea '[.]' one.yml two.yml
ysh ea 'select(fileIndex == 0) * select(fileIndex == 1)' defaults.yml production.yml
```

It can also use one file to update others. This query reads the version from the first file and writes it into the rest:

```sh
query='select(fileIndex == 0).version as $version | select(fileIndex > 0).release.version = $version'
ysh ea --check "$query" release.yml services/*.yml
ysh ea -i "$query" release.yml services/*.yml
```

Whole-stream reduction can fold several files into one result:

```sh
ysh ea '. as $document ireduce ({}; . * $document)' defaults.yml region.yml secrets.yml
```

`split_doc` marks each streamed match as its own YAML document. YAML.sh already separates multiple YAML results, so the operator is explicit and idempotent:

```sh
ysh -o=yaml '.services[] | split_doc' config.yml
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

`setpath` creates a path from string keys and non-negative indexes. `delpaths` removes several paths in one transform:

```sh
ysh -o=yaml 'setpath(["spec", "replicas"]; 4)' deploy.yml
ysh -o=yaml 'delpaths([["metadata", "annotations"], ["metadata", "managedFields"]])' deploy.yml
```

Use `--check` for a quiet answer or `--diff` to preview the exact change. Both write nothing and return `0` when no change is needed, `1` when files would change, and `2` for an invalid query or input. Use `-i` to write the same candidate.

```sh
ysh --check '.image.tag = "stable"' services/*.yml
ysh --diff '.image.tag = "stable"' services/*.yml
ysh -i '.image.tag = "stable"' services/*.yml
```

Common scalar, collection, comment, insert, delete, and reorder edits preserve unrelated source text. Add `--preserve-only` when regeneration should be an error:

```sh
ysh --preserve-only --diff '.items += ["release"]' config.yml
```

See [documents and file edits](documents.md) for the preservation matrix, multi-file behavior, and write guarantees.

## Merged and aliased nodes

Expressions follow aliases and mapping merge sources automatically. Explicit entries override merged entries; in a merge sequence, the first source containing a key wins.

Aliases are genuine shared graph references. Updating through an alias or an inherited merge value therefore updates the referenced source node too. Use construction to materialize an independent value when shared identity is not what you want.

`anchor` and `alias` return a selected node's graph name. `tag`, `anchor`, and `alias` also have writable property forms:

```sh
ysh -o=yaml '.defaults anchor = "base" | .copy alias = "base"' config.yml
ysh -o=yaml '.release tag = "!release"' config.yml
```

Anchor renames update aliases that already reference the same node. Removing a referenced anchor, creating a duplicate anchor, or constructing a recursive alias fails. `explode(.)` clones the value with aliases and merge keys materialized.

## Presentation

`style`, `head_comment`, `line_comment`, and `foot_comment` inspect YAML presentation metadata. Their property forms edit values and generated key references:

```sh
ysh '.image | line_comment' deploy.yml
ysh -i '.image line_comment = "promoted by release"' deploy.yml
ysh -i '.image head_comment = "managed by release"' deploy.yml
ysh -i '(.image | key) foot_comment = "keep this key"' deploy.yml
ysh -i '.image style = "double" | .labels style = "flow"' deploy.yml
ysh -o=yaml '.notes style = "literal"' deploy.yml
```

Scalar styles can be reset or set to plain, single, double, literal, or folded. Collections can be reset to block output or set to flow. Block comment edits participate in strict source preservation; comments inside changed flow spans may require semantic emission.

## Language boundary

The language does not currently include date/time operators, system execution, or regex flags and capture objects. Slices target sequences, and interpolation accepts scalar results. XML is supported as a data codec rather than as a family of query operators. See the [operator reference](operators.md) for the complete surface and [yq compatibility](yq-compatibility.md) when adapting an existing yq expression.
