# Recipes

Start from the task. Every example uses the released `ysh` file and ordinary YAML input.

## Read one value

```sh
ysh '.server.port' config.yml
```

Use `-r` when another command needs unquoted scalar text:

```sh
host=$(ysh -r '.server.host' config.yml)
```

## Select matching entries

```sh
ysh '.services[] | select(.enabled) | .name' config.yml
ysh '.services | filter(.port >= 8000) | map(.name)' config.yml
```

Add `-e` when an empty, null, or false result should fail a shell script:

```sh
ysh -e '.services[] | select(.name == "api")' config.yml >/dev/null
```

## Change a file safely

Preview the exact write first:

```sh
ysh --diff '.image.tag = "stable"' deploy.yml
```

Exit status is `0` for clean, `1` for drift, and `2` for an invalid query or input. Use `--check` when a file list is enough. Then commit the same prepared update:

```sh
ysh -i '.image.tag = "stable"' deploy.yml
```

`-i` refuses symlinks and only replaces the original after every document succeeds.

When preserving comments and layout is mandatory, make it executable policy:

```sh
ysh --preserve-only --diff '.image.tag = "stable"' deploy.yml
ysh --preserve-only -i '.image.tag = "stable"' deploy.yml
```

The command fails instead of falling back to regenerated YAML.

Update a repository as one transaction:

```sh
ysh --check '.image.tag = "stable"' services/*.yml
ysh --diff '.image.tag = "stable"' services/*.yml
ysh --explain=json -i '.image.tag = "stable"' services/*.yml 2>changes.jsonl
```

Every candidate is prepared before the first replacement. The JSON Lines report records paths and decisions without recording changed values.

Require an invariant before changing anything:

```sh
query='with(.kind; select(. == "Deployment") or error("expected Deployment")) | .spec.replicas = 3'
ysh --diff "$query" deploy.yml
ysh -i "$query" deploy.yml
```

`error(MESSAGE)` aborts the complete transaction. Boolean `and` and `or` short-circuit, so the error runs only when its guard fails.

## Set values from the environment

`strenv` always creates a string. `env` parses the variable as YAML.

```sh
IMAGE_TAG=stable ysh -i '.image.tag = strenv(IMAGE_TAG)' deploy.yml
LIMITS='{cpu: 2, memory: 512Mi}' ysh '.resources = env(LIMITS)' deploy.yml
```

Disable environment operators when expressions are untrusted:

```sh
ysh --security-disable-env-ops '.services | length' config.yml
```

## Merge defaults with an override

```sh
ysh eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' defaults.yml production.yml
```

The right mapping wins at scalar leaves. This focused `eval-all` workflow covers configuration layering; it is not yq's entire stream engine.

Choose how arrays and keys merge:

```sh
ysh -n --json '{ports: [80]} *+ {ports: [443]}'       # append arrays
ysh -n --json '{api: {port: 80}} *? {api: {port: 81}, web: {port: 80}}' # existing keys only
ysh -n --json '{api: {port: 80}} *n {api: {port: 81}, web: {port: 80}}' # new keys only
```

Use `*d` to merge array entries by index.

## Share data across files

Writable `eval-all` evaluates once over every input, so one file can supply a value used to update the others:

```sh
query='select(fileIndex == 0).version as $version | select(fileIndex > 0).release.version = $version'
ysh eval-all --check "$query" release.yml services/*.yml
ysh eval-all -i "$query" release.yml services/*.yml
```

All mutated files preflight and commit together. Unchanged files are not replaced.

## Work across every document

```sh
ysh --all-documents '[documentIndex, .metadata.name]' stream.yml
ysh --document 2 '.spec' stream.yml
```

## Build new YAML

```sh
ysh -n -o=yaml '{name: "api", enabled: true, ports: [8080, 8443]}'
```

## Inspect a strange document

```sh
ysh --type '.release.created' config.yml
ysh --tag '.widget' config.yml
ysh --line '.services[0].port' config.yml
ysh --events config.yml
ysh --ast config.yml
```

Use the event stream to see what the parser recognized, then the AST to inspect resolved node identity, tags, anchors, aliases, and merges.

## Bound hostile input

```sh
ysh \
  --max-input-bytes 1048576 \
  --max-nodes 20000 \
  --max-depth 80 \
  --security-disable-env-ops \
  '.metadata.name' untrusted.yml
```

These are rejection ceilings, not tuning hints. Pick limits appropriate to the workload.
