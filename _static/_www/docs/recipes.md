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

Preview the result first:

```sh
ysh -o=yaml '.image.tag = "stable"' deploy.yml
```

Then make the same update atomically:

```sh
ysh -i '.image.tag = "stable"' deploy.yml
```

`-i` refuses symlinks and only replaces the original after every document succeeds.

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
