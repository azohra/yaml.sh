# Working on YAML.sh

Read [DESIGN.md](DESIGN.md) before changing behavior. It is the canonical
product and architecture guidance for every contributor.

## Non-negotiable constraints

- Keep the released `ysh` artifact to one readable text file.
- Keep runtime code compatible with POSIX `/bin/sh` and the AWK implementations
  covered by the portability tests.
- Edit readable sources; never edit generated `ysh` or generated docs directly.
- Preserve documented v1 behavior unless a necessary break is explicitly
  accepted and prepared as a major release candidate.
- Do not add yq parity for its own sake. Start from a concrete YAML job or a
  coherent language primitive.
- Treat queries as programs and YAML as data. Do not add system execution,
  networking, plugins, or application tag construction.
- Make unsupported neighboring syntax fail closed.
- Attach exact evidence to every public claim. Generated case counts are not
  capability counts.

## Change workflow

1. Identify the user job, public-contract impact, and subsystem owner.
2. Add or update the smallest exact behavioral test.
3. Change modular source under `src/` and rebuild the standalone artifact.
4. Run `make all`; use the focused conformance, differential, presentation,
   adversarial, and scale gates named in `CONTRIBUTING.md` when relevant.
5. Update the canonical documentation and changelog for visible behavior.
6. Check that claims remain consistent across README, docs, website, security
   policy, and story without duplicating whole explanations.

Refactors must preserve the generated artifact's behavior and compare before
and after performance on representative workloads. Complexity should move into
clear subsystem boundaries, not merely into more files.

## Documentation

Lead with useful work and guarantees. Keep prose terse, coherent, and specific.
YAML.sh should be the subject; mention yq only for familiar syntax, migration,
or measured compatibility. Let the strange, joyful constraint provide the fun;
let concrete behavior prove the tool is serious. The story is durable narrative,
not release state. Verification and release machinery belong in maintainer
material, not the product identity.
