# Multiple documents

YAML streams may contain documents separated by `---` and terminated by `...`.

```yaml
---
environment: development
---
environment: production
```

YAML.sh selects the first document by default. Use a zero-based document index for another:

```sh
ysh --document 1 '.environment' stream.yml
# production
```

The short form is `-d`:

```sh
ysh -d 1 '.environment' stream.yml
```

Anchors and tag handles are scoped to their document. Empty explicit documents are represented as null rather than disappearing from the stream.

In-place mode applies the same expression independently to every document:

```sh
ysh -i '.release.channel = "stable"' stream.yml
```

The update is committed only after the entire stream parses and every document transforms successfully.

Several files form one in-place transaction:

```sh
ysh --check '.release.channel = "stable"' services/*.yml
ysh --diff '.release.channel = "stable"' services/*.yml
ysh -i '.release.channel = "stable"' services/*.yml
```

The query is compiled once and every file is parsed in one AWK process. Check mode reports which files drift; diff mode prints the exact prepared candidates. Both write nothing and return clean `0`, drift `1`, or error `2`.

Add `--preserve-only` to `--check`, `--diff`, or `-i` when source fidelity is a requirement:

```sh
ysh --preserve-only --diff '.release.channel = "stable"' services/*.yml
```

If any changed file would need deterministic YAML regeneration, the complete preflight fails with exit `2`. In-place mode replaces nothing until all candidates pass; no-op files stay untouched, and a commit failure or interrupt rolls back files already changed.

Use `eval-all` when files need to share data. The combined stream keeps `filename`, `fileIndex`, and `documentIndex` on every root:

```sh
query='select(fileIndex == 0).version as $version | select(fileIndex > 0).release.version = $version'
ysh eval-all --check "$query" release.yml services/*.yml
ysh eval-all -i "$query" release.yml services/*.yml
```

Every mutated source file participates in the same preflight and commit. A read-only source file that does not change is not replaced.
