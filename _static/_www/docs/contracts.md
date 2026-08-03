# Configuration contracts

Validate a document, apply a standard patch, generate a reviewable change set, or cross a format boundary. The work stays in the same graph used by queries and YAML source edits.

## Validate before a script continues

```sh
ysh --schema service.schema.json '.' service.yml
```

A valid result continues to normal output. An invalid result exits non-zero with the first instance path and message:

```text
Error: schema validation failed at /service/port: number is above the maximum
```

Use expressions when a pipeline needs structured diagnostics:

```sh
ysh --json 'schema_errors(load("service.schema.json"))' service.yml
ysh -e 'schema_valid(load("service.schema.json"))' service.yml
```

Each error contains `instancePath`, `schemaPath`, `keyword`, and `message`. Values are never copied into diagnostics.

The JSON Schema 2020-12 profile covers boolean schemas; `type`, `const`, `enum`; local `$ref` and `$defs`; composition and `if`/`then`/`else`; object properties, property names, dependent schemas/keys, patterns, and additional properties; tuple/items/contains and array limits; string length and POSIX patterns; and numeric bounds and multiples. Remote and dynamic references fail closed; annotation-driven `unevaluated*` vocabularies are rejected.

## Apply JSON Patch

```sh
ysh --apply-patch deploy.patch.json --diff deploy.yml
ysh --apply-patch deploy.patch.json -i deploy.yml
```

All six RFC 6902 operations are supported: `add`, `remove`, `replace`, `move`, `copy`, and `test`. Paths use RFC 6901 JSON Pointer, including `~0`, `~1`, array indexes, and `-` append. The release gate runs 108 enabled assertions from the pinned JSON Patch community and RFC-example corpora.

On YAML input, patch mutations enter the normal source compiler. A strict edit can preserve comments and refuse regeneration:

```sh
ysh --preserve-only --apply-patch deploy.patch.json -i deploy.yml
```

Apply RFC 7396 Merge Patch when an object-shaped overlay is clearer:

```sh
ysh --merge-patch production.merge.json --diff deploy.yml
```

## Generate a patch

```sh
ysh --json --generate-patch desired.yml '.' current.yml > change.json
```

Generation is deterministic. Mapping changes become ordered remove, replace, and add operations; changed sequences and unlike node kinds use a replace operation. Applying the generated patch reproduces the target graph.

The same operations are available inside expressions:

```sh
ysh --json 'pointer("/services/0/name")' config.yml
ysh --json 'apply_patch([{op:"replace",path:"/replicas",value:3}])' deploy.yml
ysh --json 'merge_patch({debug:null,release:{channel:"stable"}})' config.yml
ysh --json 'diff_patch({name:"desired"})' current.yml
```

## Read and write other configuration formats

Input format is inferred from a filename or selected explicitly:

```sh
ysh '.database.port' config.toml
ysh -p ini -o yaml '.' app.conf
ysh -p xml -o json '.catalog.item' catalog.xml
ysh -o toml '.service' config.yml
```

| Format | Contract |
|---|---|
| TOML 1.0 | Tables, dotted keys, arrays, inline tables, array tables, strings, integers, floats, booleans, and date/time values. Decoder and encoder each pass all 205 official valid fixtures. |
| INI | Global scalar keys and nested dotted sections. Values remain strings; duplicate keys fail. |
| XML | One data root; attributes become `+@name`, text becomes `+content` beside children, and repeated elements become arrays. Names and XML 1.0 characters are checked; DTDs and custom entities are disabled. |

TOML's remaining 12 official invalid cases concern raw byte sequences portable AWK cannot reliably observe after record decoding: bare CR, NUL, invalid UTF-8, and UTF-16. The other 462 invalid fixtures fail closed.

Non-YAML formats are semantic codecs, not presentation-preserving editors. Mixed XML text/child ordering is not retained. Convert or query one document at a time; use YAML input for `-i`, repository transactions, source comments, and exact byte preservation.
