# Install & quick start

YAML.sh ships as one executable text file. The released file contains both the portable shell launcher and the AWK engine.

## Install the pinned release

```sh
curl -fsSL https://raw.githubusercontent.com/azohra/yaml.sh/v1.4.0/ysh -o ysh
chmod +x ysh
sudo mv ysh /usr/local/bin/ysh
```

Or run the small installer:

```sh
curl -fsSL https://yaml.azohra.com/install | sh
```

Choose another destination without `sudo`:

```sh
curl -fsSL https://yaml.azohra.com/install | YSH_INSTALL_DIR="$HOME/.local/bin" sh
```

## Requirements

- A POSIX-style `/bin/sh`.
- A compatible AWK implementation.

The release suite covers macOS AWK, Ubuntu AWK, and BusyBox AWK. Bash, Python, Ruby, Node.js, Go, `jq`, and a package manager are not required.

## First query

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

Select a sequence item:

```sh
ysh '.server.ports[1]' config.yml
# 8443
```

Select a collection:

```sh
ysh '.services[0]' config.yml
# {"name":"api","enabled":true}
```

Stream and filter nodes:

```sh
ysh '.services[] | select(.enabled) | .name' config.yml
# api
```

Use a default when a path is missing, null, or false:

```sh
ysh '.release.channel // "stable"' config.yml
# stable
```

Transform and emit YAML:

```sh
ysh -o=yaml '.release.channel = "stable"' config.yml
```

Once the result looks right, update the file in place:

```sh
ysh -i '.release.channel = "stable"' config.yml
```

In-place output preserves file permissions. Scalar-only changes also preserve comments, blank lines, layout, and plain/single/double quote style. Structural changes use normalized semantic YAML, so review the diff like the tiny chaos engineer you are.

## Standard input

Omit the file to read YAML from standard input:

```sh
printf '%s\n' 'answer: 42' | ysh '.answer'
```

Use `-` explicitly when it helps a generated command read clearly:

```sh
generate-config | ysh '.release.version' -
```

## Next steps

- [Learn paths, streams, construction, and updates](queries.md)
- [Choose value, JSON, YAML, type, tag, or line output](output.md)
- [Read the YAML support contract](supported_yml.md)
