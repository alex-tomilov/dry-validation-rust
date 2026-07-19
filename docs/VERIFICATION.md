# Verification record

Date: 2026-07-16

## Canonical command

Run the repository verification entry point from the project root:

```bash
script/verify
```

The command exits nonzero on Ruby test, native compile, dependency version
capture, Rust formatting, Rust test, Clippy, Cargo lockfile check, package
audit, source-gem install, or installed smoke-contract failure.

Run only the package audit with:

```bash
bundle exec rake package:audit
```

## Deterministic judge demo

After compiling the native extension, run the safe-namespace demo in human or
machine-readable mode:

```bash
script/demo
script/demo --json
```

Both modes execute the same asserted cases and exit nonzero if any expectation
fails. The script resolves the repository from its own location, so its
absolute path works from any current directory. The demo is offline and does
not invoke a benchmark or an OpenAI API.

## GitHub Actions

The repository defines these non-release workflows:

- `.github/workflows/ci.yml`: Ruby integration matrix for Ruby 3.3, 3.4, and
  3.5 on Linux and macOS; Rust quality checks on MSRV 1.85 and stable; isolated
  loading-mode checks for safe mode, exact mode, exact-mode conflict detection,
  and built-gem installation.
- `.github/workflows/compatibility.yml`: pinned upstream preflight for
  `dry-validation` 1.11.1 and `dry-schema` 1.16.0, with structured artifact
  upload until the full differential harness exists.
- `.github/workflows/security.yml`: bundler-audit, Cargo audit, lockfile
  checks, and Ruby CodeQL with explicit least-privilege permissions.
- `.github/workflows/package.yml`: source-gem package audit and artifact
  upload without publication.
- `.github/workflows/fuzz.yml`: scheduled/manual bounded fuzz preflight that is
  non-blocking for ordinary pull requests until a dedicated fuzz target exists.
- `.github/workflows/container.yml`: read-only pull-request image builds plus
  restricted manual/tag GHCR publication. A separate job pulls the published
  Linux amd64 image by digest and runs the offline Docker smoke suite. Workflow
  presence is not evidence that a public image has been published.

There is intentionally no RubyGems or GitHub release workflow. The container
workflow prepares GHCR publication only for explicit manual or tag events.

Dependency update and audit policy is documented in
[DEPENDENCY_SECURITY.md](DEPENDENCY_SECURITY.md). Dependabot is configured for
Bundler, Cargo, and GitHub Actions in `.github/dependabot.yml`, with native
bridge updates isolated from routine low-risk updates.

## Toolchain

- Ruby: `ruby 3.3.7 (2025-01-15 revision be31f993d7) [x86_64-linux]`
- Rust: `rustc 1.90.0 (1159e78c4 2025-09-14) (Homebrew)`
- Rust host: `x86_64-unknown-linux-gnu`
- Platform: `linux x86_64`
- Bundler: `Bundler version 2.5.22`

The canonical verification command also prints locked Ruby gem versions and a
top-level locked Cargo dependency tree through:

```bash
bundle exec rake dependency:versions
```

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
49 runs, 311 assertions, 0 failures, 0 errors, 0 skips

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

Observed from `bundle exec rake package:audit`:

```text
CHANGELOG.md
LICENSE
NOTICE.md
README.md
docs/ARCHITECTURE.md
docs/COMPATIBILITY.md
docs/FEASIBILITY.md
docs/SUPPORT_MATRIX.md
docs/VERIFICATION.md
dry-validation-rust.gemspec
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
rust-toolchain.toml
```

Local Cargo `target` files, generated Makefiles, logs, native shared objects,
built `.gem` artifacts, benchmarks, examples, editor files, credentials, and
Codex stage prompts are intentionally excluded from the source gem.

## Verification runs

- `script/verify`: passed after adding the package audit to canonical
  verification.
- `bundle exec rake package:audit`: passed from the built state.
- `script/verify`: passed after adding dependency version capture to canonical
  verification.
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
- The dedicated package audit now also rejects benchmarks, examples, Codex stage
  prompts, editor files, credentials, and built package artifacts.
