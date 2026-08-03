# YAML.sh design

## Product

YAML.sh is a useful YAML programming tool built under a joyful constraint: one
readable POSIX shell file, powered by portable AWK. It queries, transforms,
validates, converts, inspects, and source-edits YAML without acquiring another
language runtime.

The released `ysh` remains one text executable. Its implementation is POSIX
`/bin/sh` and portable AWK; repository edits may use the ordinary host file
utilities documented in the runtime contract.

The premise is the product, not a deployment scenario. YAML.sh is useful when
any of these matter:

- the target already has a shell and AWK but should not acquire another runtime;
- a YAML change must retain comments, style, ordering, and unrelated bytes;
- several files must be evaluated from stable snapshots and changed as one
  preflighted, rollback-capable operation;
- configuration behavior needs inspectable limits and a small execution model;
- the executable itself should remain readable, copyable source.

Familiar yq-shaped syntax lowers the cost of learning the language. It is an
interface influence and a differential oracle, not the product identity.

## Invariants

1. **One shipped file.** Development sources may be modular; `ysh` is the
   complete release artifact.
2. **Portable implementation.** The query engine stays within POSIX shell and
   the AWK implementations in CI. A broader runtime requires a major release.
3. **Structure before text.** Parsing produces a node graph. Queries, schemas,
   patches, codecs, and emitters share that representation.
4. **Source is a first-class output.** YAML edits compile against owned source
   spans. `--preserve-only` turns preservation into a checked precondition.
5. **Preview equals candidate.** Check, diff, and write consume one prepared
   plan. Repository writes detect drift and retain rollback material.
6. **Unsupported input fails closed.** A nearby form must not be accepted with
   plausible but incorrect semantics.
7. **No hidden execution.** Expressions do not spawn commands, open network
   connections, load plugins, or construct application objects from tags.
   Environment, local-file, and dynamic-expression access stays explicit and
   separately controllable.
8. **Claims have exact evidence.** Counts are supporting measurements, never
   substitutes for named behavior and expected outcomes.
9. **Compatibility describes versions.** Effort, speed, and ambition do not
   select a major version. Only a necessary break in the documented contract
   does.
10. **Fun sharpens the constraint.** Novelty is welcome; accidental complexity,
    filler, and parity for its own sake are not.

## Decision filter

A capability belongs when it materially improves portable configuration work
and composes with the graph, source compiler, or transaction model. Prefer a
small general primitive over a collection of workflow-specific flags.

Before adding or retaining a capability, ask:

1. What concrete job becomes possible or safer?
2. Does the graph provide a simpler implementation than a separate subsystem?
3. Can the behavior be bounded, explained, and tested across supported AWKs?
4. Does it strengthen YAML.sh's product, or merely reduce a comparison-table gap?
5. Is its ongoing documentation, security, performance, and compatibility cost
   proportionate to its value?

Supported features are not removed merely because they are unfashionable or
infrequently used. Deprecation requires a named product or safety improvement,
compatibility evidence, and a migration path.

## Architecture

Development source is organized by responsibility and assembled in dependency
order:

```text
shell CLI + transaction coordinator
              ↓
AWK limits, diagnostics, codecs, YAML parser, graph
              ↓
query lexer/parser/evaluator + contracts
              ↓
semantic emitters + source edit compiler
              ↓
value output / exact candidate / repository transaction
```

The graph is the internal boundary. Parsers create nodes; programs transform
node streams; contracts inspect or mutate nodes; emitters serialize nodes; the
source compiler compares the final graph with recorded YAML ownership.

Subsystems may use AWK's shared arrays, but new code should go through named
graph and stream operations instead of adding unrelated direct mutations.
Large dispatchers should delegate coherent operator families while preserving
one evaluation model and measured performance.

## Runtime contract

Read-only queries require:

- a POSIX-compatible `/bin/sh`;
- a supported AWK;
- the shell's standard built-ins.

Source-aware check, diff, and write additionally use commonly available host
utilities: `mktemp`, `cp`, `cmp`, `mv`, `rm`, and `wc`. `mktemp` is widespread
but not specified by POSIX; CI owns the supported host behavior. Installation
has a separate network and checksum contract.

These dependencies are not additional language runtimes or libraries. They are
still dependencies and must be documented and tested honestly.

## Trust model

Documents are data. Queries are programs.

Resource ceilings reduce accidental and hostile resource use; they do not make
AWK a hardened sandbox. A caller handling untrusted documents should set limits
appropriate to the host. A caller handling untrusted queries must also disable
environment, local-file, and dynamic-expression capabilities or avoid running
the query entirely.

Security documentation must distinguish:

- parsing an untrusted document with a trusted fixed query;
- executing an untrusted query;
- writing files selected by a trusted CLI invocation;
- using YAML.sh itself as a security or certification boundary.

## Evidence

Every public capability maps to an exact fixture, assertion, property, or
external oracle outcome. Generated variation may strengthen a behavior but does
not create a new capability count.

Evidence has four tiers:

1. fast behavioral and documentation checks on relevant changes;
2. cross-shell and cross-AWK portability;
3. conformance, differential, preservation, fault, adversarial, and scale gates;
4. release-candidate reproduction of the complete public contract.

Performance gates describe useful workloads and budgets. They are not vanity
comparisons and must record latency and memory without calling a loose ceiling
an optimization.

## Documentation and voice

Start with the job, then explain the mechanism and boundary. Prefer one accurate
example to a capability count. Be terse, direct, and occasionally funny; never
use jokes as filler or repeat exclusions to manufacture humility.

The README is the shortest complete introduction. The website establishes the
identity and first useful action. Documentation is task and reference material.
The story explains why the design exists; it is not a second changelog and does
not advance with every release.

## Releases

Compatible repairs, refactors, stricter handling outside the supported grammar,
and additive capabilities remain minor releases. A major release requires a
named incompatibility in documented CLI, query, output, YAML interpretation, or
runtime behavior; compatibility fixtures; migration documentation; and a
release candidate.

A release is complete only when source, generated artifact, installer, docs,
checksums, signed tag, GitHub release, and package metadata agree.
