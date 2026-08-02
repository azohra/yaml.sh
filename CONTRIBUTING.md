# Contributing

Thanks for improving YAML.sh. Keep changes compatible with Bash 3.2 and common AWK implementations on Linux and macOS; the standalone executable must not require a third-party runtime.

## Development workflow

1. Add or update a test in `test/test.sh`. Parser fixtures belong in `test/`.
2. Edit the readable sources in `src/`. Do not edit the generated `ysh` executable by hand.
3. Run `make all` to rebuild, lint, and test the project.
4. Update the documentation and changelog for user-visible changes.

Bug reports should include a minimal YAML document, the exact command, YAML.sh version, Bash version, AWK implementation, and operating system.
