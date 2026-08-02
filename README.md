# YAML.sh

[![CI](https://github.com/azohra/yaml.sh/actions/workflows/ci.yml/badge.svg)](https://github.com/azohra/yaml.sh/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/azohra/yaml.sh)](https://github.com/azohra/yaml.sh/releases/latest)

YAML.sh reads a practical subset of YAML using only Bash, AWK, and standard Unix tools. It is useful in small bootstrap scripts where installing a full YAML implementation is not an option.

> YAML.sh is intentionally not a complete YAML 1.2 implementation. For untrusted input or advanced YAML features such as anchors, aliases, tags, directives, and explicit complex keys, use a maintained full parser.

## Install

Download a pinned release:

```bash
curl -fsSL https://raw.githubusercontent.com/azohra/yaml.sh/v0.3.0/ysh -o ysh
chmod +x ysh
sudo mv ysh /usr/local/bin/ysh
```

## Quick start

```yaml
---
block_no: 0
level_one:
  level_two:
    key: value
    simple_list: [first, second, third]
    object_list:
      - name: one
        value: 1
      - {name: two, value: 2}
message: |-
  Values can span
  multiple lines.
```

```bash
ysh -f input.yaml -Q 'level_one.level_two.key'
# value

ysh -f input.yaml -Q 'level_one.level_two.simple_list[1]'
# second

ysh -f input.yaml -Q 'level_one.level_two.object_list[1].name'
# two
```

YAML can also be piped in:

```bash
printf '%s\n' 'name: yaml.sh' | ysh -Q name
```

## Reuse transpiled data

Parsing produces a line-oriented intermediate representation. Store it once when several queries need the same input, and always quote the variable when passing it back with `-T`:

```bash
data=$(ysh -f input.yaml)
ysh -T "${data}" -Q block_no
ysh -T "${data}" -Q 'level_one.level_two.key'
```

Unquoted `-T ${data}` is not safe: the shell splits the intermediate representation into separate arguments before YAML.sh can read it.

## Query source lines

`--line` returns the original line containing a key or value. This is available for file and standard-input YAML, but not for already-transpiled data because source positions are not present there.

```bash
ysh -f input.yaml --line 'level_one.level_two.key'
# 5
```

## Multiple documents

Use `--next` to move through documents separated by `---`:

```bash
data=$(ysh -f input.yaml)
while [ -n "${data}" ]; do
  ysh -T "${data}" -Q block_no
  data=$(ysh -T "${data}" --next)
done
```

## Command reference

| Flag | Purpose |
| --- | --- |
| `-f, --file FILE` | Parse a YAML file. |
| `-T, --transpiled DATA` | Read one quoted intermediate-data argument. |
| `-q, --query PATH` | Return an encoded value or chainable child structure. |
| `-Q, --query-val PATH` | Return a decoded scalar value. |
| `-s, --sub PATH` | Return a child structure. |
| `-l, --list PATH` | Return a list structure. |
| `-L, --list-val PATH` | Return the decoded scalar values in a list. |
| `-c, --count PATH` | Count list elements. |
| `-i, --index N` | Select a list item from a chained query. |
| `-I, --index-val N` | Return a decoded scalar list item. |
| `-p, --line PATH` | Return source line number(s). |
| `-t, --tops` | Return the top-level keys of the current structure. |
| `-n, --next` | Move to the next YAML document. |
| `-v, --version` | Print the installed version. |
| `-h, --help` | Print CLI help. |

See the [supported YAML reference](_static/_docs/supported_yml.md) for syntax details.

## Library use

```bash
YSH_LIB=1
source /usr/local/bin/ysh

document=$(YSH_parse input.yaml)
YSH_safe_query "${document}" 'level_one.level_two.key'
```

## Development

```bash
make all
```

This rebuilds the standalone `ysh` executable, runs ShellCheck, and executes the test suite. CI covers current Ubuntu and macOS runners.

## License

[MIT](LICENSE)
