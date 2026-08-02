# Queries

Version 1 uses one deliberately small, yq-shaped path language. Queries select a node from the parsed document rather than filtering flattened text.

## Root

`.` selects the document root:

```sh
ysh '.' config.yml
```

Root mappings and sequences are emitted as JSON by default. A root scalar is printed as text.

## Mapping keys

Append a bare key after `.`:

```sh
ysh '.server' config.yml
ysh '.server.host' config.yml
ysh '.server.tls.enabled' config.yml
```

Bare keys continue until the next `.` or `[`. For keys containing query punctuation, use bracket notation.

## Sequence indexes

Indexes are zero-based:

```sh
ysh '.ports[0]' config.yml
ysh '.services[2].name' config.yml
```

An out-of-range index is an error rather than an empty result.

## Quoted keys

Bracket notation makes the key boundary explicit:

```sh
ysh '.["key.with.dots"]' config.yml
ysh '.metadata["build[number]"]' config.yml
ysh '.["a key with spaces"]' config.yml
```

This is possible because v1 retains mapping identity. The old flattened representation could not distinguish a literal dot in a key from a query separator.

## Merged and aliased nodes

Queries follow aliases and mapping merge sources automatically:

```yaml
defaults: &defaults
  retries: 3
production:
  <<: *defaults
  endpoint: api.example.com
```

```sh
ysh '.production.retries' config.yml
# 3
```

Explicit mapping entries override merged entries. In a merge sequence, the first source containing a key wins.

## Current query boundary

Version 1 focuses on deterministic node selection. It does not yet implement pipes, wildcards, recursive descent, predicates, arithmetic, assignment, or in-place editing.

Those are query-language features—not parser shortcuts—and can now be added without changing the YAML graph underneath.
