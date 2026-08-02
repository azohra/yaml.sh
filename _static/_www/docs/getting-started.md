# Install & quick start

YAML.sh ships as one executable text file. The released file contains both the portable shell launcher and the AWK engine.

## Install the pinned release

```sh
curl -fsSL https://raw.githubusercontent.com/azohra/yaml.sh/v1.0.0/ysh -o ysh
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

- [Query quoted and punctuated keys](queries.md)
- [Choose JSON, type, tag, or line output](output.md)
- [Read the YAML support contract](supported_yml.md)
