# Verification Guide

Status: living document.
Last updated: 2026-07-29.

This document describes how to verify the claims made in the project
documentation. Every claim in ARCHITECTURE.md, COMPATIBILITY.md, and the
README should be traceable to a command or test described here.

## Quick Verification

Run the full verification suite:

    script/verify

This executes:

1. Ruby unit and integration tests (`bundle exec rake test`).
2. Differential compatibility tests against pinned upstream.
3. RuboCop lint.
4. Package metadata audit.

## Milestone Verification Status

| Milestone                | Verification Method                                                                | Status      |
| ------------------------ | ---------------------------------------------------------------------------------- | ----------- |
| A — Trustworthy Baseline | `script/verify`, CI workflows, package audit                                       | ✅ Verified |
| B — Common Schema Subset | Differential corpus (80+ cases), Rust unit tests (28), malformed-input corpus (64) | ✅ Verified |
| C — Ordinary Rules       | `rules_test.rb`, differential rule cases                                           | 🔵 Partial  |
| D — Performance Proof    | `benchmark/schema_throughput.rb` (no published results yet)                        | ⚪ Pending  |
| E–G                      | Not yet applicable                                                                 | ⚪ Pending  |

## Ruby-Side Evidence

### Unit Tests

    bundle exec rake test

Covers: schema definition, coercion, predicates, rules, result API, messages,
config, contract DSL, evaluator, path, failures, values.

### Differential Compatibility

    bundle exec ruby test/differential_compatibility_test.rb

Runs each fixture case in an isolated subprocess against both this gem and
pinned upstream `dry-validation` 1.11.1. Compares:

- Output values (deep equality).
- Error messages (deep equality).
- Unsupported constructs raise the expected error class.

Fixtures live in `test/fixtures/differential/`.

### Unsupported Constructs

Six cases verify that unsupported upstream features (hints, i18n, monads,
macros, each with complex blocks, dry-schema composition) raise
`UnsupportedFeatureError` rather than silently producing wrong results.

## Rust-Side Evidence

### Unit Tests

    cd ext/dry_validation_rust && cargo test

28 tests covering:

- Plan deserialization and version checking (`plan.rs`).
- Coercion edge cases: `"Infinity"`, `"NaN"`, `"1_000"`, empty strings,
  overflow, unicode (`coercion.rs`).
- Predicate evaluation: boundary values, type mismatches (`predicates.rs`).
- Message interpolation: token substitution, missing tokens (`messages.rs`).

### Clippy

    cd ext/dry_validation_rust && cargo clippy -- -D warnings

### Malformed-Input Resilience

64-input seeded corpus in `test/malformed_input_test.rb` exercises the Rust
engine with:

- Deeply nested structures (up to depth 200, guarded by recursion limit).
- Oversized strings (1 MB+).
- Mixed-type arrays.
- Null bytes and invalid UTF-8 sequences.
- Extreme numeric values (MAX_INT, MIN_INT, MAX_FLOAT, NaN, Infinity).

## Compatibility Matrix

See `COMPATIBILITY.md` for the feature-by-feature matrix. Each row marked
"✅ implemented and covered" must have at least one differential fixture case.

## Benchmarks

See `benchmark/schema_throughput.rb`. No published results yet — Milestone D
will produce `docs/BENCHMARKS.md`.

## CI Workflows

| Workflow            | Trigger          | Purpose                                    |
| ------------------- | ---------------- | ------------------------------------------ |
| `ci.yml`            | push, PR         | Tests + lint + compile                     |
| `compatibility.yml` | push, PR, weekly | Differential suite against pinned upstream |
| `fuzz.yml`          | weekly, manual   | Malformed-input corpus                     |
| `package.yml`       | push, PR         | Gemspec/Cargo metadata audit               |
| `security.yml`      | push, PR, weekly | `cargo audit` + `bundle audit`             |

## Reproducing a Specific Claim

| Claim                            | Command                                                    |
| -------------------------------- | ---------------------------------------------------------- |
| "80+ differential cases pass"    | `bundle exec ruby test/differential_compatibility_test.rb` |
| "28 Rust unit tests pass"        | `cd ext/dry_validation_rust && cargo test`                 |
| "64 malformed inputs handled"    | `bundle exec ruby test/malformed_input_test.rb`            |
| "Package metadata is consistent" | `script/verify` (package audit step)                       |
| "RuboCop clean"                  | `bundle exec rubocop`                                      |
