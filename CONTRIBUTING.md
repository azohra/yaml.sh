# Contributing

Thanks for improving YAML.sh. Keep changes compatible with POSIX `/bin/sh` and
the AWK implementations covered by the portability tests; the standalone
executable must not require a third-party runtime.

Read [the design](DESIGN.md) first. It defines the product premise, invariants, architecture, evidence standard, and compatibility rules used to evaluate changes.

## Development workflow

1. Add or update a test in `test/test.sh`. Parser fixtures belong in `test/`.
2. Edit the readable sources in `src/`. Never edit generated files; the map is below.
3. Run `mise run check` to rebuild, lint, and test the project. Runtime and
   docs-generator changes also need `mise run check:linux-portability`; Docker
   supplies the Linux AWK and shell matrix that CI runs. Then run the focused
   gates for the subsystem you touched. Update `test/public-contract.tsv` when
   the supported surface or its product role changes.
4. Update documentation and record the completed changes in the PR title and body.

| You changed | Also run |
| --- | --- |
| YAML parser, scalars, or graph | `make fuzz`, `make presentation`, `make conformance`, `make parser-boundaries` |
| Query parser or evaluators | `make fuzz`, `make differential`, `make operator-manifest` |
| Source-edit compiler or diff renderer | `make presentation`, `make fuzz` |
| Codecs, schema, pointer, or patches | `make toml-conformance`, `make schema-conformance`, `make json-patch-conformance` |
| Resource limits or transactions | `make adversarial`, `make scale` |
| Docs sources or generators | `make docs`, `make docs-check` |

Before a release, `mise run evidence` runs the full measured battery: conformance
against the pinned YAML, TOML, JSON Schema and JSON Patch corpora, differential
agreement with a pinned yq, and the scale and benchmark budgets. It fetches those
corpora itself. `mise run evidence:busybox` repeats the conformance, differential,
and fuzz measurements with BusyBox AWK in Docker. The weekly job runs both verbs.

CI's `Check` job requires successful runtime, documentation, and portability
results. Use this stable result for branch protection.

`mise run push` checks and publishes a clean feature branch for PR review.

## Generated files

Edit the sources and run their build command:

| Output | Source and command |
| --- | --- |
| `ysh` (ignored) | `src/ysh.sh`, `src/awk/*.awk`, and `src/diff.awk`; `make ysh` builds the development executable |
| `_static/_www/docs/*/index.html`, `_static/_www/docs/index.html`, `_static/_www/docs/search-index.json` | `make docs` renders the documentation Markdown; these outputs remain committed |
| `.release/` (ignored) | `mise run build:release` builds the versioned executable, checksum and release notes |
| `.release/site/` (ignored) | `mise run deploy` builds the website, filling the installer and homepage from downloaded published assets |

The PR title and body become the squash commit and supply the changelog.
`mise run changelog` renders pending changes and release history.
[Versioning](VERSIONING.md) describes release and website deployment.

Bug reports should include a minimal YAML document, the exact command, YAML.sh version, shell, AWK implementation, and operating system.
