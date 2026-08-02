# YAML without the luggage

YAML.sh is a focused, yq-like tool delivered as one readable shell file. It runs anywhere with `/bin/sh` and AWK: bootstrap scripts, minimal containers, old machines, and recovery environments where installing the better-known tool is the problem.

```sh
ysh '.services[] | select(.enabled) | .name' config.yml
ysh -i '.services[] | select(.enabled) | .tier = "active"' config.yml
```

## Start with the task

- [Install one file and run the first query](getting-started.md).
- [Copy a recipe for filtering, updates, environment, or file merging](recipes.md).
- [Learn the query language](queries.md).
- [Choose value, JSON, YAML, metadata, AST, or events](output.md).
- [Work across files and document streams](documents.md).

## The tiny idea

Sometimes yq is exactly right. Sometimes you are writing the script that would install yq.

YAML.sh lives in that second moment. It keeps the useful configuration workflow while protecting the premise:

- one auditable text executable;
- a portable POSIX shell launcher and AWK engine;
- real mappings, sequences, tags, anchors, aliases, and merge behavior;
- a writable expression stream rather than chained query flags;
- no package manager, runtime, plugin system, or hidden binary.

## Real structure

```text
YAML source
    ↓
tokens and parser events
    ↓
mapping / sequence / scalar / alias graph
    ↓
merge resolution and expression streams
    ↓
value / JSON / YAML / metadata
```

The graph is why empty collections survive, punctuated keys behave, aliases retain identity, and in-place changes can preserve source presentation.

## Honest boundaries

The useful overlap with yq is large, but deliberate. YAML.sh does not implement non-YAML codecs, dates, file-loading operators, dynamic evaluation, system execution, or yq's complete operator and flag surface.

The project publishes two contracts instead of a compatibility percentage:

- [YAML support](supported_yml.md) records parser behavior and measured evidence.
- [yq compatibility](yq-compatibility.md) records the useful overlap and intentional omissions.

Unsupported neighboring syntax should fail explicitly, not produce a plausible lie.

## Trust it appropriately

Input bytes, graph nodes, and nesting depth have configurable ceilings. Environment access can be disabled. In-place writes reject symlinks and only replace a file after the full transformation succeeds.

Read [security and limits](security.md) before handling untrusted documents or expressions.

## Open the hood

```sh
ysh --events config.yml
ysh --ast config.yml
ysh --explain -i '.image.tag = "stable"' config.yml
```

The [internals guide](internals.md) follows a document through the parser. The [development guide](development.md) explains how each new promise earns fixtures, differential cases, rejection tests, and portability evidence.

YAML.sh is built for fun. The support contract is serious.
