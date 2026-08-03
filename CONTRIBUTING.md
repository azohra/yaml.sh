# Contributing

Thanks for improving YAML.sh. Keep changes compatible with POSIX `/bin/sh` and the AWK implementations covered by CI; the standalone executable must not require a third-party runtime.

Read [the design](DESIGN.md) first. It defines the product premise, invariants, architecture, evidence standard, and compatibility rules used to evaluate changes.

## Development workflow

1. Add or update a test in `test/test.sh`. Parser fixtures belong in `test/`.
2. Edit the readable sources in `src/`. Do not edit the generated `ysh` executable by hand.
3. Run `make all` to rebuild, lint, and test the project. Parser and evaluator changes should also run `make fuzz`, `make presentation`, `make scale`, and the pinned conformance/differential gates. Update `test/public-contract.tsv` when the supported surface or its product role changes.
4. Update the documentation and changelog for user-visible changes.

Release numbers follow [Semantic Versioning](VERSIONING.md). Compatible additions belong in a minor release, compatible fixes in a patch release, and a new major requires an intentional, documented compatibility break.

Bug reports should include a minimal YAML document, the exact command, YAML.sh version, shell, AWK implementation, and operating system.
