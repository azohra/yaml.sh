<p align="center">
  <img src="_static/_www/brand/hero.svg" alt="YAML.sh — YAML in shell, no really" width="900">
</p>

<p align="center">
  <strong>A serious YAML tool in one delightfully questionable medium.</strong>
</p>

<p align="center">
  <a href="https://github.com/azohra/yaml.sh/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/azohra/yaml.sh?style=for-the-badge&labelColor=101410&color=d8ff45"></a>
  <img alt="POSIX shell plus AWK" src="https://img.shields.io/badge/runtime-sh_+_awk-f5f1e8?style=for-the-badge&labelColor=101410">
</p>

<p align="center">
  <a href="https://yaml.azohra.com">Website</a> ·
  <a href="https://yaml.azohra.com/docs/">Docs</a> ·
  <a href="https://yaml.azohra.com/docs/recipes/">Recipes</a> ·
  <a href="https://yaml.azohra.com/docs/supported_yml/">YAML support</a>
</p>

---

YAML.sh reads YAML as a graph, runs a compact expression language over it, and can compile changes back into the original source. The released `ysh` is one POSIX shell executable with its portable AWK engine embedded.

```console
$ ysh '.services[] | select(.enabled) | .name' config.yml
api
web

$ ysh --preserve-only --diff '.image.tag = "stable"' deploy.yml
--- a/deploy.yml
+++ b/deploy.yml
@@ -2 +2 @@
-  tag: old # keep this comment
+  tag: stable # keep this comment
```

No package manager, language runtime, YAML library, plugin host, or opaque binary. The constraint is the fun part.

## Install

```sh
brew install azohra/tools/ysh
```

Or install the checksum-pinned release artifact:

```sh
curl -fsSL https://yaml.azohra.com/install | sh
```

Choose another directory with `YSH_INSTALL_DIR="$HOME/.local/bin"`.

Read-only queries require `/bin/sh` and AWK. Source-aware `--check`, `--diff`, and `-i` also use `mktemp`, `cp`, `cmp`, `mv`, `rm`, and `wc` from the host.

## What makes it useful

### Program the structure

Paths, streams, filters, reducers, construction, updates, aliases, merges, metadata, and multi-document input share one node graph.

```sh
ysh '.services | map(select(.port >= 8000)) | map(.name)' config.yml
ysh -n -o yaml '{name: "api", enabled: true, ports: [8080, 8443]}'
ysh -o yaml '.replicas += 1 | del(.metadata.internal)' deploy.yml
ysh eval-all '. as $doc ireduce ({}; . * $doc)' defaults.yml production.yml
```

The syntax is intentionally familiar to yq users, but YAML.sh's product is the portable graph, source compiler, and repository transaction—not imitation for its own sake.

### Edit YAML without eating the comments

```sh
ysh --check '.image.tag = "stable"' services/*.yml
ysh --diff '.image.tag = "stable"' services/*.yml
ysh --preserve-only -i '.image.tag = "stable"' services/*.yml
```

Scalar, flow, block-scalar, insert, delete, comment, and reorder changes compile into owned source spans. Bytes outside those spans stay intact. `--preserve-only` refuses a transform that would require semantic regeneration.

`--check` and `--diff` write nothing and return `0` when clean, `1` when files would change, and `2` on error. The exact prepared candidates flow into `-i`. Multi-file writes work from snapshots, detect drift, skip no-ops, and retain rollback material.

### Work with configuration contracts

```sh
ysh --schema service.schema.json '.' service.yml
ysh --apply-patch change.json --preserve-only --diff service.yml
ysh --merge-patch production.json -i service.yml
ysh --json --generate-patch desired.yml '.' current.yml > change.json
```

JSON Pointer, JSON Patch, Merge Patch, and a documented JSON Schema profile operate directly on the graph. JSON, YAML, TOML, INI, XML, properties, CSV, TSV, Base64, URI, and shell-text codecs are built in.

### Inspect what happened

```sh
ysh --type '.release.created' config.yml
ysh '[.services[0].port | line, .services[0].port | column]' config.yml
ysh --events config.yml
ysh --ast config.yml
ysh --explain=json --diff '.image.tag = "stable"' deploy.yml 2>changes.jsonl
```

Events and AST output expose the parser. Explain mode reports selection paths, mutations, and presentation decisions without logging values.

## Trust model

Documents are data. Queries are programs. YAML.sh does not spawn commands, open network connections, load plugins, or construct application objects from tags. Environment reads, query-selected local-file reads, and dynamic expression evaluation can be disabled independently:

```sh
ysh \
  --max-input-bytes 1048576 \
  --max-nodes 20000 \
  --max-depth 80 \
  --security-disable-env-ops \
  --security-disable-file-ops \
  --security-disable-eval \
  "$QUERY" input.yml
```

Those controls narrow capability; they do not make an untrusted query a sandbox. Read [security and limits](https://yaml.azohra.com/docs/security/) before crossing a trust boundary.

## Know the boundary

YAML.sh names support instead of implying it:

- [YAML support](https://yaml.azohra.com/docs/supported_yml/) records accepted and rejected syntax.
- [Query guide](https://yaml.azohra.com/docs/queries/) defines the expression language.
- [Operator manifest](https://yaml.azohra.com/docs/operators/) audits the yq-shaped surface with evidence for every row.
- [Configuration contracts](https://yaml.azohra.com/docs/contracts/) define patches, schemas, and non-YAML codecs.

Unsupported neighboring syntax should fail clearly rather than return a plausible lie. The release suite checks pinned parser outcomes, cross-AWK and cross-shell behavior, differential semantics, source-preservation properties, transaction races and faults, adversarial limits, and useful scale.

## Build and contribute

```sh
make all
```

Development source is modular under `src/awk/`; the build assembles the single `ysh` artifact. Start with [DESIGN.md](DESIGN.md), then read the [internals](https://yaml.azohra.com/docs/internals/) and [development](https://yaml.azohra.com/docs/development/) guides.

## License

[MIT](LICENSE)
