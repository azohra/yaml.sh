# Working on YAML.sh

Read [DESIGN.md](DESIGN.md) first. It owns the product premise, durable
constraints, decision filter, trust model, evidence standard, and
documentation voice. [CONTRIBUTING.md](CONTRIBUTING.md) owns the workflow,
the subsystem gate table, and the generated-file map. This file adds only
what an automated contributor needs operationally; do not restate the
canonical documents here.

## Ground rules

- Edit readable sources under `src/`; never edit the generated `ysh` or
  generated docs. The generated-file map is in `CONTRIBUTING.md`.
- Preserve documented v1 behavior. Only a necessary, prepared break in the
  documented contract selects a major release ([VERSIONING.md](VERSIONING.md)).
- Unsupported neighboring syntax fails closed. Queries are programs and YAML
  is data; do not add system execution, networking, plugins, or application
  tag construction.
- Attach exact evidence to every public claim. Generated case counts are not
  capability counts.

## Change workflow

1. Identify the user job, public-contract impact, and subsystem owner.
2. Add or update the smallest exact behavioral test.
3. Change modular source under `src/` and run `make all`.
4. Run the focused gates for the subsystem you touched, using the gate table
   in `CONTRIBUTING.md`.
5. Update the canonical documentation and changelog for visible behavior.
6. Check that claims remain consistent across README, docs, website, security
   policy, and story without duplicating whole explanations.

Refactors must preserve the generated artifact's behavior and compare before
and after performance on representative workloads (`make scale`,
`make benchmark`). Complexity should move into clear subsystem boundaries,
not merely into more files.

## Operational notes

- After any `src/` change, `testReleaseArtifactsStayInSync` fails until
  `make docs` refreshes the installer checksum. That is the expected
  mid-development state, not a regression.
- Releases follow the exact touchpoint checklist in `VERSIONING.md`.
- House idioms for portable AWK and shell, plus known gotchas, are recorded
  in the [development guide](_static/_www/docs/development.md).
