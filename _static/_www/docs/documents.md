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
ysh -i '.release.channel = "stable"' services/*.yml
```

Every file is parsed and transformed into a sibling candidate first. Only then are originals replaced; a commit failure or interrupt rolls back files already changed.
