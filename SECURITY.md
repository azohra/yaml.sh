# Security policy

Only the latest release receives security fixes. Report suspected
vulnerabilities privately through this repository's GitHub Security Advisories,
not a public issue.

YAML.sh parses documents as data and queries as programs. Queries cannot execute
commands, access the network, load plugins, or construct application objects
from YAML tags. YAML.sh is not a sandbox or a security boundary.

For untrusted documents, use a fixed query and set `--max-input-bytes`,
`--max-nodes`, and `--max-depth` for the host. For queries from another trust
boundary, disable every capability they do not need:

```sh
ysh \
  --security-disable-env-ops \
  --security-disable-file-ops \
  --security-disable-eval \
  "$QUERY" input.yml
```

Those switches block environment reads, query-selected local-file reads, and
dynamic YAML.sh expression evaluation respectively. They do not make an
untrusted query safe: it can still consume CPU and memory within configured
limits and inspect the input files supplied by the caller.

`--check`, `--diff`, and `-i` reject symlinks and duplicate inputs, work from
snapshots, detect source drift, and retain rollback material. A multi-file
commit is rollback-capable; it is not globally atomic or power-loss durable.

The complete trust and write model is documented at
<https://yaml.azohra.com/docs/security/>.
