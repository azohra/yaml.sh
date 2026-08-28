# Development

## Build everything

```sh
make all
```

The default workflow rebuilds `ysh`, validates shell scripts with ShellCheck, runs the shUnit2 suite, audits the workflow, parser-boundary, and public-contract gates, and verifies that the committed static documentation is generated and internally linked correctly.

## Source layout

```text
src/ysh.sh     POSIX shell CLI and batch edit coordinator
src/awk/       ordered engine modules: core primitives, codecs, YAML source
               and parser and graph, query parser, contracts, query runtime
               and evaluators, emitters, source-edit compiler, output, main
src/diff.awk   bounded unified-diff renderer
build/         shbuilder.awk assembles ysh; docs.sh, docs-page.awk,
               docs-search.awk, and docbuilder.awk generate the site
test/          test.sh behavioral suite on a vendored shunit2 (2.1.8pre
               snapshot of kward/shunit2); focused gate scripts with their
               TSV corpora; YAML fixtures; workflow fixtures under
               workflows/; fault-injection PATH shims under fault-bin/;
               toml-test adapters
bench/         benchmark.sh throughput sample; scale.sh resource contract
_static/_www/  unified Cloudflare Pages site; docs/*.md are the editable
               documentation sources, and install is the installer
```

Each gate script reads its sibling TSV corpus: tab-separated columns, blank
lines and `#` comments skipped, rows grouped under a leading family or
capability label. Add a row beside its family, rerun the owning gate, and
update `test/public-contract.tsv` when the supported surface changes; the
gates assert their own corpus floors and status vocabularies.

## Build documentation

```sh
make docs
```

Markdown remains the readable source under `_static/_www/docs`. Portable shell and AWK generate committed HTML at real paths such as `/docs/queries/`; no client-side framework renders the pages. The small optional script provides local search, copy buttons, and keyboard shortcuts. Run `make docs-check` to detect stale output, broken local links, anchor regressions, remote framework assets, or release-specific artwork. The same target runs `test/guidance.sh`, which verifies that the build targets, repository paths, local links, version literals, and provenance claims named in the guidance documents still match the repository.

## Add parser behavior

For every supported feature:

1. Add a focused fixture or inline YAML sample.
2. Test the selected value or structure.
3. Test metadata when tags, types, or source lines matter.
4. Add an explicit rejection test if a neighboring syntax remains unsupported.
5. Update the YAML support reference.

The objective is not a vague percentage of YAML. It is an expanding set of behaviors users can rely on.

Run `make operator-manifest` and `make parser-boundaries` before expanding the public contract. `make conformance` uses the pinned YAML Test Suite; `make differential` uses yq v4.53.3 and jq; `make toml-conformance`, `make schema-conformance`, and `make json-patch-conformance` use their pinned upstream suites. `make fuzz`, `make presentation`, `make adversarial`, and `make scale` cover replayable grammar properties, exact source retention, hostile shapes, and bounded scale.

## Add expression behavior

Expression operators must preserve node references unless they intentionally compute a new value. Add tests for precedence, empty streams, null traversal, scalar and collection inputs, multi-result output, and parity with the equivalent yq expression where one exists.

## Portability

Hosted CI covers macOS AWK on Arm and Intel, mawk on two Ubuntu releases, original AWK, POSIX-mode gawk, and BusyBox AWK. Shell smoke tests use dash, BusyBox sh, bash POSIX mode, and the platform `/bin/sh`. That portability matrix runs on pull requests and main updates that touch the runtime; the longer evidence workflow runs on demand before a release and weekly to catch upstream changes.

Run the Linux-only portion on any Docker host:

```sh
mise run check:linux-portability
```

The Ubuntu 24.04 container covers BusyBox AWK, POSIX-mode gawk, original AWK,
dash, bash POSIX mode, and BusyBox sh. The native CI matrix remains the proof
for macOS on Arm and Intel.

Avoid implementation-specific AWK extensions unless the portability contract changes deliberately. House idioms keep the modules portable: declare function locals as extra parameters after the real arguments; pass arrays through parameters, which are per-call and by-reference; write awkward quotes as `sprintf("%c", 39)`; avoid gawk-only builtins such as `gensub` and `asort`. Module text must never contain the build heredoc terminators `YSH_AWK_EOF` or `YSH_DIFF_AWK_EOF`.

One recorded shell gotcha: in `VAR1=... VAR2=$(cmd) program`, many shells apply the assignments left to right, so a leading `PATH=` prefix changes how a later `$(command -v ...)` resolves. Resolve real tool paths into variables before building such command lines, as the `test/fault-bin/` shims require.
