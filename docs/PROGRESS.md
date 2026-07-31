# Project Progress

Status: living document.
Last updated: 2026-07-31.

One-page project status for contributors, reviewers, and the maintainer.

## Milestone Status

| #   | Milestone               | Status         | Notes                                 |
| --- | ----------------------- | -------------- | ------------------------------------- |
| A   | Trustworthy Baseline    | ✅ Complete    | PRs #48–#51                           |
| B   | Common Schema Subset    | ✅ Complete    | PRs #49–#56, #65–#71                  |
| C   | Ordinary Rules Subset   | 🔵 Active      | ~20% done; code-quality tasks pending; hot-helper inline hints applied 2026-07-31 |
| D   | Performance Proof       | ⚪ Not started | Blocked on C                          |
| E   | Compatibility Slice     | ⚪ Not started | Blocked on D                          |
| F   | Packaging and Platforms | ⚪ Not started | Blocked on E                          |
| G   | Stable Subset           | ⚪ Not started | Blocked on F                          |

## What Has Been Accomplished

### Milestone A (Complete)

- Upstream `dry-validation` pinned at 1.11.1.
- Differential harness with 80+ schema cases and 6 unsupported-construct cases.
- Isolated-subprocess execution with timeout and memory guards.
- `script/verify` one-command gate.
- Package metadata audit.
- 5 CI workflows, Dependabot, issue/PR templates.

### Milestone B (Complete)

- Nine schema slices delivered (required/optional keys, types, nesting,
  predicates, coercion, composition, messages, result API, unsupported constructs).
- Rust engine split into 6 modules (plan, engine, coercion, predicates, error, ruby_bridge).
- Typed `PredicateArg` enum.
- Recursion depth guard (default 128).
- 28 Rust unit tests.
- 64-input malformed-input resilience corpus.
- `cargo test` and `cargo clippy` in CI.

## What Is Next (Milestone C)

1. Build a dedicated 50-case rule corpus (see Milestone C file for distribution).
2. Complete C-Q1 through C-Q4 code-quality tasks.
3. Stress-test rule dependencies and isolation.
4. Wire rule corpus into differential CI.

## Code-Quality Tasks (from Milestone C)

| ID   | Task                                     | Status     |
| ---- | ---------------------------------------- | ---------- |
| C-Q1 | Unify predicate evaluation (3 sites → 1) | ⚪ Pending |
| C-Q2 | Unify `Undefined` sentinels              | ⚪ Pending |
| C-Q3 | Fix `MessageSet#freeze` no-op            | ⚪ Pending |
| C-Q4 | Split `schema.rb` (480 lines → 4 files)  | ⚪ Pending |

## Key Metrics

| Metric                     | Value                  |
| -------------------------- | ---------------------- |
| Ruby source files          | ~15                    |
| Rust source files          | 7 (lib.rs + 6 modules) |
| Ruby test files            | ~12                    |
| Rust unit tests            | 28                     |
| Differential fixture cases | 80+                    |
| Malformed-input corpus     | 64                     |
| CI workflows               | 5                      |
| Documentation files        | 12+                    |

## Known Debt and Risks

- No published benchmark results (Milestone D).
- No precompiled platform gems (Milestone F).
- No RBS type signatures (Milestone F).
- Governance documentation may be disproportionate to project scale.
- Naming/affiliation with dry-rb not yet discussed (Milestone G).
- `edition = "2024"` / `rust-version = "1.85"` may exclude contributors.

## File Manifest

This progress update was generated on 2026-07-29 and includes updates to:

- `docs/ROADMAP.md`
- `docs/VERIFICATION.md`
- `docs/PROGRESS.md` (this file)
- `docs/codex/01_MILESTONE_A_TRUSTWORTHY_BASELINE.md`
- `docs/codex/02_MILESTONE_B_COMMON_SCHEMA.md`
- `docs/codex/03_MILESTONE_C_ORDINARY_RULES.md`
- `docs/codex/04_MILESTONE_D_PERFORMANCE_PROOF.md`
- `docs/codex/05_MILESTONE_E_COMPATIBILITY_SLICE.md`
- `docs/codex/06_MILESTONE_F_PACKAGING_AND_PLATFORMS.md`
- `docs/codex/07_MILESTONE_G_STABLE_SUBSET.md`
