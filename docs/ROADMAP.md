# Roadmap

This roadmap tracks outcomes, not a checklist of files or tools. Each stage may
contain several dependency-ordered pull requests, but only one coherent slice is
implemented at a time. Completion requires executable evidence; documentation
or coverage percentages alone do not close a stage.

## 0.1 prerelease: safe core

1. [`T01`](codex/stages/technical/T01-modularize-without-changing-behavior.md) —
   modularize without changing behavior.
2. [`T02`](codex/stages/technical/T02-harden-plans-and-ruby-rust-boundaries.md) —
   enforce immutable plans, strict unsupported-state handling, numeric fidelity,
   exception propagation, and FFI safety.
3. [`T03`](codex/stages/technical/T03-align-the-supported-compatibility-slice.md) —
   prove the deliberately supported DSL and result semantics against pinned
   upstream releases.
4. [`T04`](codex/stages/technical/T04-add-risk-based-robustness-evidence.md) —
   add malformed-input, property, fuzz, GC, concurrency, and load evidence where
   risk justifies it.
5. [`R01`](codex/stages/repository/R01-streamline-ci-and-developer-workflow.md) —
   keep one canonical verification path and proportionate CI.
6. [`R02`](codex/stages/repository/R02-keep-public-documentation-canonical.md) —
   keep identity, support, compatibility, architecture, and usage claims concise.
7. [`R03`](codex/stages/repository/R03-prove-package-and-release-readiness.md) —
   prove source packaging and protected release readiness.
8. [`G00`](codex/stages/release-gates/G00-audit-prerelease-readiness.md) — audit
   the prerelease gate and close one remaining blocker at a time.

## 0.2–0.3: evidence and adoption

1. [`T05`](codex/stages/technical/T05-measure-before-optimizing.md) — build
   representative evidence and optimize only profiled bottlenecks.
2. [`R04`](codex/stages/repository/R04-add-evidence-backed-adoption-paths.md) —
   maintain executable standalone/framework adoption paths without overstating
   compatibility.
3. [`G01`](codex/stages/release-gates/G01-audit-evidence-and-adoption-readiness.md)
   — audit whether compatibility, artifacts, performance, and support evidence
   justify broader adoption.

## Future experiment

[`T06`](codex/stages/technical/T06-evaluate-batch-and-streaming-apis.md) evaluates
a separate Rust-owned batch/streaming boundary. The normal engine uses Ruby
objects and stays under the GVL. This experiment does not block the core roadmap.

## Deliberately not used as milestones

- arbitrary line-coverage percentages;
- exhaustive YARD tags or a documentation site;
- a “full predicate set” count;
- CI benchmark gates on shared runners;
- badges, example directories, devcontainers, or generators without a proven
  maintainer/user need;
- publishing, tagging, releases, outreach, or repository-setting changes without
  an explicit authorized request.
