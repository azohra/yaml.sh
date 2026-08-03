# Development

## Build everything

```sh
make all
```

The default workflow rebuilds `ysh`, validates shell scripts with ShellCheck, runs the shUnit2 suite, and verifies that the committed static documentation is generated and internally linked correctly.

## Source layout

```text
src/ysh.sh              POSIX shell CLI
src/ysh.awk             YAML engine
src/diff.awk            bounded unified-diff renderer
test/test.sh            behavioral suite
test/conformance.sh     pinned YAML Test Suite gate
test/differential.sh    pinned yq comparison gate
test/operator-manifest.sh audited operator/form contract
test/yq-corpus-base.tsv hand-written differential cases
test/generate-yq-corpus.sh reproducible categorized expansion
test/fuzz.sh            grammar-guided replayable properties
test/presentation-matrix.sh exact compound-edit matrix
test/parser-boundaries.sh deliberate accept/reject boundary matrix
test/adversarial.sh     resource and recursion guards
bench/benchmark.sh      repeatable throughput sample
bench/scale.sh          125,000-node resource contract
build/docs.sh           static documentation build
build/docs-page.awk     controlled Markdown-to-HTML renderer
test/docs.sh            generated page, link, anchor, and asset checks
test/advanced.yml       v1 conformance fixture
test/expressions.yml    v1 expression and transformation fixture
_static/_www            unified Cloudflare Pages site
_static/_www/docs       documentation
_static/_www/install    installer
```

## Build documentation

```sh
make docs
```

Markdown remains the readable source under `_static/_www/docs`. Portable shell and AWK generate committed HTML at real paths such as `/docs/queries/`; no client-side framework renders the pages. The small optional script provides local search, copy buttons, and keyboard shortcuts. Run `make docs-check` to detect stale output, broken local links, anchor regressions, remote framework assets, or release-specific artwork.

## Add parser behavior

For every supported feature:

1. Add a focused fixture or inline YAML sample.
2. Test the selected value or structure.
3. Test metadata when tags, types, or source lines matter.
4. Add an explicit rejection test if a neighboring syntax remains unsupported.
5. Update the YAML support reference.

The objective is not a vague percentage of YAML. It is an expanding set of behaviors users can rely on.

Run `make operator-manifest` and `make parser-boundaries` before expanding the public contract. `make conformance` uses the pinned YAML Test Suite; `make differential` uses yq v4.53.3 and jq. `make fuzz`, `make presentation`, `make adversarial`, and `make scale` cover replayable grammar properties, exact source retention, hostile shapes, and bounded scale.

## Add expression behavior

Expression operators must preserve node references unless they intentionally compute a new value. Add tests for precedence, empty streams, null traversal, scalar and collection inputs, multi-result output, and parity with the equivalent yq expression where one exists.

## Portability

Hosted CI covers macOS AWK on Arm and Intel, mawk on two Ubuntu releases, original AWK, POSIX-mode gawk, and BusyBox AWK. Shell smoke tests use dash, BusyBox sh, bash POSIX mode, and the platform `/bin/sh`. That portability matrix runs on every pull request and main update; the longer evidence workflow runs on demand before a release and weekly as drift detection.

Avoid implementation-specific AWK extensions unless the portability contract changes deliberately.
