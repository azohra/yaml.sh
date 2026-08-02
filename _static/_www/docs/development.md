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
test/advanced.yml       v1 conformance fixture
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

## Portability

Hosted CI runs the suite with the platform AWK on Ubuntu and macOS, then repeats it with BusyBox AWK on Linux. The generated executable is parsed and executed by `/bin/sh`.

Avoid implementation-specific AWK extensions unless the portability contract changes deliberately.
