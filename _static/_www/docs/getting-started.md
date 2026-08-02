# Install & quick start

YAML.sh ships as one executable text file. The released file contains both the portable shell launcher and the AWK engine.

## Install the pinned release

```sh
curl -fsSL https://raw.githubusercontent.com/azohra/yaml.sh/v1.7.0/ysh -o ysh
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

The release suite covers macOS AWK, mawk, original AWK, POSIX-mode gawk, and BusyBox AWK across several POSIX shells. Bash, Python, Ruby, Node.js, Go, `jq`, and a package manager are not runtime requirements.

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

Slice and label a result:

```sh
ysh '"\(.server.host):\(.server.ports[0:2] | length)"' config.yml
# localhost:2
```

Transform and emit YAML:

```sh
ysh -o=yaml '.release.channel = "stable"' config.yml
```

Once the result looks right, update the file in place:

```sh
ysh -i '.release.channel = "stable"' config.yml
```

In-place output is atomic and preserves file permissions. Common replacements, inserts, deletes, and sequence reorders retain comments, blank lines, directives, properties, block/flow layout, and quote style. Unsupported presentation edits fall back to stable semantic YAML—review the diff like the tiny chaos engineer you are.

## Bound hostile input

Defaults are generous; automation can tighten them:

```sh
ysh --max-input-bytes 1048576 --max-nodes 20000 --max-depth 64 '.' config.yml
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

## Compose configuration

Environment values can stay strings or be parsed as YAML:

```sh
IMAGE_TAG=v1.7 ysh '.image.tag = strenv(IMAGE_TAG)' deploy.yml
LIMITS='{cpu: 2, memory: 1Gi}' ysh '.resources = env(LIMITS)' deploy.yml
```

Evaluate files independently by listing them, or evaluate one expression across the combined document stream:

```sh
ysh '[filename, .name]' one.yml two.yml
ysh eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' defaults.yml production.yml
```

## Next steps

- [Learn paths, streams, construction, and updates](queries.md)
- [Choose value, JSON, YAML, type, tag, or line output](output.md)
- [Read the YAML support contract](supported_yml.md)
- [Compare the focused surface with yq](yq-compatibility.md)
