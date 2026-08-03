# YAML without the luggage

YAML.sh is a focused, yq-like tool delivered as one readable shell file. It runs anywhere with `/bin/sh` and AWK: bootstrap scripts, minimal containers, old machines, and recovery environments where installing the better-known tool is the problem.

```sh
ysh '.services[] | select(.enabled) | .name' config.yml
ysh -i '.services[] | select(.enabled) | .tier = "active"' config.yml
ysh --preserve-only --diff '.release.channel = "stable"' services/*.yml
ysh --schema service.schema.json --apply-patch promote.json --diff service.yml
```

## Start with the task

- [Install one file and run the first query](getting-started.md).
- [Copy a recipe for filtering, updates, environment, or file merging](recipes.md).
- [Learn the query language](queries.md).
- [Validate, patch, compare, and convert configuration](contracts.md).
- [Check the operator manifest](operators.md).
- [Choose value, JSON, YAML, metadata, AST, or events](output.md).
- [Check, compose, and update files or document streams](documents.md).

## The tiny idea

Sometimes yq is exactly right. Sometimes you are writing the script that would install yq.

YAML.sh lives in that second moment. It keeps the useful configuration workflow while protecting the premise:

- one auditable text executable;
- a portable POSIX shell launcher and AWK engine;
- real mappings, sequences, tags, anchors, aliases, and merge behavior;
- a writable expression stream rather than chained query flags;
- graph-native configuration contracts: JSON Pointer/Patch, Merge Patch, and a JSON Schema profile;
- embedded JSON, YAML, TOML, INI, XML, properties, CSV, TSV, Base64, URI, and shell codecs;
- one shared check, diff, and commit plan for repository work;
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

## Where it fits

The useful overlap with yq is large, but deliberate. YAML.sh includes bounded dynamic evaluation, guarded local loads, reproducible shuffle, standard configuration contracts, and portable codecs. System execution, date arithmetic, regex capture objects, remote schema resolution, and yq's complete flag surface remain outside the contract.

Three references make that boundary easy to inspect:

- [YAML support](supported_yml.md) lists parser behavior, limits, and test coverage.
- [Operator manifest](operators.md) classifies every YAML-oriented yq area with named evidence.
- [yq compatibility](yq-compatibility.md) maps the useful overlap and intentional omissions.

Unsupported neighboring syntax should fail explicitly, not produce a plausible lie.

## Trust it appropriately

Input bytes, graph nodes, and nesting depth have configurable ceilings. Environment access can be disabled. In-place writes reject symlinks, preflight every input, and roll back a partial commit.

Read [security and limits](security.md) before handling untrusted documents or expressions.

## Open the hood

```sh
ysh --events config.yml
ysh --ast config.yml
ysh --preserve-only --diff '.image.tag = "stable"' services/*.yml
ysh --explain=json -i '.image.tag = "stable"' services/*.yml 2>changes.jsonl
```

The [internals guide](internals.md) follows a document through the parser. The [development guide](development.md) explains the fixtures, differential cases, rejection tests, and portability checks behind it.

YAML.sh is built for fun. The tests are serious.
