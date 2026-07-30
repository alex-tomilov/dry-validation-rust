# Milestone Roadmap

Status: draft for implementation planning.
Last updated: 2026-07-29.

This roadmap defines the milestone sequence for turning the current feasibility
prototype into a credible, publicly releasable compatibility slice of
`dry-validation`.

The order is deliberately conservative: each milestone produces evidence that
de-risks the next one.

## Milestone Status Overview

| Milestone | Title                   | Status         | Completed  |
| --------- | ----------------------- | -------------- | ---------- |
| A         | Trustworthy Baseline    | ✅ Complete    | 2026-07-24 |
| B         | Common Schema Subset    | ✅ Complete    | 2026-07-29 |
| C         | Ordinary Rules Subset   | 🔵 Active      | —          |
| D         | Performance Proof       | ⚪ Not started | —          |
| E         | Compatibility Slice     | ⚪ Not started | —          |
| F         | Packaging and Platforms | ⚪ Not started | —          |
| G         | Stable Subset           | ⚪ Not started | —          |

## Milestone A — Trustworthy Baseline

Status: ✅ Complete (2026-07-24).

Completed via PRs #48–#51. Evidence:

- Upstream `dry-validation` pinned at 1.11.1 with lockfile discipline.
- Differential harness: 80+ schema cases, 6 unsupported-construct cases,
  each executed in isolated subprocesses with timeout and memory guards.
- `script/verify` one-command gate: tests + differential + rubocop + package audit.
- Package metadata audit (gemspec, Cargo.toml, extconf, LICENSE consistency).
- CI workflows: ci.yml, compatibility.yml, fuzz.yml, package.yml, security.yml.
- Dependabot, issue templates, PR template, SECURITY.md, SUPPORT_MATRIX.md.

## Milestone B — Common Schema Subset

Status: ✅ Complete (2026-07-29).

Completed via PRs #49–#56 (nine slices) and PRs #65–#71 (Rust hardening).

All nine slices delivered:

1. Required/optional keys, key presence, unknown-key policy.
2. Value types and nil policy.
3. Nested hashes and arrays.
4. Predicates with arguments.
5. Params/JSON coercion.
6. Schema composition.
7. Error messages.
8. Result API.
9. Unsupported constructs.

Rust engine hardened:

- `lib.rs` split into 6 modules (plan, engine, coercion, predicates, error, ruby_bridge).
- Typed `PredicateArg` enum replacing raw `serde_json::Value`.
- Recursion depth guard (default 128, configurable).
- 28 Rust unit tests (plan, coercion, predicates, messages).
- 64-input malformed-input resilience corpus.
- `cargo test` and `cargo clippy` wired into CI.

## Milestone C — Ordinary Rules Subset

Status: 🔵 Active.

Current state: ~10 rule scenarios in `rules_test.rb`, ~15 rule cases in the
differential corpus. No dedicated 50-case corpus yet. Code-quality tasks
C-Q1 through C-Q4 pending (see milestone file).

Goal: make ordinary rules (`rule` blocks, `key?`, `value()`, simple dependencies)
behave compatibly for the common schema subset.

## Milestone D — Performance Proof

Goal: produce honest, reproducible benchmark evidence.

## Milestone E — Compatibility Slice

Goal: define and implement a named compatibility slice with explicit
supported/unsupported lists.

## Milestone F — Packaging and Platforms

Goal: make installation and CI trustworthy across supported platforms.

## Milestone G — Stable Subset

Goal: prepare a public release candidate with docs, examples, and support policy.

## Dependency Order

A → B → C → D → E → F → G

B depends on A because schema behavior must be measured against a pinned
upstream baseline.

C depends on B because rules are only meaningful once schema behavior is stable.

D depends on C because performance claims should be made for the intended
feature subset, not a partial prototype.

E depends on D because the compatibility slice should be chosen with knowledge
of where the Rust path actually helps.

F depends on E because packaging should target the slice that is actually
supported.

G depends on F because a stable release requires trustworthy installation.

## What This Roadmap Deliberately Does Not Do

- It does not promise full `dry-validation` compatibility.
- It does not promise speedup before benchmarks exist.
- It does not expand scope to hints, i18n, monads, or macros before the core
  slice is proven.
