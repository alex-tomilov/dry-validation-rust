# Codex stage T00: establish a reproducible baseline

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Repository context

Work in the current `dry-validation-rust` repository. Inspect the branch, implementation, tests, documentation, and recent related changes before editing. Do not assume every path or API named below is still exact.

## Assignment

Implement only this technical-polishing stage. Keep it suitable for one focused pull request. When the stage is explicitly large, split it into the smallest dependency-ordered PRs and complete only the first coherent PR unless the user explicitly asks for the whole sequence.

**Priority:** P0  
**Suggested branch:** `chore/baseline-verification`  
**Risk:** Low  
**Dependencies:** None

## Objective

Create a repeatable record of current behavior before changing architecture.

## Work items

1. Add a single verification entry point, for example:

```text
script/verify
```

It should run:

```bash
bundle exec rake compile
bundle exec rake test
cargo fmt --check --manifest-path ext/dry_validation_rust/Cargo.toml
cargo test --manifest-path ext/dry_validation_rust/Cargo.toml
cargo clippy --manifest-path ext/dry_validation_rust/Cargo.toml \
  --all-targets --all-features -- -D warnings
cargo check --manifest-path ext/dry_validation_rust/Cargo.toml --locked
gem build dry-validation-rust.gemspec
```

2. Add `script/benchmark-smoke` that runs a small, non-gating benchmark.
3. Record:
   - Ruby version;
   - Rust version;
   - platform;
   - Bundler version;
   - test count and assertion count;
   - native extension compile status;
   - source gem file list;
   - current benchmark JSON.
4. Add behavior fixtures for representative contracts:
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
5. Store expected normalized output and errors as stable JSON fixtures where possible.
6. Ensure test helpers can rebuild the extension from a clean checkout.

## Files likely touched

```text
Rakefile
script/verify
script/benchmark-smoke
test/test_helper.rb
test/fixtures/baseline/*.json
docs/VERIFICATION.md
```

## Tests

- Run the verification script twice from a clean tree.
- Remove build artifacts and run it again.
- Build the `.gem`, install it into a temporary gem home, and run a smoke contract.
- Confirm the test process does not accidentally load upstream `dry-validation`.

## Acceptance criteria

- One documented command verifies the repository.
- The command exits nonzero on any Ruby, Rust, formatting, lint, build, or package failure.
- Baseline fixtures cover every currently advertised feature category.
- A built source gem can be installed and required in a clean temporary environment.
- No production behavior changes are introduced.

## Stop/adjust signals

- Tests depend on execution order.
- Tests pass only when stale native artifacts are present.
- Exact mode accidentally loads upstream.
- The source gem omits required Rust or Ruby files.
- Benchmark output is not machine-readable.

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
