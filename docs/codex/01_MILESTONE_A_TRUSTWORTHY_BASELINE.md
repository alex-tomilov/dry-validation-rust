# Milestone A — Trustworthy Baseline

Status: ✅ Complete (2026-07-29).
Completed via PRs #48–#51.

## Completion Evidence

| Acceptance Criterion                            | Artifact                                                         | Status |
| ----------------------------------------------- | ---------------------------------------------------------------- | ------ |
| Upstream pinned at specific version             | `Gemfile.lock` → dry-validation 1.11.1                           | ✅     |
| Differential harness with isolated subprocesses | `test/differential_compatibility_test.rb`                        | ✅     |
| 80+ schema cases                                | `test/fixtures/differential/`                                    | ✅     |
| 6 unsupported-construct cases                   | `test/differential_compatibility_test.rb`                        | ✅     |
| Timeout and memory guards                       | Subprocess isolation with `Timeout` + `RLIMIT_AS`                | ✅     |
| One-command verification                        | `script/verify`                                                  | ✅     |
| Package metadata audit                          | `script/verify` (package audit step)                             | ✅     |
| CI workflows                                    | `.github/workflows/{ci,compatibility,fuzz,package,security}.yml` | ✅     |
| Dependabot                                      | `.github/dependabot.yml`                                         | ✅     |
| Issue/PR templates                              | `.github/ISSUE_TEMPLATE/`, `.github/PULL_REQUEST_TEMPLATE.md`    | ✅     |
| Security policy                                 | `SECURITY.md`                                                    | ✅     |
| Support matrix                                  | `SUPPORT_MATRIX.md`                                              | ✅     |

## Key Artifacts Produced

- **Differential harness**: Runs each fixture in an isolated subprocess against
  both this gem and pinned upstream. Compares output values and error messages
  via deep equality. Unsupported constructs must raise `UnsupportedFeatureError`.
- **Fixture corpus**: `test/fixtures/differential/` — YAML files defining
  contract class, input, and expected output.
- **Verification script**: `script/verify` — runs tests, differential suite,
  RuboCop, and package audit in sequence. Non-zero exit on any failure.
- **CI workflows**: 5 workflows covering tests, compatibility, fuzzing,
  packaging, and security.

## Original Scope (Preserved for Reference)

Goal: make the project's claims verifiable before adding features.

### Tasks

1. Pin upstream `dry-validation` to a specific version in `Gemfile.lock`.
2. Build a differential test harness that runs the same contract through both
   this gem and upstream, comparing output values and error messages.
3. Create 50+ fixture cases covering the schema subset.
4. Add `script/verify` as a one-command gate.
5. Audit package metadata (gemspec, Cargo.toml, extconf, LICENSE).
6. Set up CI workflows.

### Acceptance Criteria

- `script/verify` passes on a clean checkout.
- Differential suite runs in CI.
- No undocumented claims in README.
