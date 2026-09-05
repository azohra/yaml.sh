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
4. Update the documentation and changelog for user-visible changes.

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

CI's `Check` job combines the selected runtime, documentation, and portability
results. It rejects failed classification and missing or unsuccessful selected
jobs, while accepting intentional skips. Use this stable result for branch
protection: the runtime matrix emits different check names when skipped.

`mise run push` checks and publishes a clean feature branch for PR review.

## Generated files

`make ysh` and `make docs` own these paths; edit their sources instead:

| Generated | Source |
| --- | --- |
| `ysh` | `src/ysh.sh`, `src/awk/*.awk`, and `src/diff.awk`, assembled by `build/shbuilder.awk` |
| `_static/_www/docs/*/index.html`, `_static/_www/docs/index.html`, `_static/_www/docs/search-index.json` | `_static/_www/docs/*.md`, rendered by `build/docs.sh` |
| Version spans inside `README.md` and `_static/_www/index.html` | Rewritten by `build/docbuilder.awk` during `make docs` |
| Release URL and checksum inside `_static/_www/install` | Preserved by ordinary docs builds; rewritten together from the release artifact with `make docs RELEASE_SHA256=...` |

Ordinary source changes must not rewrite the checksum for the immutable release
asset named by the installer. `testReleaseArtifactsStayInSync` pins that released
version and digest until the next release updates both together.

Release numbers follow [Semantic Versioning](VERSIONING.md). Compatible additions belong in a minor release, compatible fixes in a patch release, and a new major requires an intentional, documented compatibility break.

Bug reports should include a minimal YAML document, the exact command, YAML.sh version, shell, AWK implementation, and operating system.
