@AGENTS.md

Operational quick facts:

- `ysh` and the docs HTML are generated; the generated-file map is in
  CONTRIBUTING.md. Edit sources under `src/` and `_static/_www/docs/*.md`,
  then rebuild with `make ysh` / `make docs`.
- After changing `src/`, `testReleaseArtifactsStayInSync` fails until
  `make docs` refreshes the installer checksum. Expected while developing.
- Pick focused gates from the table in CONTRIBUTING.md; release touchpoints
  are listed in VERSIONING.md.
