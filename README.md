<p align="center">
  <img src="_static/_www/brand/hero.svg" alt="YAML.sh — YAML in shell. No, really." width="900">
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

YAML.sh queries, transforms, validates, and edits YAML in one readable POSIX shell file with portable AWK inside. It can change exactly what you asked for without rewriting the comments and formatting around it.

```console
$ ysh '.books[] | select(.read) | .title' reading.yml
Piranesi
The Left Hand of Darkness

$ ysh --preserve-only --diff '.theme = "midnight"' settings.yml
--- a/settings.yml
+++ b/settings.yml
@@ -1 +1 @@
-theme: light # terminal colours
+theme: midnight # terminal colours
```

No extra runtime or package manager. The constraint is the fun part.

## Install

```sh
brew install azohra/tools/ysh
```

Or install the checksum-pinned release artifact:

```sh
curl -fsSL https://yaml.azohra.com/install | sh
```

Choose another directory with `curl -fsSL https://yaml.azohra.com/install | YSH_INSTALL_DIR="$HOME/.local/bin" sh`.

Read-only queries require `/bin/sh` and AWK. `--check`, `--diff`, and `-i` also use `mktemp`, `cp`, `cmp`, `mv`, `rm`, and `wc` from the host.

## What makes it useful

### Query and transform

Use paths, pipes, filters, reducers, construction, and updates without flattening away YAML types, anchors, aliases, or merge keys.

```sh
ysh '.albums | map(select(.rating >= 9)) | map(.title)' music.yml
ysh -n -o yaml '{name: "Ada", tags: ["awk", "yaml"]}'
ysh -o yaml '.count += 1 | del(.draft)' notes.yml
ysh eval-all '. as $doc ireduce ({}; . * $doc)' defaults.yml local.yml
```

### Edit YAML without eating the comments

```sh
ysh --check '.image.tag = "stable"' services/*.yml
ysh --diff '.image.tag = "stable"' services/*.yml
ysh --preserve-only -i '.image.tag = "stable"' services/*.yml
```

YAML.sh can update scalars, collections, block scalars, comments, and ordering while leaving unrelated text alone. `--preserve-only` refuses a change when it cannot keep that promise.

`--check` and `--diff` write nothing and return `0` when clean, `1` when files would change, and `2` on error. Multi-file writes are fully prepared before the first replacement, skip unchanged files, stop if a file changes after YAML.sh reads it, and roll back a failed write.

### Validate, patch, and convert

```sh
ysh --schema service.schema.json '.' service.yml
ysh --apply-patch change.json --preserve-only --diff service.yml
ysh --merge-patch production.json -i service.yml
ysh --json --generate-patch desired.yml '.' current.yml > change.json
```

JSON Pointer, JSON Patch, Merge Patch, and a documented JSON Schema profile are built in. YAML.sh reads and writes JSON, YAML, TOML, INI, and XML; expression codecs cover properties, CSV, TSV, Base64, URI, and shell quoting.

### Inspect strange YAML

```sh
ysh --type '.release.created' config.yml
ysh '[.services[0].port | line, .services[0].port | column]' config.yml
ysh --events config.yml
ysh --ast config.yml
ysh --explain=json --diff '.image.tag = "stable"' deploy.yml 2>changes.jsonl
```

Events and AST output show how YAML.sh understood a document. Explain mode reports selected paths, changes, and formatting decisions without logging values.

## Trust model

YAML files are data; queries are programs. Queries cannot execute commands or open network connections, but they can explicitly read environment variables or local files, and `eval` can compile a dynamically supplied expression. Those capabilities can be disabled independently. Read [security and limits](https://yaml.azohra.com/docs/security/) before running untrusted input.

## Know the boundary

YAML.sh documents what it supports:

- [YAML support](https://yaml.azohra.com/docs/supported_yml/) records accepted and rejected syntax.
- [Queries](https://yaml.azohra.com/docs/queries/) defines the expression language.
- [Validate, patch, and convert](https://yaml.azohra.com/docs/contracts/) defines schemas, patches, and non-YAML formats.
- [Security and limits](https://yaml.azohra.com/docs/security/) explains capabilities and resource ceilings.

Unsupported syntax fails clearly rather than returning a plausible result.

## Build and contribute

```sh
make all
```

Development source is modular under `src/awk/`; the build assembles the single `ysh` artifact. Start with [DESIGN.md](DESIGN.md), then read the [internals](https://yaml.azohra.com/docs/internals/) and [development](https://yaml.azohra.com/docs/development/) guides.

## License

[MIT](LICENSE)
