# Install & quick start

YAML.sh ships as one executable text file. The released file contains both the portable shell launcher and the AWK engine.

## Install with Homebrew

```sh
brew install azohra/tools/ysh
```

Homebrew installs the same single-file release artifact used by the direct installer.

## Install directly

The hosted installer downloads the release artifact, verifies its pinned SHA-256 digest, then writes it to the install directory:

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

Ask whether the update would change anything:

```sh
ysh --check '.release.channel = "stable"' config.yml
```

Check mode writes nothing. It exits `0` when clean, `1` when the query would change a file, and `2` when the query or input is invalid. Once the check looks right, update in place:

See the exact candidate instead:

```sh
ysh --diff '.release.channel = "stable"' config.yml
```

```sh
ysh -i '.release.channel = "stable"' config.yml
```

In-place output is atomic and preserves file permissions. Common replacements, inserts, deletes, sequence reorders, and block appends retain comments, blank lines, directives, properties, layout, and quote style. Unsupported presentation edits fall back to stable semantic YAML. Add `--preserve-only` to make that fallback an error.

The same expression can check or update several files as one preflighted transaction:

```sh
ysh --check '.release.channel = "stable"' services/*.yml
ysh --diff '.release.channel = "stable"' services/*.yml
ysh -i '.release.channel = "stable"' services/*.yml
```

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
IMAGE_TAG=stable ysh '.image.tag = strenv(IMAGE_TAG)' deploy.yml
LIMITS='{cpu: 2, memory: 1Gi}' ysh '.resources = env(LIMITS)' deploy.yml
```

Evaluate files independently by listing them, or evaluate one expression across the combined document stream:

```sh
ysh '[filename, .name]' one.yml two.yml
ysh eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' defaults.yml production.yml
ysh eval-all -i 'select(fileIndex == 0).version as $version | select(fileIndex > 0).release.version = $version' release.yml services/*.yml
```

## Next steps

- [Learn paths, streams, construction, and updates](queries.md)
- [Choose value, JSON, YAML, type, tag, or line output](output.md)
- [Explore supported YAML syntax and limits](supported_yml.md)
- [Compare the focused surface with yq](yq-compatibility.md)

Maintaining a script written for the original command interface? Use the focused [legacy migration guide](migration.md).
