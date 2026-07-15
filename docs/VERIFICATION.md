# Verification record

Date: 2026-07-15

## Canonical command

Run the repository verification entry point from the project root:

```bash
script/verify
```

The command exits nonzero on Ruby test, native compile, Rust formatting, Rust
test, Clippy, Cargo lockfile check, gem build, source-gem install, or installed
smoke-contract failure.

## Toolchain

- Ruby: `ruby 3.3.7 (2025-01-15 revision be31f993d7) [x86_64-linux]`
- Rust: `rustc 1.90.0 (1159e78c4 2025-09-14) (Homebrew)`
- Rust host: `x86_64-unknown-linux-gnu`
- Platform: `linux x86_64`
- Bundler: `Bundler version 2.5.22`

## Current behavior confirmed

Baseline fixtures live under `test/fixtures/baseline/*.json` and are checked by
`test/baseline_fixture_test.rb`. They cover:

- shallow Params;
- nested hash;
- primitive array;
- array of hashes;
- Ruby predicate;
- rule failure;
- `rule.each`;
- options and context;
- inherited schema;
- imported schema;
- exact and side-by-side loading.

The exact and side-by-side loading fixtures assert that the upstream
`dry-validation` gem is not loaded accidentally.

## Test and build counts

Observed from `script/verify`:

```text
29 runs, 65 assertions, 0 failures, 0 errors, 0 skips

running 4 tests
test result: ok. 4 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out
```

Native extension compile status: `bundle exec rake compile` completed
successfully, including a rebuild after removing generated artifacts.

## Benchmark smoke

Run the non-gating machine-readable benchmark smoke with:

```bash
script/benchmark-smoke
```

Observed JSON:

```json
{
  "benchmark": "schema_throughput",
  "ruby_platform": "x86_64-linux",
  "engines": [
    {
      "iterations": 1000,
      "warmup_iterations": 100,
      "elapsed": 0.011346595998475095,
      "throughput": 88132.15876676963,
      "allocated_objects": 71012,
      "engine": "dry-validation-rust",
      "version": "0.1.0.pre1",
      "ruby": "ruby 3.3.7 (2025-01-15 revision be31f993d7) [x86_64-linux]"
    }
  ]
}
```

This smoke benchmark has no threshold and is not a public performance claim.

## Source gem file list

Observed from `Gem::Specification.load("dry-validation-rust.gemspec").files`:

```text
CHANGELOG.md
LICENSE
NOTICE.md
README.md
benchmark/schema_throughput.rb
docs/ARCHITECTURE.md
docs/COMPATIBILITY.md
docs/FEASIBILITY.md
docs/VERIFICATION.md
docs/codex/README.md
docs/codex/stages/release-gates/G00-audit-and-close-the-alpha-release-gate.md
docs/codex/stages/release-gates/G01-audit-and-close-the-beta-release-gate.md
docs/codex/stages/release-gates/G02-audit-and-close-the-release-candidate-gate.md
docs/codex/stages/release-gates/G03-audit-and-close-the-stable-1-0-gate.md
docs/codex/stages/repository/R00-define-product-identity-and-scope.md
docs/codex/stages/repository/R01-choose-branch-and-contribution-governance.md
docs/codex/stages/repository/R02-add-community-health-and-support-files.md
docs/codex/stages/repository/R03-repository-metadata-and-gemspec-cleanup.md
docs/codex/stages/repository/R04-build-a-serious-ci-pipeline.md
docs/codex/stages/repository/R05-dependency-and-supply-chain-hygiene.md
docs/codex/stages/repository/R06-native-binary-gem-strategy.md
docs/codex/stages/repository/R07-release-automation-and-version-policy.md
docs/codex/stages/repository/R08-documentation-information-architecture.md
docs/codex/stages/repository/R09-project-planning-and-issue-hygiene.md
docs/codex/stages/repository/R10-public-performance-and-compatibility-evidence.md
docs/codex/stages/repository/R11-adoption-examples-and-supportability.md
docs/codex/stages/repository/R12-stable-1-0-governance.md
docs/codex/stages/technical/T00-establish-a-reproducible-baseline.md
docs/codex/stages/technical/T01-separate-mutable-dsl-builders-from-immutable-compiled-plans.md
docs/codex/stages/technical/T02-introduce-a-typed-and-strictly-validated-native-plan.md
docs/codex/stages/technical/T03-correct-ruby-exception-handling-across-the-rust-boundary.md
docs/codex/stages/technical/T04-support-arbitrary-precision-ruby-integers.md
docs/codex/stages/technical/T05-split-the-rust-extension-into-modules-without-behavior-changes.md
docs/codex/stages/technical/T06-build-a-differential-compatibility-harness.md
docs/codex/stages/technical/T07-index-schema-error-paths.md
docs/codex/stages/technical/T08-cache-finalized-result-message-views.md
docs/codex/stages/technical/T09-normalize-rule-paths-and-compile-rule-metadata-once.md
docs/codex/stages/technical/T10-add-measured-native-fast-paths.md
docs/codex/stages/technical/T11-replace-the-benchmark-smoke-test-with-a-benchmark-suite.md
docs/codex/stages/technical/T12-property-fuzz-malformed-plan-gc-and-concurrency-testing.md
docs/codex/stages/technical/T13-evaluate-a-future-batch-gvl-releasing-api.md
examples/new_user_contract.rb
ext/dry_validation_rust/Cargo.lock
ext/dry_validation_rust/Cargo.toml
ext/dry_validation_rust/extconf.rb
ext/dry_validation_rust/src/lib.rs
lib/dry-schema.rb
lib/dry-validation.rb
lib/dry/schema.rb
lib/dry/validation.rb
lib/dry/validation/rust.rb
lib/dry/validation/rust/config.rb
lib/dry/validation/rust/contract.rb
lib/dry/validation/rust/errors.rb
lib/dry/validation/rust/evaluator.rb
lib/dry/validation/rust/failures.rb
lib/dry/validation/rust/macros.rb
lib/dry/validation/rust/message.rb
lib/dry/validation/rust/message_set.rb
lib/dry/validation/rust/native.rb
lib/dry/validation/rust/path.rb
lib/dry/validation/rust/result.rb
lib/dry/validation/rust/rule.rb
lib/dry/validation/rust/schema.rb
lib/dry/validation/rust/values.rb
lib/dry/validation/rust/version.rb
lib/dry_validation_rust.rb
```

Local Cargo `target` files, generated Makefiles, logs, native shared objects,
and built `.gem` artifacts are intentionally excluded from the source gem.

## Verification runs

- `script/verify`: passed after formatting and Clippy compatibility fixes.
- `script/verify`: passed a second time from the built state.
- Removed generated build artifacts and ran `script/verify`: passed, including
  native extension rebuild, gem build, temporary gem-home install, and installed
  smoke contract.

## Prompt assumptions corrected

- The old verification document existed but was handwritten and did not point
  to a single canonical command.
- `benchmark/schema_throughput.rb` emitted text only; it now supports JSON for
  benchmark smoke capture.
- The previous gemspec glob could include local Cargo `target` `.rs` files when
  build artifacts existed. The source gem file list now rejects `target`.
