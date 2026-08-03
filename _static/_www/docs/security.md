# Security & limits

YAML.sh parses data and runs an explicit query program. Queries cannot execute commands, open network connections, or construct application objects from YAML tags; YAML input is never evaluated as shell.

## Trust the query separately from the document

- No system execution, network, or plugin operators.
- No application-specific object construction from YAML tags.
- Environment access is limited to explicit `env`, `strenv`, and `envsubst` operators.
- File access is limited to explicit `load`, `load_str`, `load_base64`, and `load_props`; every read shares the input-byte ceiling.
- Dynamic `eval` compiles only YAML.sh expressions, has expression-node and nesting ceilings, and can be disabled independently.
- Check, diff, and in-place writes reject symlinks and duplicate inputs, evaluate source snapshots, then refuse detected live-file drift.
- Input bytes, graph nodes, and nesting depth have hard configurable ceilings.

Documents are data; queries are programs. A fixed query can inspect an untrusted document within configured resource limits. Do not assume an untrusted query is safe merely because it cannot launch a command: it can still inspect its inputs, use enabled ambient reads, and consume CPU and memory. YAML.sh is not a sandbox.

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

Defaults are 16 MiB of input, 100,000 graph and expression nodes, and 256 levels of collection depth. Set lower limits when the expected documents are smaller.

## Disable environment access

Expressions only read environment variables when they use an environment operator. Disable those operators entirely when the query does not need them:

```sh
ysh --security-disable-env-ops '.services | length' config.yml
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

Loads follow paths supplied by the query. Disable the entire class when local-file access is unnecessary:

```sh
ysh --security-disable-file-ops '.services | length' config.yml
```

The flag makes every `load*` operator fail. It does not affect the input files named on the command line. `load` parses YAML, `load_props` parses properties, `load_str` returns text, and `load_base64` decodes RFC 4648 text. Loaded content is subject to `--max-input-bytes`.

`eval(EXPR)` treats its string as code in YAML.sh's expression language. Disable it unless dynamic expressions are required:

```sh
ysh --security-disable-eval "$QUERY" config.yml
```

For a fixed query that needs no ambient reads or dynamic code, combine all three switches:

```sh
ysh \
  --security-disable-env-ops \
  --security-disable-file-ops \
  --security-disable-eval \
  "$QUERY" config.yml
```

This removes the explicit ambient-read and dynamic-code capabilities. It does not make an untrusted query safe.

## In-place writes

`--check`, `--diff`, and `-i` require one or more real files. YAML.sh snapshots and transforms the complete set before replacing anything and creates candidates only for files that actually change. It preserves permissions and refuses symlinks, duplicate paths, and newline-containing names. If a live input changes during the run, the operation aborts rather than overwriting it. A write failure or interrupt restores files already changed from the evaluated snapshots.

`--diff` prints changed values; treat its output like file contents. Use `--explain=json` when logs need paths and decisions without values. Add `--preserve-only` when regenerated presentation would be unsafe or too noisy to review.

Each file replacement is an atomic same-directory rename. A multi-file batch is not globally atomic or power-loss durable. Another process can still race after the final comparison. Keep normal backups and version control; guards do not make a logically wrong query correct.

## Reporting a vulnerability

Do not open a public issue for an undisclosed vulnerability. Follow the repository [security policy](https://github.com/azohra/yaml.sh/security/policy).
