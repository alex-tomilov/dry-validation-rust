# Contributing to dry-validation-rust

Thank you for helping improve `dry-validation-rust`. This is a hybrid
Ruby/Rust native extension, so changes must preserve both Ruby-facing behavior
and the safety of the Rust FFI boundary.

Before starting substantial work, open an issue or comment on an existing one
so scope and compatibility expectations can be agreed. Keep pull requests
focused on one behavior, maintenance concern, or documentation change.
Roadmap priorities, milestone scope, label meanings, and project-board flow are
defined in [docs/PROJECT_MANAGEMENT.md](docs/PROJECT_MANAGEMENT.md).

## Prerequisites

Use a Ruby, Rust toolchain, and platform listed in
[the support matrix](docs/SUPPORT_MATRIX.md). A source checkout currently
requires:

- CRuby 3.3 or newer with development headers;
- Rust 1.75 or newer and Cargo (the MSRV, tested in CI);
- Bundler;
- a C compiler and `make`;
- Clang/libclang when the selected `rb-sys` build requires bindgen.

On macOS, install the Xcode Command Line Tools and LLVM. On Debian/Ubuntu,
install a build toolchain plus `clang` and `libclang-dev`.

## Clean-checkout setup

```bash
git clone https://github.com/alex-tomilov/dry-validation-rust.git
cd dry-validation-rust
bundle install
bundle exec rake compile
script/verify
```

`script/verify` is the canonical local gate. It compiles the native extension,
runs the Ruby and Rust tests, checks Rust formatting and Clippy warnings,
verifies the lockfile, builds the source gem, installs it into an isolated gem
home, and runs an installed-package smoke contract.

## Test layers

Use the smallest relevant check while developing, then run `script/verify`
before requesting review.

```bash
# Ruby integration suite
script/test

# One Ruby test file
bundle exec ruby -Itest test/schema_test.rb

# Rust unit tests and quality checks
cargo test --locked --manifest-path ext/dry_validation_rust/Cargo.toml
cargo fmt --check --manifest-path ext/dry_validation_rust/Cargo.toml
cargo clippy --manifest-path ext/dry_validation_rust/Cargo.toml \
  --all-targets --all-features -- -D warnings

# Source-gem contents and clean-install smoke
bundle exec rake package:audit
```

Rust code must be formatted with `rustfmt` and pass Clippy with warnings denied.
Code must compile on the Rust 1.75 MSRV; CI tests that exact toolchain.
Runtime and FFI code must not use `unwrap`, `expect`, broad `.ok()`, or
`unwrap_or(default)` unless the reason is narrow, documented, and reviewed.
No Rust panic may cross the Ruby FFI boundary.

## Compatibility fixtures

The current baseline fixtures live in `test/fixtures/baseline` and are
exercised by `test/baseline_fixture_test.rb`.

When changing compatibility behavior:

1. Add or update a narrowly named scenario in
   `test/baseline_fixture_test.rb`.
2. Add the expected normalized result under
   `test/fixtures/baseline/<scenario>.json`.
3. Cover valid and invalid input when both paths are relevant.
4. Compare the same contract and input against the pinned
   `dry-validation` and `dry-schema` versions from
   `docs/SUPPORT_MATRIX.md`, in a separate process.
5. Include both outputs, exceptions, and version details in the pull request.

The full differential harness is not implemented yet. Until it is, do not
describe a local baseline fixture as proof of upstream parity.

## Changelog policy

Add an entry under `Unreleased` in `CHANGELOG.md` for user-visible behavior,
compatibility changes, packaging changes, security changes, or meaningful
documentation changes. Internal refactors that do not affect users generally
do not need an entry.

Do not rewrite released changelog sections except to correct a factual error.

## Benchmark evidence

Performance claims require reproducible before/after evidence. Include:

- the exact benchmark script and revision;
- warmup and measured iteration counts;
- Ruby, Rust, dependency, OS, CPU, and memory details;
- throughput or latency plus RSS/allocations where relevant;
- raw results from multiple runs;
- compatibility checks proving semantics did not change.

`script/benchmark-smoke` is a non-gating sanity check, not evidence for a
public performance claim.

## Pull requests

The repository currently uses `develop` as the active integration branch and
`main` as the default/release branch. Unless a maintainer requests otherwise,
open feature and maintenance pull requests against `develop`. Tested changes
are promoted to `main`; releases are tagged from `main`.

Pull requests should:

- link the implementation issue and milestone;
- explain the problem and the chosen design;
- identify public API and compatibility impact;
- include regression tests for behavior changes;
- remain small enough to review as one coherent change;
- update relevant documentation and the changelog;
- report exact verification commands and results;
- avoid drive-by formatting or unrelated refactoring.

Prefer squash merging for a focused pull request. Do not force-push after
review has started unless necessary to remove sensitive data or repair the
branch, and explain any rewritten history.

Do not commit generated native libraries, packaged `.gem` files, Cargo
`target` output, generated Makefiles, or other build artifacts. Release tooling
may generate binary artifacts in CI, but those artifacts belong in the release
pipeline rather than the source tree.

## Contribution certification

The project does not require a Contributor License Agreement or mandatory
Developer Certificate of Origin sign-off at this stage. By contributing, you
confirm that you have the right to submit the work under the repository's MIT
license. A future certification change will be proposed publicly before it is
enforced.
