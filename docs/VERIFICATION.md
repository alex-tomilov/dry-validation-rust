# Verification

## Canonical command

Run from the repository root:

```bash
script/verify
```

It compiles the native extension, runs Ruby and Rust tests, records dependency
versions, checks Rust formatting/Clippy/lockfile consistency, audits the source
gem, installs it in a temporary gem home, and runs a smoke contract. The command
exits nonzero when any required step fails.

The Ruby suite includes the pinned, separate-process differential corpus. Run
`bundle exec rake compatibility:differential` to execute that corpus alone.

Focused commands remain useful while developing:

```bash
bundle exec rake compile
bundle exec rake test
cargo test --locked --manifest-path ext/dry_validation_rust/Cargo.toml
bundle exec rake package:audit
```

The canonical command output is the source for current test counts, toolchain
versions, and package contents. This document deliberately does not snapshot
those volatile values.

## Behavior evidence

`test/fixtures/baseline/*.json` and `test/baseline_fixture_test.rb` cover the
currently advertised safe-mode behavior categories, including nested data,
arrays, Ruby predicates/rules, options/context, schema reuse, and isolated
loading modes.

Compatibility claims require cases executed against pinned upstream releases in
separate processes. `test/differential_compatibility_test.rb` compares values,
value classes, success state, errors, exceptions, and rule traces for the
initial corpus. Documentation text and method/file inventories are not
compatibility evidence.

## CI responsibilities

- `ci.yml`: supported Ruby/platform integration, Rust MSRV/stable checks,
  loading isolation, and package smoke checks.
- `compatibility.yml`: pinned-upstream preflight and structured evidence until
  the full Milestone B common-schema corpus is implemented.
- `security.yml`: dependency audits and CodeQL with explicit permissions.
- `package.yml`: source-gem audit and artifact upload without publication.
- `fuzz.yml`: scheduled/manual bounded preflight until Milestone B adds dedicated
  targets justified by risk.

There is intentionally no publication workflow yet. Pull-request workflows must
not contain publication credentials or release permissions.

## Package evidence

`bundle exec rake package:audit` verifies an allow/deny package manifest, rejects
local/generated/credential material, installs the built gem into a temporary
gem home, confirms it loads from that location without upstream dry-validation,
and runs valid/invalid contract smoke cases.

Codex stage prompts, benchmarks, examples, editor state, generated native output,
and built gem artifacts are excluded from the source gem.

## Performance evidence

`script/benchmark-smoke` is a non-gating local sanity check. It is not a public
performance claim. Milestone D requires representative semantics, warmup,
multiple samples, environment data, allocations/RSS where relevant, negative
results, and pinned-upstream process isolation before publishing comparisons.

Shared-runner benchmark thresholds and CI commits of benchmark baselines are not
part of the verification model.

## Evidence policy

- Test observable behavior, failure propagation, security boundaries, and built
  artifacts.
- Parse configuration when syntax or permissions matter; do not freeze command
  strings or exact roadmap counts.
- Do not test documentation wording, heading order, badges, file layout, YARD
  coverage, or arbitrary line-coverage percentages.
- Record reproducible regressions as focused tests; avoid permanent snapshots of
  incidental local output.
