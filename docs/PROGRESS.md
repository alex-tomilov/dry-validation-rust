# Project Progress

Status: living document.
Last updated: 2026-08-06.

One-page project status for contributors, reviewers, and the maintainer.

## Milestone Status

| #   | Milestone               | Status         | Notes                                 |
| --- | ----------------------- | -------------- | ------------------------------------- |
| 0   | Foundation              | ✅ Complete    | Steps 0.1 public side-by-side API lock, 0.2 SemVer policy, and 0.3 actionable security process completed 2026-08-04 |
| A   | Trustworthy Baseline    | ✅ Complete    | PRs #48–#51                           |
| B   | Common Schema Subset    | ✅ Complete    | PRs #49–#56, #65–#71                  |
| C   | Ordinary Rules Subset   | 🔵 Active      | ~20% done; C-Q3 completed; hot-helper inline hints, cached rule/macro keyword introspection, and `MessageSet#to_h` memoization applied 2026-08-01 |
| D   | Performance Proof       | 🔵 Active      | Phase 1 steps 1–2 completed 2026-08-03; remaining work blocked on C |
| E   | Compatibility Slice     | ⚪ Not started | Blocked on D                          |
| F   | Packaging and Platforms | 🔵 Active      | Cross-compilation for four P0 platforms and a signed, trusted-publishing release workflow added 2026-08-06; publication remains blocked on E |
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

1. Build a dedicated 50-case rule corpus (see Milestone C file for distribution).
2. Complete remaining C-Q1, C-Q2, and C-Q4 code-quality tasks.
3. Stress-test rule dependencies and isolation, then wire the rule corpus into differential CI.
4. After Milestone C, complete the remaining Performance Proof steps; Phase 1 path-vector reuse and Ruby class caching are complete.
5. Complete Milestone E, configure the RubyGems trusted publisher for `rubygems-push.yml`, then validate and publish the P0 precompiled gems.

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
| CI workflows               | 7                      |
| Documentation files        | 12+                    |

## Known Debt and Risks

- No published benchmark results (Milestone D).
- P0 precompiled-gem builds and signed publication workflow are configured but not yet validated in CI or published; RubyGems trusted-publisher setup is still required (Milestone F).
- No RBS type signatures (Milestone F).
- Security advisories depend on GitHub private vulnerability reporting remaining enabled.
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
