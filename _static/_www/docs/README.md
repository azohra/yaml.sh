# YAML in shell. No, really.

YAML.sh queries, transforms, validates, and edits YAML in one readable POSIX shell file with portable AWK inside. Common edits keep the comments and formatting around them.

```sh
ysh '.books[] | select(.read) | .title' reading.yml
ysh --preserve-only --diff '.theme = "midnight"' settings.yml
ysh --schema settings.schema.json '.' settings.yml
```

## Start with the job

- [Install one file and run the first query](getting-started.md).
- [Copy a recipe for filtering, updates, composition, or validation](recipes.md).
- [Learn paths, streams, construction, and updates](queries.md).
- [Validate, patch, and convert configuration](contracts.md).
- [Check, compose, and update files or document streams](documents.md).
- [Choose value, JSON, YAML, metadata, AST, or events](output.md).

## What it can do

- **Query and transform.** Use paths, pipes, filters, reducers, construction, and updates across files and YAML documents.
- **Edit carefully.** Preview changes with `--check` or `--diff`; use `--preserve-only` when comments and formatting must stay put.
- **Validate, patch, and convert.** Apply JSON Schema, JSON Patch, and Merge Patch, or move between YAML, JSON, TOML, INI, and XML; expression codecs cover properties, CSV, and TSV.
- **Inspect strange input.** View types, source locations, parser events, an AST, or an explanation of an edit.

The released `ysh` contains the complete shell launcher and AWK engine. Copy one file, read it, and run it without another language runtime.

## Know the boundary

- [YAML support](supported_yml.md) records accepted and rejected syntax.
- [Queries](queries.md) defines the expression language.
- [Validate, patch, and convert](contracts.md) defines schemas, patches, and non-YAML formats.
- [Security and limits](security.md) explains optional capabilities, resource ceilings, and write behavior.

Unsupported syntax fails clearly rather than returning a plausible result.

## Open the hood

```sh
ysh --events config.yml
ysh --ast config.yml
ysh --explain=json --diff '.image.tag = "stable"' services/*.yml 2>changes.jsonl
```

The [internals guide](internals.md) follows a document through parsing, evaluation, output, and careful source edits. The [development guide](development.md) explains the codebase and test suite.
