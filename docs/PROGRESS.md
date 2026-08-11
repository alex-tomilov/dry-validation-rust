# Project Progress

Status: living document.
Last updated: 2026-08-11.

One-page project status for contributors, reviewers, and the maintainer.

## Milestone Status

| #   | Milestone               | Status         | Notes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| --- | ----------------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 0   | Foundation              | ✅ Complete    | Steps 0.1 public side-by-side API lock, 0.2 SemVer policy, and 0.3 actionable security process completed 2026-08-04                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| A   | Trustworthy Baseline    | ✅ Complete    | PRs #48–#51                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| B   | Common Schema Subset    | ✅ Complete    | PRs #49–#56, #65–#71                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| C   | Ordinary Rules Subset   | 🔵 Active      | ~20% done; C-Q3 and C-Q4 completed; schema collaborators are one class per file and schema-owned types use only the `Schema` namespace as of 2026-08-11                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| D   | Performance Proof       | 🔵 Active      | Phase 1 steps 1–2 and maturity-roadmap Steps 3.1–3.5 completed 2026-08-09; canonical 64-bit integers and finite decimal float parameters now coerce in Rust, while non-canonical spellings and Bignums retain Ruby behavior and explicit non-finite literals remain rejected. README records three-run results for all six scenarios, CI rejects Ruby-allocation regressions above 5% of `main`, weekly CI runs five minutes of plan-deserialization fuzzing, and the Ruby suite exercises a seeded hostile-hash corpus in an isolated subprocess; broader-host and native-allocation evidence remain pending |
| E   | Compatibility Slice     | 🔵 Active      | `config.validate_keys = true`, predicate-composition blocks, Ruby-owned custom dry-types/constructor and sum objects, YAML/I18n schema-message backends, and Ruby-side `before`/`after` processor hooks implemented for all schema modes by 2026-08-08                                                                                                                                                                                                                                                                                                                                                        |
| F   | Packaging and Platforms | 🔵 Active      | Cross-compilation for four P0 platforms, a signed trusted-publishing release workflow, and README source/precompiled installation guidance added 2026-08-06; publication remains blocked on E                                                                                                                                                                                                                                                                                                                                                                                                                 |
| G   | Stable Subset           | ⚪ Not started | Blocked on F                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |

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
2. Complete remaining C-Q1 and C-Q2 code-quality tasks.
3. Stress-test rule dependencies and isolation, then wire the rule corpus into differential CI.
4. Automate the benchmark matrix and complete the remaining Performance Proof work after Milestone C; Phase 1 path-vector reuse, Ruby class caching, and Steps 3.1–3.5 (benchmark matrix, allocation gate, plan deserialization/Ruby-level engine fuzzing, and profiled GVL-path optimizations) are complete.
5. Configure the RubyGems trusted publisher for `rubygems-push.yml`, then validate and publish the P0 precompiled gems so the documented recommended path becomes available.

## Code-Quality Tasks (from Milestone C)

| ID   | Task                                     | Status     |
| ---- | ---------------------------------------- | ---------- |
| C-Q1 | Unify predicate evaluation (3 sites → 1) | ⚪ Pending |
| C-Q2 | Unify `Undefined` sentinels              | ⚪ Pending |
| C-Q3 | Fix `MessageSet#freeze` no-op            | ✅ Done    |
| C-Q4 | Split `schema.rb` (480 lines → 4 files)  | ✅ Done    |

## Key Metrics

| Metric                     | Value                                  |
| -------------------------- | -------------------------------------- |
| Ruby source files          | 29                                     |
| Rust source files          | 7 (lib.rs + 6 modules) + 1 fuzz target |
| Ruby test files            | ~14                                    |
| Rust unit tests            | 21                                     |
| Differential fixture cases | 80+                                    |
| Malformed-input corpus     | 64                                     |
| CI workflows               | 8                                      |
| Documentation files        | 12+                                    |

## Known Debt and Risks

- Benchmark matrix results are limited to one x86_64 Linux host and three runs per scenario; no benchmark-matrix automation, cross-host evidence, or native-allocation measurement yet (Milestone D). Ruby allocation regressions and baseline recording are limited to Ubuntu Ruby 3.3.
- P0 precompiled-gem builds and signed publication workflow are configured but not yet validated in CI or published; RubyGems trusted-publisher setup is still required (Milestone F).
- No RBS type signatures (Milestone F).
- Predicate-composition blocks support sequential predicate calls only; boolean dry-logic AST composition remains unsupported.
- Custom dry-types are Ruby-owned direct `value(type)` fields; custom array-member types and dry-schema's type-specific failure messages remain unsupported.
- I18n schema messages require applications to include the optional `i18n` gem.
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
