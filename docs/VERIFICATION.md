# Verification Guide

This document maps project claims to the executable checks that support them.
Current milestone state is authoritative in [compat/status.yml](../compat/status.yml);
the intended milestone outcomes are in [ROADMAP.md](ROADMAP.md).

## Quick verification

Run the canonical local gate from a source checkout:

    script/verify

It compiles the native extension, checks Rust formatting, runs locked Rust
tests, Clippy, a locked Cargo build, the Ruby suite, dependency-version output,
and the source-gem audit. It also attempts a Rust advisory audit. The advisory
audit is non-gating when `cargo-audit` cannot be installed or run; use the
Security workflow for the CI-enforced audit.

`script/verify` does not run every CI job. Run these additional checks when the
affected surface calls for them:

    bundle exec rubocop
    bundle exec yard --fail-on-warning
    bundle exec rake generate:predicates:check

## Ruby evidence

### Full suite

    bundle exec rake test

The suite compiles the extension first and covers the public contract DSL,
schema evaluation and coercion, rules, result and message APIs, loading modes,
generated predicates, package metadata, workflow structure, release tooling,
and regression boundaries.

### Pinned differential compatibility

    bundle exec ruby -Itest test/differential_compatibility_test.rb

This runs the documented compatibility corpus in isolated Ruby processes
against this gem and the pinned upstream `dry-validation` version. It compares
successful outputs, value classes, errors, context, rule traces, and expected
exceptions. The pinned upstream versions are recorded in
[compat/status.yml](../compat/status.yml) and [SUPPORT_MATRIX.md](SUPPORT_MATRIX.md).

Recognized unsupported declarations are separately verified to raise the
documented `UnsupportedFeatureError` deterministically; parsing an input is not
treated as support.

### Baseline behavior and hostile input

    bundle exec ruby -Itest test/baseline_fixture_test.rb
    bundle exec ruby -Itest test/malformed_input_resilience_test.rb
    bundle exec ruby -Itest test/fuzz_engine_test.rb

The baseline fixtures protect representative public loading, schema, rule, and
context behavior. The malformed-input tests exercise deterministic handling of
a seeded corpus across schema modes. The hostile-input subprocess test includes
cycles, deep nesting, hostile keys, default-proc hashes, and generated values;
it guards against native crashes or process termination rather than treating
ordinary validation errors as failures.

## Rust evidence

### Locked build and tests

    cargo test --locked --manifest-path ext/dry_validation_rust/Cargo.toml
    cargo check --locked --manifest-path ext/dry_validation_rust/Cargo.toml

The Rust tests cover native plan parsing, coercion, predicates, engine
evaluation, and Ruby-boundary error handling. `--locked` ensures the checked
dependency graph matches the tracked lockfile.

### Formatting and linting

    cargo fmt --check --manifest-path ext/dry_validation_rust/Cargo.toml
    cargo clippy --manifest-path ext/dry_validation_rust/Cargo.toml --all-targets --all-features -- -D warnings

### MSRV

The supported Rust minimum is recorded in [SUPPORT_MATRIX.md](SUPPORT_MATRIX.md).
Verify it explicitly with that version, for example:

    cargo +1.75.0 check --locked --manifest-path ext/dry_validation_rust/Cargo.toml
    cargo +1.75.0 test --locked --manifest-path ext/dry_validation_rust/Cargo.toml

## Packaging and release evidence

### Source gem

    bundle exec rake package:audit
    script/update-gem-contents gem_contents.txt
    diff -u expected_gem_contents.txt gem_contents.txt

The package audit builds the source gem, verifies its file selection and
metadata, installs it into an isolated gem home, and runs a safe-entrypoint
smoke test.

### Release preparation

    script/release MAJOR.MINOR.PATCH

The release script requires a clean checkout, updates the Ruby/Cargo versions
and lockfiles plus the changelog, then creates a local release commit and tag.
See [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) before using it. It neither
pushes Git history nor publishes an artifact.

## Benchmarks and regression gates

Run the representative matrix with:

    ruby -Ilib benchmark/schema_throughput.rb

Use `ENGINE`, `SCENARIO`, `N`, `WARMUP`, and `FORMAT=json` to select a workload
and record comparable output. Published host-specific results and their
methodology live in the [README](../README.md#representative-benchmark-results);
they are evidence for those workloads, not a general speed guarantee.

Ruby-allocation and Criterion regression gates compare pull-request candidates
with the main-branch baselines when those baselines are available. Refresh a
baseline only after reviewing the measurement:

    bundle exec script/record-allocation-baseline
    bundle exec script/record-criterion-baseline

## CI workflows

| Workflow                                                   | Trigger                               | Evidence provided                                                                                                                                                                                            |
| ---------------------------------------------------------- | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `CI`                                                       | Pull requests, pushes, weekly, manual | Changelog gate; hosted source fallback; Ruby/Rust quality (including allowed-to-fail beta); weekly nightly Miri; dependency bounds; package smoke; allocation and Criterion regression checks; loading modes |
| `Compatibility`                                            | Pull requests, pushes, daily, manual  | Pinned upstream installation and baseline-fixture preflight artifact                                                                                                                                         |
| `Package`                                                  | Pull requests, pushes, manual         | Source-gem audit, isolated install smoke test, and generated package-content manifest                                                                                                                        |
| `Security`                                                 | Pull requests, pushes, weekly, manual | Ruby/Rust dependency audit, `cargo vet`, locked build, and CodeQL                                                                                                                                            |
| `Fuzz`                                                     | Weekly, manual                        | Bounded nightly plan-deserialization fuzzing and corpus/crash artifacts; non-gating                                                                                                                          |
| `Native Gems`                                              | Manual                                | Cross-platform native-gem build and installed-gem smoke tests                                                                                                                                                |
| `Record Allocation Baseline` / `Record Criterion Baseline` | Manual                                | Reviewable benchmark-baseline artifacts without repository writes                                                                                                                                            |
| `rubygems:push`                                            | Version tags, manual                  | Release-context verification, signed gem artifacts, and trusted publishing after environment approval                                                                                                        |

## Claim-to-check map

| Claim                                         | Primary evidence                                                                        |
| --------------------------------------------- | --------------------------------------------------------------------------------------- |
| Supported public behavior                     | `bundle exec rake test` plus the applicable baseline fixture                            |
| Pinned compatibility behavior                 | `test/differential_compatibility_test.rb` in isolated processes                         |
| Explicit failure for unsupported declarations | `test/differential_compatibility_test.rb` and `test/malformed_input_resilience_test.rb` |
| Native parser and engine resilience           | Locked Rust tests, `test/fuzz_engine_test.rb`, and the scheduled Fuzz workflow          |
| Package installs cleanly                      | `bundle exec rake package:audit` and the Package workflow                               |
| Rust dependency graph is reproducible         | Locked Cargo test/check commands and the Security workflow                              |
| Ruby style and API documentation are clean    | `bundle exec rubocop` and `bundle exec yard --fail-on-warning`                          |
| Performance or allocation regression claim    | Benchmark matrix plus the corresponding main-baseline CI gate                           |
