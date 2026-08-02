<p align="center">
  <img src="_static/_www/brand/hero.svg" alt="YAML.sh — yq energy, zero baggage" width="900">
</p>

<p align="center">
  <strong>A useful YAML tool for the moment before you can install tools.</strong>
</p>

<p align="center">
  <a href="https://github.com/azohra/yaml.sh/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/azohra/yaml.sh?style=for-the-badge&labelColor=101410&color=d8ff45"></a>
  <a href="https://github.com/azohra/yaml.sh/actions/workflows/ci.yml"><img alt="CI status" src="https://img.shields.io/github/actions/workflow/status/azohra/yaml.sh/ci.yml?style=for-the-badge&label=tests&labelColor=101410"></a>
  <img alt="POSIX shell plus AWK" src="https://img.shields.io/badge/runtime-sh_+_awk-f5f1e8?style=for-the-badge&labelColor=101410">
</p>

<p align="center">
  <a href="https://yaml.azohra.com">Website</a> ·
  <a href="https://yaml.azohra.com/docs/">Docs</a> ·
  <a href="https://yaml.azohra.com/docs/recipes/">Recipes</a> ·
  <a href="https://yaml.azohra.com/docs/yq-compatibility/">yq compatibility</a>
</p>

---

YAML.sh brings a focused, yq-shaped query language to bootstrap scripts, tiny containers, old machines, and mildly cursed recovery shells. The released `ysh` is one readable text file: a POSIX `/bin/sh` launcher with its AWK parser and evaluator embedded.

No package manager. No language runtime. No YAML library. No mystery binary.

```console
$ ysh '.services[] | select(.enabled) | .name' config.yml
api
web

$ ysh -i '.services[] | select(.enabled) | .tier = "active"' config.yml

$ ysh -i '.image.tag = "stable"' deploy/*.yml
```

## Install one file

The hosted installer downloads the release artifact, verifies its pinned SHA-256 digest, then writes it to `/usr/local/bin`:

```sh
curl -fsSL https://yaml.azohra.com/install | sh
```

Install without `sudo`:

```sh
curl -fsSL https://yaml.azohra.com/install | YSH_INSTALL_DIR="$HOME/.local/bin" sh
```

Requirements: `/bin/sh` and AWK. That is the whole runtime dependency graph.

## Why this exists

Sometimes yq is exactly right. Sometimes you are writing the script that would install yq.

YAML.sh is for that second moment. It keeps the useful paths, streams, filters, construction, updates, environment composition, and multi-file configuration work. It deliberately leaves out codecs, dynamic evaluation, file-loading operators, dates, and other features that would compromise the small portable runtime.

The constraint is the fun part.

## Do real configuration work

Read and filter:

```sh
ysh '.server.ports[1]' config.yml
ysh '.services[] | select(.enabled) | .name' config.yml
ysh '.services | filter(.port >= 8000) | map(.name)' config.yml
```

Build and update:

```sh
ysh -n -o=yaml '{name: "api", enabled: true, ports: [8080, 8443]}'
ysh -o=yaml '.replicas += 1 | del(.metadata.internal)' deploy.yml
ysh -i '.image.tag = "stable"' deploy.yml
ysh -i 'setpath(["jobs", "deploy", "runs-on"]; "ubuntu-latest")' workflow.yml
ysh -i '.metadata.release = "2026-08"' services/*.yml
```

Compose files and environment:

```sh
IMAGE_TAG=stable ysh -i '.image.tag = strenv(IMAGE_TAG)' deploy.yml
ysh eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' defaults.yml production.yml
```

Inspect the parser:

```sh
ysh --type '.release.created' config.yml
ysh --line '.services[0].port' config.yml
ysh --events config.yml
ysh --ast config.yml
ysh --explain -i '.image.tag = "stable"' deploy.yml
ysh --explain=json -i '.image.tag = "stable"' deploy/*.yml 2>changes.jsonl
```

`--explain` writes mutation paths and the presentation decision to stderr, without echoing values. Its JSON form emits one audit record per input.

The [recipe book](https://yaml.azohra.com/docs/recipes/) starts with tasks. The [query guide](https://yaml.azohra.com/docs/queries/) covers the language.

## One file, real structure

YAML.sh parses YAML into a node graph:

```text
YAML stream → node graph → aliases + merges → expression stream → values / YAML
```

Mappings remain mappings. Empty collections survive. Tags and source lines stay attached. Anchors and aliases retain shared identity. Updates operate on selected nodes rather than reconstructed strings.

Common in-place replacements, inserts, deletes, and sequence reorders preserve comments, whitespace, quoting, styles, anchors, tags, and directives. Styles, tags, anchors, and aliases are writable graph metadata. Larger structural changes fall back to deterministic semantic YAML.

Multi-file `-i` is one transaction: every candidate is parsed and transformed before the first replacement. A commit failure or interrupt restores preserved originals.

## Useful, measured, bounded

The release contract is evidence, not a universal compliance claim:

| Gate | Current release |
| --- | ---: |
| Expected YAML Test Suite outcomes | 282/282 |
| Strict-invalid inputs rejected | 91/91 |
| Categorized programs matching yq v4.53.3 | 2,620/2,620 |
| Real-world workflow programs matching yq | 35/35 |
| Cross-file programs matching yq | 8/8 |
| Behavioral tests | 94 |
| Grammar-guided properties | 12,000/12,000 |
| Exact presentation mutations | 400/400 |
| Scale contract | 125,000 nodes; 1,500 documents; ≤224 MiB RSS |

Supported behavior has a test. Nearby unsupported behavior gets an explicit error instead of a confident misparse.

Read the exact [YAML support contract](https://yaml.azohra.com/docs/supported_yml/) and the honest [yq capability map](https://yaml.azohra.com/docs/yq-compatibility/).

## A deliberately small security model

YAML.sh does not run YAML as shell code, construct application objects from tags, load neighboring files, execute commands, or provide dynamic evaluation. Input bytes, graph nodes, and collection depth have configurable ceilings. Environment operators can be disabled entirely.

```sh
ysh \
  --max-input-bytes 1048576 \
  --max-nodes 20000 \
  --max-depth 80 \
  --security-disable-env-ops \
  '.metadata.name' untrusted.yml
```

See [security and limits](https://yaml.azohra.com/docs/security/) for the trust boundary.

## CLI at a glance

```text
ysh [OPTIONS] QUERY [FILE...]
ysh eval-all QUERY FILE...
```

| Option | Purpose |
| --- | --- |
| `-o value|raw|json|yaml` | Select output form |
| `-r`, `--json`, `-y` | Raw scalar, JSON, or YAML shortcuts |
| `-i` | Transactionally update one or more real files |
| `-n` | Build output without reading input |
| `-e` | Fail on empty, null, or false output |
| `-I N`, `--unwrap-scalar=false` | Control YAML indentation or retain scalar presentation |
| `-d N`, `--all-documents` | Select one or every YAML document |
| `--type`, `--tag`, `--line` | Inspect selected node metadata |
| `--ast`, `--events` | Inspect parser structure |
| `--explain`, `--explain=json` | Report value-free mutations and presentation behavior |
| `--max-input-bytes`, `--max-nodes`, `--max-depth` | Bound hostile input |

Run `ysh --help` for the complete interface.

## Hack on it

```sh
make all
```

That builds the standalone file, runs ShellCheck, and executes the behavioral suite. The portability matrix covers macOS AWK, mawk, original AWK, POSIX-mode gawk, BusyBox AWK, and several POSIX shells. The longer conformance, differential, fuzz, presentation, adversarial, and scale evidence runs before releases and weekly.

The implementation is intentionally inspectable. Start with the [internals guide](https://yaml.azohra.com/docs/internals/) or [development guide](https://yaml.azohra.com/docs/development/).

## Versions mean compatibility

YAML.sh follows [Semantic Versioning](VERSIONING.md). Features grow v1 with minor releases; fixes use patches; v2 requires a necessary, named incompatibility and migration path. Capability belongs in the evidence, not an inflated major number.

## License

[MIT](LICENSE)
