# Security & limits

YAML.sh parses data and runs an explicit query program. It never evaluates YAML as shell, runs commands, opens network connections, or executes application-specific tag constructors.

## The small security model

- No system execution, network, or plugin operators.
- No application-specific object construction from YAML tags.
- Environment access is limited to explicit `env`, `strenv`, and `envsubst` operators.
- File access is limited to explicit `load`, `load_str`, `load_base64`, and `load_props`; every read shares the input-byte ceiling.
- Dynamic `eval` compiles only YAML.sh expressions, has expression-node and nesting ceilings, and can be disabled independently.
- Check, diff, and in-place writes reject symlinks and duplicate inputs, evaluate source snapshots, then refuse detected live-file drift.
- Input bytes, graph nodes, and nesting depth have hard configurable ceilings.

This is a narrower attack surface than a general automation language. It is not a sandbox: a query can still read allowed files and consume CPU and memory up to the configured limits.

## Bound input

```sh
ysh \
  --max-input-bytes 1048576 \
  --max-nodes 20000 \
  --max-depth 80 \
  '.metadata.name' untrusted.yml
```

| Limit | Protects against |
| --- | --- |
| `--max-input-bytes` | Oversized files and streams |
| `--max-nodes` | Documents, embedded codecs, or expressions that create too many graph nodes |
| `--max-depth` | Excessively nested collections and recursive traversal |

Scale tests parse 125,000 payload nodes and 1,500 documents under a 224 MiB RSS ceiling. Set lower limits for smaller workloads or tighter environments.

## Disable environment access

Expressions only read environment variables when they use an environment operator. Disable those operators entirely when the expression comes from another trust boundary:

```sh
ysh --security-disable-env-ops "$UNTRUSTED_QUERY" config.yml
```

The flag makes `env`, `strenv`, and `envsubst` fail rather than returning an empty value.

## Treat queries as programs

Do not splice untrusted strings into a query. Pass data through YAML files or controlled environment variables instead.

```sh
# Avoid constructing syntax from data.
ysh ".users.$UNTRUSTED_NAME" config.yml

# Prefer a controlled variable value and a fixed expression.
USER_NAME="$UNTRUSTED_NAME" ysh '.users[strenv(USER_NAME)]' config.yml
```

Use `--security-disable-env-ops` when even that environment read is inappropriate.

## Disable file access and dynamic evaluation

Loads are useful for bootstrapping configuration, but they follow paths supplied by the query. Disable the entire class when a query crosses a trust boundary:

```sh
ysh --security-disable-file-ops "$UNTRUSTED_QUERY" config.yml
```

The flag makes every `load*` operator fail. It does not affect the input files named on the command line. `load` parses YAML, `load_props` parses properties, `load_str` returns text, and `load_base64` decodes RFC 4648 text. Loaded content is subject to `--max-input-bytes`.

`eval(EXPR)` treats its string as code in YAML.sh's expression language. Disable it when expressions or data may cross a trust boundary:

```sh
ysh --security-disable-eval "$QUERY" config.yml
```

For a restricted query runner, combine all three switches:

```sh
ysh \
  --security-disable-env-ops \
  --security-disable-file-ops \
  --security-disable-eval \
  "$QUERY" config.yml
```

This removes the explicit ambient-read and dynamic-code capabilities. It does not turn the remaining query language into a hardened sandbox.

## In-place writes

`--check`, `--diff`, and `-i` require one or more real files. YAML.sh snapshots and transforms the complete set before replacing anything and creates candidates only for files that actually change. It preserves permissions and refuses symlinks, duplicate paths, and newline-containing names. A changed live input aborts rather than being overwritten. A commit failure or interrupt restores the evaluated snapshots.

`--diff` prints changed values; treat its output like file contents. Use `--explain=json` when logs need paths and decisions without values. Add `--preserve-only` when regenerated presentation would be unsafe or too noisy to review.

Each replacement is an atomic same-directory rename. The multi-file sequence is preflighted and rollback-capable, not globally atomic or power-loss durable. Another process can still race after the final comparison. Keep normal backups and version control; guards do not make a logically wrong query correct.

## Reporting a vulnerability

Do not open a public issue for an undisclosed vulnerability. Follow the repository [security policy](https://github.com/azohra/yaml.sh/security/policy).
