# Roadmap

This roadmap tracks the outcome-oriented milestones specified in
[`docs/codex`](codex/). A milestone can contain several small, dependency-aware
changes; completion requires the executable evidence in its own exit gate.

1. [**Milestone A — Establish the trustworthy baseline**](codex/01_MILESTONE_A_TRUSTWORTHY_BASELINE.md)
   — pin the compatibility target, prove the existing subset differentially,
   make unsupported constructs explicit, and verify source-gem installation.
2. [**Milestone B — Dependable common schema path**](codex/02_MILESTONE_B_COMMON_SCHEMA.md)
   — make the documented common `params`, `json`, and plain-schema path
   dependable for realistic nested payloads.
3. [**Milestone C — Dependable ordinary contract rules**](codex/03_MILESTONE_C_ORDINARY_RULES.md)
   — make supported Ruby rules predictable, isolated, and compatible after
   structural validation.
4. [**Milestone D — Prove or disprove the performance case**](codex/04_MILESTONE_D_PERFORMANCE_PROOF.md)
   — measure favourable, neutral, and unfavourable workloads before choosing
   any optimization work.
5. [**Milestone E — Implement one migration-driven compatibility slice**](codex/05_MILESTONE_E_COMPATIBILITY_SLICE.md)
   — use the reusable template to deliver one evidenced compatibility feature
   at a time; it is not a bulk-parity milestone.
6. [**Milestone F — Package and platform hardening**](codex/06_MILESTONE_F_PACKAGING_AND_PLATFORMS.md)
   — prove clean source-gem installation and a deliberately small verified
   Ruby/platform matrix.
7. [**Milestone G — Stable supported subset**](codex/07_MILESTONE_G_STABLE_SUBSET.md)
   — make a narrow 1.0 go/no-go decision based on compatibility, packaging,
   platform, migration, and performance evidence.

## Dependency order

`A → B → C` establishes the supported behavior. `D` measures that behavior,
`E` adds one selected migration blocker at a time, and `F` hardens delivery.
`G` is the release-readiness gate and depends on the relevant evidence from all
earlier milestones. Milestone D, E, and F can be worked on after their stated
prerequisites; they do not authorize broad support or release claims.

## Deliberately not used as milestones

- arbitrary line-coverage percentages;
- exhaustive YARD tags or a documentation site;
- a “full predicate set” count;
- CI benchmark gates on shared runners;
- badges, example directories, devcontainers, or generators without a proven
  maintainer/user need;
- publishing, tagging, releases, outreach, or repository-setting changes without
  an explicit authorized request.
