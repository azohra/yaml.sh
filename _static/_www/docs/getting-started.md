# Install & quick start

YAML.sh ships as one executable text file containing its shell launcher and AWK engine.

## Install

With Homebrew:

```sh
brew install azohra/tools/ysh
```

Or download the release directly. The installer verifies its pinned SHA-256 digest before writing the file:

```sh
curl -fsSL https://yaml.azohra.com/install | sh
```

Choose another destination without `sudo`:

```sh
curl -fsSL https://yaml.azohra.com/install | YSH_INSTALL_DIR="$HOME/.local/bin" sh
```

Read-only commands need a POSIX-compatible `/bin/sh` and AWK. `--check`, `--diff`, and `-i` also use the host's `mktemp`, `cp`, `cmp`, `mv`, `rm`, and `wc`. No other language runtime is required.

## Read YAML

Given `config.yml`:

```yaml
server:
  host: localhost
  ports: [8080, 8443]
services:
  - name: api
    enabled: true
```

Select a scalar:

```sh
ysh '.server.host' config.yml
# localhost
```

Select a sequence item or filter a stream:

```sh
ysh '.server.ports[1]' config.yml
# 8443

ysh '.services[] | select(.enabled) | .name' config.yml
# api
```

Collections print as compact JSON by default:

```sh
ysh '.services[0]' config.yml
# {"name":"api","enabled":true}
```

Omit the file to read standard input:

```sh
printf '%s\n' 'answer: 42' | ysh '.answer'
```

## Change YAML

Print transformed YAML without changing the file:

```sh
ysh -o=yaml '.release.channel = "stable"' config.yml
```

Preview the exact in-place change:

```sh
ysh --diff '.release.channel = "stable"' config.yml
```

Then write it:

```sh
ysh -i '.release.channel = "stable"' config.yml
```

Common edits retain comments and surrounding formatting. Add `--preserve-only` to fail rather than regenerate YAML when a change cannot be made safely in the original source. See [multiple documents and file edits](documents.md) for check mode, multi-file changes, and exact write guarantees.

## Build and convert

Use `-n` to create a document without reading input:

```sh
ysh -n -o=yaml '{name: "api", enabled: true}'
```

Input can also be JSON, TOML, INI, or XML:

```sh
ysh '.database.port' config.toml
ysh -p xml -o json '.catalog.item' catalog.xml
```

## Next steps

- [Copy a practical recipe](recipes.md)
- [Learn the query language](queries.md)
- [Edit documents and files safely](documents.md)
- [Validate, patch, and convert configuration](contracts.md)
- [See supported YAML syntax](yaml-support.md)
