# Project Progress

Status: living document.
Last updated: 2026-08-03.

One-page project status for contributors, reviewers, and the maintainer.

## Milestone Status

| #   | Milestone               | Status         | Notes                                 |
| --- | ----------------------- | -------------- | ------------------------------------- |
| 0   | Foundation              | 🔵 Active      | Step 0.1 public side-by-side API lock completed 2026-08-04; SemVer and security policy work remains |
| A   | Trustworthy Baseline    | ✅ Complete    | PRs #48–#51                           |
| B   | Common Schema Subset    | ✅ Complete    | PRs #49–#56, #65–#71                  |
| C   | Ordinary Rules Subset   | 🔵 Active      | ~20% done; C-Q3 completed; hot-helper inline hints, cached rule/macro keyword introspection, and `MessageSet#to_h` memoization applied 2026-08-01 |
| D   | Performance Proof       | 🔵 Active      | Phase 1 steps 1–2 completed 2026-08-03; remaining work blocked on C |
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
- 18 Rust unit tests, including native coercion boundary cases.
- 64-input malformed-input resilience corpus.
- `cargo test` and `cargo clippy` in CI.

## What Is Next

1. Complete Foundation Step 0.2 (SemVer policy) and Step 0.3 (actionable security process).
2. Build a dedicated 50-case rule corpus (see Milestone C file for distribution).
3. Complete remaining C-Q1, C-Q2, and C-Q4 code-quality tasks.
4. Stress-test rule dependencies and isolation, then wire the rule corpus into differential CI.
5. After Milestone C, complete the remaining Performance Proof steps; Phase 1 path-vector reuse and Ruby class caching are complete.

## Code-Quality Tasks (from Milestone C)

| ID   | Task                                     | Status     |
| ---- | ---------------------------------------- | ---------- |
| C-Q1 | Unify predicate evaluation (3 sites → 1) | ⚪ Pending |
| C-Q2 | Unify `Undefined` sentinels              | ⚪ Pending |
| C-Q3 | Fix `MessageSet#freeze` no-op            | ✅ Done    |
| C-Q4 | Split `schema.rb` (480 lines → 4 files)  | ⚪ Pending |

## Key Metrics

| Metric                     | Value                  |
| -------------------------- | ---------------------- |
| Ruby source files          | ~16                    |
| Rust source files          | 7 (lib.rs + 6 modules) |
| Ruby test files            | ~12                    |
| Rust unit tests            | 18                     |
| Differential fixture cases | 80+                    |
| Malformed-input corpus     | 64                     |
| CI workflows               | 5                      |
| Documentation files        | 12+                    |

## Known Debt and Risks

- No published benchmark results (Milestone D).
- A SemVer policy for native compatibility changes is still pending (Foundation Step 0.2).
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
