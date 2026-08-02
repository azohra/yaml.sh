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
