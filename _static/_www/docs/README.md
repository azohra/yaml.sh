# YAML in shell. No, really.

YAML.sh is a serious YAML tool built in an intentionally mischievous medium: one readable POSIX shell executable with portable AWK inside. It queries, transforms, validates, converts, inspects, and edits YAML without acquiring another language runtime.

```sh
ysh '.services[] | select(.enabled) | .name' config.yml
ysh --preserve-only --diff '.release.channel = "stable"' services/*.yml
ysh --schema service.schema.json --apply-patch promote.json --diff service.yml
```

## Start with the job

- [Install one file and run the first query](getting-started.md).
- [Copy a recipe for filtering, updates, composition, or validation](recipes.md).
- [Learn paths, streams, construction, and updates](queries.md).
- [Validate, patch, compare, and convert configuration](contracts.md).
- [Check, compose, and update files or document streams](documents.md).
- [Choose value, JSON, YAML, metadata, AST, or events](output.md).

## The product

The released `ysh` contains a POSIX shell launcher and portable AWK engine. It needs no package manager, language runtime, YAML library, plugin host, or opaque binary.

Its useful shape comes from four parts:

- **A real graph.** Mappings, sequences, tags, anchors, aliases, merges, source locations, and empty collections retain their meaning.
- **A compact language.** Familiar paths, pipes, filters, reducers, construction, and updates operate on writable node streams.
- **A source compiler.** Common changes become owned edit spans, so unrelated bytes and attached comments survive. `--preserve-only` makes that a precondition.
- **A repository transaction.** Check, diff, and write share prepared candidates. Multi-file updates use snapshots, detect drift, skip no-ops, and retain rollback material.

Yq-shaped syntax is a useful interface influence and comparison oracle. It is not the reason YAML.sh exists.

## Know the boundary

The docs separate product claims from test volume:

- [YAML support](supported_yml.md) records accepted and rejected syntax.
- [Operator manifest](operators.md) classifies the yq-shaped surface with named evidence.
- [Configuration contracts](contracts.md) define schemas, patches, and non-YAML codecs.
- [Security and limits](security.md) defines capabilities, resource ceilings, and write guarantees.

Unsupported neighboring input should fail clearly instead of returning a plausible lie.

## Open the hood

```sh
ysh --events config.yml
ysh --ast config.yml
ysh --explain=json --diff '.image.tag = "stable"' services/*.yml 2>changes.jsonl
```

The [internals guide](internals.md) follows a document through the graph, evaluator, emitter, and source compiler. The [development guide](development.md) explains how exact capabilities map to fixtures, properties, and external oracles.

YAML.sh is built for fun. The contract is serious.
