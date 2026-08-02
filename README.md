# YAML.sh

> **yq energy. zero baggage.**

[![CI](https://github.com/azohra/yaml.sh/actions/workflows/ci.yml/badge.svg)](https://github.com/azohra/yaml.sh/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/azohra/yaml.sh)](https://github.com/azohra/yaml.sh/releases/latest)

[Website](https://yaml.azohra.com) · [Documentation](https://docs.yaml.azohra.com) · [Install script](https://get.yaml.azohra.com)

YAML.sh is a yq-like YAML query tool delivered as one portable shell script. It needs only `/bin/sh` and AWK—no package manager, language runtime, downloaded binary, or YAML library.

The parser builds a real YAML node graph before resolving aliases, merge keys, tags, types, and queries. YAML.sh intentionally implements a tested YAML subset rather than claiming complete YAML 1.2 compliance; see the [support contract](_static/_docs/supported_yml.md) for exact boundaries.

## Install

Download a pinned release:

```sh
curl -fsSL https://raw.githubusercontent.com/azohra/yaml.sh/v1.0.0/ysh -o ysh
chmod +x ysh
sudo mv ysh /usr/local/bin/ysh
```

Or use the installer:

```sh
curl -fsSL https://get.yaml.azohra.com | sh
```

## Quick start

```yaml
server:
  host: localhost
  ports: [8080, 8443]
services:
  - name: api
    enabled: true
```

```sh
ysh '.server.host' config.yml
# localhost

ysh '.server.ports[1]' config.yml
# 8443

ysh '.services[0]' config.yml
# {"name":"api","enabled":true}
```

Standard input works without a special flag:

```sh
printf '%s\n' 'answer: 42' | ysh '.answer'
# 42
```

## Queries

Queries begin with `.` and support mapping keys and zero-based sequence indexes:

```sh
ysh '.' config.yml
ysh '.server.host' config.yml
ysh '.services[0].name' config.yml
```

Use bracket notation when a key contains query punctuation:

```sh
ysh '.["key.with.dots"]' config.yml
ysh '.metadata["build[number]"]' config.yml
```

This query model does not flatten the document, so empty collections and keys containing `.`, `[` or `]` remain unambiguous.

## Output

Scalar queries print their decoded text value. Mapping and sequence queries emit JSON by default. `--json` or `-o=json` forces JSON scalar encoding and converts recognized core types where JSON can represent them.

```sh
ysh '.enabled' config.yml
ysh -o=json '.services' config.yml
ysh --type '.enabled' config.yml
ysh --tag '.custom' config.yml
ysh --line '.server.host' config.yml
```

Available type reports are `mapping`, `sequence`, `string`, `null`, `bool`, `int`, `float`, `timestamp`, and `tagged`.

## Multiple documents

Select a zero-based document with `--document` or `-d`:

```sh
ysh --document 1 '.project.name' stream.yml
```

## Inspect the parser

The node graph and parser-style event stream are public debugging surfaces:

```sh
ysh --ast config.yml
ysh --events config.yml
```

They expose mappings, sequences, scalar types, tags, anchors, alias targets, merge entries, source lines, and parent-child edges without exposing a lossy transpiled data format.

## Command reference

| Flag | Purpose |
| --- | --- |
| `QUERY [FILE]` | Run a yq-style query against a file or standard input. |
| `-o, --output FORMAT` | Select `value`, `raw`, or `json`. |
| `-r, --raw-output` | Print a scalar value without JSON quoting. |
| `--json` | Emit JSON. |
| `--type` | Print the selected node type. |
| `--tag` | Print the selected node tag. |
| `--line` | Print the selected node source line. |
| `--ast` | Print the parsed node graph. |
| `--events` | Print parser-style node events. |
| `-d, --document N` | Select a zero-based YAML document. |
| `-V, --version` | Print the installed version. |
| `-h, --help` | Print CLI help. |

## Version 1 migration

Version 1 intentionally removes the v0.x `-f`, `-T`, `-q`, `-Q`, `-s`, `-l`, `-i`, and chainable transpiled-data interface. Use one query directly against a file or standard input instead:

```sh
# v0.x
ysh -f config.yml -Q 'server.host'

# v1
ysh '.server.host' config.yml
```

## Development

```sh
make all
```

This rebuilds the single-file executable, runs ShellCheck, and executes the suite. CI covers macOS AWK, Ubuntu AWK, BusyBox AWK, and `/bin/sh` execution.

## License

[MIT](LICENSE)
