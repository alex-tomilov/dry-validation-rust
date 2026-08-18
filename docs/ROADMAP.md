# Milestone Roadmap

Status: implementation plan.

This roadmap defines the intended milestone sequence for turning the current
feasibility prototype into a credible, publicly releasable compatibility slice
of `dry-validation`.

It is intentionally **not** a progress log. Current machine-readable milestone
and named-task state lives in [`compat/status.yml`](../compat/status.yml).
Detailed implemented/unsupported behavior lives in
[`COMPATIBILITY.md`](COMPATIBILITY.md), and runtime/platform support lives in
[`SUPPORT_MATRIX.md`](SUPPORT_MATRIX.md).

The order is deliberately conservative: each milestone should produce evidence
that de-risks the next one.

## Milestone sequence

| Milestone | Title                   | Outcome                                                                          | Depends on    |
| --------- | ----------------------- | -------------------------------------------------------------------------------- | ------------- |
| A         | Trustworthy Baseline    | Pinned compatibility evidence, explicit unsupported forms, source-gem smoke test | —             |
| B         | Common Schema Subset    | Dependable nested schema behavior for the documented subset                      | A             |
| C         | Ordinary Rules Subset   | Predictable supported rule execution and state isolation                         | B             |
| D         | Performance Proof       | Reproducible evidence for favourable, neutral, and unfavourable workloads        | C             |
| E         | Compatibility Slice     | One selected, upstream-evidenced migration blocker                               | C             |
| F         | Packaging and Platforms | Clean installation on a small verified support matrix                            | A, C          |
| G         | Stable Subset           | Narrow stable-release go/no-go decision based on prior evidence                  | D, E, F       |

Detailed acceptance criteria and implementation prompts are authoritative in
the numbered files under `docs/codex/`.

## Milestone A — Trustworthy Baseline

Goal: establish trustworthy evidence before expanding compatibility.

Exit evidence includes:

- upstream `dry-validation` pinned with lockfile discipline;
- differential behavior executed against isolated implementations;
- explicit unsupported constructs;
- a one-command verification gate;
- source-gem/package metadata verification;
- baseline CI/security/project infrastructure needed by later milestones.

## Milestone B — Common Schema Subset

Goal: provide a dependable schema path for the documented subset.

The subset covers the concrete schema behavior selected by the Milestone B
specification, with Rust used where behavior can be reproduced safely and Ruby
retaining semantics that should stay Ruby-owned.

## Milestone C — Ordinary Rules Subset

Goal: make ordinary rules (`rule` blocks, `key?`, `value()`, simple
dependencies, and the explicitly selected rule corpus) behave compatibly for
the common schema subset.

Do not expand this milestone into every `dry-validation` rule feature. The
Milestone C file defines the concrete rule corpus, code-quality work, stress
coverage, and exit gate.

## Milestone D — Performance Proof

Goal: produce honest, reproducible benchmark evidence after correctness is
established.

Performance evidence should include favourable, neutral, and unfavourable
workloads; preserve semantic equivalence; and separate Ruby orchestration,
native execution, allocation, and setup effects where relevant.

Do not treat a host-local or synthetic result as a general speed guarantee.

## Milestone E — Compatibility Slice

Goal: define and implement a named migration-driven compatibility slice with
explicit supported and unsupported behavior.

Compatibility claims require pinned, separate-process differential evidence.
The detailed current feature boundary remains authoritative in
[`COMPATIBILITY.md`](COMPATIBILITY.md).

## Milestone F — Packaging and Platforms

Goal: make installation and CI trustworthy across a small explicitly verified
support matrix.

This includes source/native packaging work, supported Ruby/Rust/platform
targets, and release plumbing needed for the chosen compatibility slice.
Platform claims remain authoritative in
[`SUPPORT_MATRIX.md`](SUPPORT_MATRIX.md).

## Milestone G — Stable Subset

Goal: prepare a narrow stable supported subset and make a release go/no-go
decision from the evidence produced by Milestones D, E, and F.

A stable release must not broaden compatibility, platform, or performance
claims beyond executable evidence.

## Dependency order

```text
A -> B -> C
          |\
          | +----> E --\
          +-----> D ----> G
          |
          +-----> F ----/
```

- B depends on A because schema behavior must be measured against a pinned
  upstream baseline.
- C depends on B because rules are only meaningful once schema behavior is
  stable.
- D depends on C because performance claims should be made for the intended
  feature subset, not a partial prototype.
- E depends on C because migration compatibility should build on established
  schema/rule behavior.
- F depends on A and C because packaging must preserve the proven baseline and
  current supported behavior.
- G depends on D, E, and F because a stable release needs performance,
  compatibility, and installation evidence.

## What this roadmap deliberately does not do

- It does not act as an activity log.
- It does not duplicate the detailed compatibility matrix.
- It does not duplicate platform/runtime support.
- It does not track test/file/document counts.
- It does not promise full `dry-validation` compatibility.
- It does not promise speedup before representative evidence exists.
- It does not expand scope to unrelated ecosystem features before the selected
  subset is proven.

When a task reveals new work, keep it in the task/PR context until it is
intentionally accepted into a milestone. Do not automatically expand this
roadmap with every discovered follow-up.
