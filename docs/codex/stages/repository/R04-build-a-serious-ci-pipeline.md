# Codex stage R04: build a serious CI pipeline

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Repository context

Work in the current `dry-validation-rust` repository. Inspect the branch, implementation, tests, documentation, and recent related changes before editing. Do not assume every path or API named below is still exact.

## Assignment

Implement only this public-repository maturity stage. Keep it suitable for one focused pull request. When the stage is explicitly large, split it into the smallest dependency-ordered PRs and complete only the first coherent PR unless the user explicitly asks for the whole sequence.

**Priority:** P0  
**Suggested branch:** `chore/ci-matrix`

## Workflows

```text
.github/workflows/ci.yml
.github/workflows/compatibility.yml
.github/workflows/security.yml
.github/workflows/package.yml
.github/workflows/fuzz.yml
```

Do not create `release.yml` until packaging is stable.

## `ci.yml`

Jobs:

### Ruby integration

Matrix initially:

- Ruby 3.3;
- Ruby 3.4;
- Ruby 3.5 if released and supported;
- Linux;
- macOS where build capacity permits.

Steps:

1. checkout;
2. setup Ruby/Bundler;
3. setup Rust toolchain;
4. install native build prerequisites;
5. bundle cache;
6. compile extension;
7. run Ruby tests with warnings;
8. run package audit.

### Rust quality

Run:

```bash
cargo fmt --check
cargo test --locked
cargo clippy --all-targets --all-features -- -D warnings
cargo check --locked
```

Test both:

- MSRV 1.85;
- current stable.

If edition/dependency requirements make MSRV inaccurate, either fix them or update the documented MSRV. Never advertise an untested MSRV.

### Loading modes

Run isolated subprocess tests for:

- safe mode;
- exact mode;
- conflict detection;
- built-gem installation.

## `compatibility.yml`

- install pinned upstream gems;
- run tagged differential suite;
- upload structured diff artifacts;
- optionally run a broader scheduled suite nightly.

## `security.yml`

- dependency audits;
- lockfile review;
- CodeQL where useful;
- secret scanning is a repository setting;
- no untrusted PR should receive publish credentials.

## `fuzz.yml`

- scheduled/manual;
- bounded duration;
- upload crashing corpus;
- never block ordinary PRs initially.

## CI principles

- pin action major versions or commit SHAs according to project policy;
- use least-privilege permissions;
- define explicit `permissions`;
- cancel superseded runs;
- avoid shell scripts that interpolate untrusted PR data;
- keep performance informational on shared runners.

## Acceptance criteria

- CI passes from a clean public fork.
- Required checks complete without repository secrets.
- MSRV and supported Ruby versions are genuinely tested.
- Package installation is tested, not merely compilation.
- Compatibility failures produce useful artifacts.
- Workflow permissions are minimal.

---

---

## Mandatory execution sequence

1. Inspect relevant code, tests, build files, and documentation.
2. Restate current behavior and the minimal proposed design.
3. Identify assumptions in this prompt that do not match the current repository.
4. Add/update regression and boundary tests.
5. Implement the focused change.
6. Run focused checks.
7. Run canonical full verification.
8. Review the diff for unrelated behavior or compatibility changes.
9. Update documentation/changelog only where justified.
10. Stop without publishing or changing remote repository settings.

## Scope control

- Do not perform adjacent roadmap stages.
- Do not add unrelated DSL features.
- Do not hide an upstream mismatch by weakening canonicalization or tests.
- Do not claim optimization without measurements.
- If the full stage cannot safely fit one PR, provide a PR breakdown and implement the first self-contained part.

## Final response format

Return:

1. **Summary**
2. **Current behavior confirmed**
3. **Files changed**
4. **Implementation details**
5. **Design decisions / rejected alternatives**
6. **Public API and compatibility impact**
7. **Tests and exact commands**
8. **Benchmark evidence**, if applicable
9. **Known limitations / follow-ups**
10. **Risks / rollback**
11. **No-release confirmation**
