# Operator reference

This page is the compact index to YAML.sh's expression language. The [query guide](queries.md) explains each family with examples.

## Select and combine

| Job | Forms |
|---|---|
| Paths | `.`, `.name`, `.["name"]`, `.[INDEX]`, slices, dynamic keys |
| Traversal | `.[]`, optional `?`, recursive `..` |
| Streams | pipe `\|`, comma union, array collection `[EXPRESSION]` |
| Filter | `select`, `filter`, `first` |
| Defaults | `LEFT // RIGHT` |
| Logic | `and`, `or`, `not`, `any`, `all`, `any_c`, `all_c` |
| Compare scalars | `==`, `!=`, `>`, `>=`, `<`, `<=` |
| Variables | `as $name`, `ref $name`, `reduce`, `ireduce` |
| Context | `path`, `parent`, `root`, `key`, `line`, `column`, `tag` |
| Input context | `filename`, `fileIndex`, `documentIndex` |

Equality compares scalar values. Mappings and sequences are not structurally equal merely because they contain the same values.

## Build and update

| Job | Forms |
|---|---|
| Construct | arrays, objects, computed object keys |
| Assign | `=`, `\|=`, `+=`, `-=`, `*=`, `/=`, `%=` |
| Delete | `del`, `delpaths` |
| Paths | `setpath` |
| Scoped update | `with(PATH; UPDATE)` |
| Arithmetic | `+`, `-`, `*`, `/`, `%` |
| Merge mappings | `*`, plus `*+`, `*d`, `*?`, and `*n` policies |
| YAML properties | read or write `tag`, `anchor`, `alias`, `style`, `head_comment`, `line_comment`, `foot_comment` |
| Alias materialization | `explode` |

Updating through an alias or inherited merge value follows the shared YAML node. Anchor renames keep referring aliases valid. Invalid or recursive alias construction is rejected.

## Collections

| Family | Forms |
|---|---|
| Size and keys | `length`, `keys`, `has`, `kind`, `type` |
| Transform | `map`, `map_values`, `to_entries`, `from_entries`, `with_entries` |
| Order | `sort`, `sort_by`, `sort_keys`, `reverse`, `shuffle` |
| Group and deduplicate | `group_by`, `unique`, `unique_by` |
| Select values | `min`, `min_by`, `max`, `max_by`, `pick`, `omit` |
| Reshape | `flatten`, `pivot`, `array_to_map`, `add` |
| Documents | `split_doc` |

`--shuffle-seed N` makes `shuffle` reproducible. Sorting and grouping use scalar keys. `flatten` is recursive.

## Strings and regular expressions

| Job | Forms |
|---|---|
| Case and whitespace | `upcase`, `downcase`, `trim` |
| Convert | `to_string`, `to_number` |
| Split and join | `split`, `join` |
| Match text | `contains`, `startswith`, `endswith`, `test`, `sub` |
| Compose | `"value: \(EXPRESSION)"` interpolation |

`test` and global `sub` use the host AWK's POSIX extended regular expressions. Regex flags, capture objects, and replacement backreferences are not supported. Interpolation accepts the first scalar result.

## Environment, files, and dynamic expressions

| Job | Forms |
|---|---|
| Environment | `env`, `strenv`, `envsubst` |
| Local files | `load`, `load_str`, `load_base64`, `load_props` |
| Dynamic expression | `eval(EXPR)` |
| Stop with an error | `error(MESSAGE)` |

Environment access, query-selected file reads, and dynamic evaluation can be disabled independently. See [security and limits](security.md).

## Encode and decode

| Format | Decode | Encode |
|---|---|---|
| YAML | `from_yaml`, `@yamld` | `to_yaml`, `@yaml` |
| JSON | `from_json`, `@jsond` | `to_json`, `@json` |
| TOML | `from_toml`, `@tomld` | `to_toml`, `@toml` |
| INI | `from_ini`, `@inid` | `to_ini`, `@ini` |
| XML data | `from_xml`, `@xmld` | `to_xml`, `@xml` |
| Properties | `from_props`, `@propsd` | `to_props`, `@props` |
| CSV | `from_csv`, `@csvd` | `to_csv`, `@csv` |
| TSV | `from_tsv`, `@tsvd` | `to_tsv`, `@tsv` |
| Base64 | `@base64d` | `@base64` |
| URI | `@urid` | `@uri` |
| Shell text | — | `@sh` |

TOML, INI, and XML use documented data profiles rather than reproducing every application-specific extension. See [validate, patch, and convert](contracts.md).

## Configuration operations

Expressions also provide RFC 6901 `pointer`, RFC 6902 `apply_patch` and `diff_patch`, RFC 7396 `merge_patch`, and the documented JSON Schema operators `schema_valid` and `schema_errors`.

## Current boundary

Date/time operators, system execution, regex capture objects and flags, and application-specific YAML tag construction are not implemented. XML is available as a secure data codec; it is not an XPath or XML application runtime. See [yq compatibility](yq-compatibility.md) only when translating an existing yq program.
