# Migrate from v0.x

Version 1 intentionally breaks the old CLI. The public transpiled representation and chainable query operations were the architectural constraint preventing YAML.sh from preserving real YAML structure.

## File queries

```sh
# v0.x
ysh -f config.yml -Q 'server.host'

# v1
ysh '.server.host' config.yml
```

## Standard input

```sh
# v0.x and v1 both accept standard input,
# but v1 uses the query as the positional argument.
generate-config | ysh '.server.host'
```

## Collections

```sh
# v0.x
ysh -f config.yml -l 'services'

# v1
ysh '.services' config.yml
```

Version 1 emits a selected collection as compact JSON. Use `-o=json` to make scalar JSON encoding explicit as well.

## Source lines and types

```sh
# v0.x
ysh -f config.yml --line 'server.host'

# v1
ysh --line '.server.host' config.yml
```

```sh
ysh --type '.server.port' config.yml
```

## Multiple documents

The chainable `--next` operation is replaced with direct indexing:

```sh
# v0.x
data=$(ysh -f stream.yml)
ysh -T "$data" --next -Q 'name'

# v1
ysh --document 1 '.name' stream.yml
```

## Removed interface

The following v0.x flags are not accepted in v1:

- `-f`, because the input file is positional.
- `-T`, because the transpiled representation is gone.
- `-q` and `-Q`, because the positional query replaces them.
- `-s`, `-l`, `-L`, `-c`, and `-I`, because node selection uses one query grammar.
- The v0.x meaning of `-i`. Modern YAML.sh reuses `-i` for yq-style in-place file updates; v1.3 preserves presentation for scalar-only changes.
- `--next`, because `--document N` addresses a document directly.

If a script depends on v0.x behavior, pin `v0.4.0` while migrating.
