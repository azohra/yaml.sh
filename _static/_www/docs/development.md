# Development

## Build everything

```sh
make all
```

The default workflow rebuilds `ysh`, validates the shell with ShellCheck, and runs the shUnit2 suite.

## Source layout

```text
src/ysh.sh              POSIX shell CLI
src/ysh.awk             YAML engine
test/test.sh            behavioral suite
test/conformance.sh     pinned YAML Test Suite gate
test/differential.sh    pinned yq comparison gate
test/fuzz.sh            deterministic generated properties
test/adversarial.sh     resource and recursion guards
bench/benchmark.sh      repeatable throughput sample
test/advanced.yml       v1 conformance fixture
test/expressions.yml    v1 expression and transformation fixture
_static/_www            unified Cloudflare Pages site
_static/_www/docs       documentation
_static/_www/install    installer
```

## Add parser behavior

For every supported feature:

1. Add a focused fixture or inline YAML sample.
2. Test the selected value or structure.
3. Test metadata when tags, types, or source lines matter.
4. Add an explicit rejection test if a neighboring syntax remains unsupported.
5. Update the support contract.

The objective is not a vague percentage of YAML. It is an expanding set of behaviors users can rely on.

Run `make conformance` with `YAML_TEST_SUITE_DIR` set to the pinned data checkout. Run `make differential` with yq v4.53.3 and jq available. `make fuzz`, `make adversarial`, and `make benchmark` cover generated structure, hostile shapes, and throughput.

## Add expression behavior

Expression operators must preserve node references unless they intentionally compute a new value. Add tests for precedence, empty streams, null traversal, scalar and collection inputs, multi-result output, and parity with the equivalent yq expression where one exists.

## Portability

Hosted CI covers macOS AWK on Arm and Intel, mawk on two Ubuntu releases, original AWK, POSIX-mode gawk, and BusyBox AWK. Shell smoke tests use dash, BusyBox sh, bash POSIX mode, and the platform `/bin/sh`.

Avoid implementation-specific AWK extensions unless the portability contract changes deliberately.
