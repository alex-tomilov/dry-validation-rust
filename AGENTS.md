# AGENTS.md — dry-validation-rust

These repository instructions apply to every Codex task.

## Architecture

- This is a hybrid Ruby/Rust validation gem.
- Ruby owns the public DSL, arbitrary rule blocks, macros, options, context, and behavior requiring ordinary Ruby method dispatch.
- Rust owns the immutable declarative schema plan, supported traversal, coercions and native predicates, normalized output, and structural errors.
- The normal engine works with Ruby objects and therefore remains under the GVL.
- `Dry::Validation::Rust` is the safe primary namespace.
- Exact compatibility mode is experimental and must be tested in a process isolated from upstream `dry-validation`.

## Correctness invariants

1. Unsupported behavior fails loudly.
2. A compiled schema or rule plan cannot change semantics through later mutation.
3. Unknown field types, schema modes, and predicates never silently succeed.
4. Unexpected Ruby exceptions are never converted into ordinary validation failures.
5. No Rust panic may cross the Ruby FFI boundary.
6. Do not use `unwrap`, `expect`, broad `.ok()`, or `unwrap_or(default)` in runtime or FFI paths without explicit documented justification.
7. Compatibility claims require executable differential tests against pinned upstream releases.
8. Performance claims require reproducible before/after evidence.
9. Do not widen the supported DSL as a side effect of another task.
10. Thread-safe does not mean GVL-free parallel execution.

## Roadmap stage lookup

Store Codex stage prompts under:

```text
docs/codex/stages/technical/
docs/codex/stages/repository/
docs/codex/stages/release-gates/
```

When the user says `Implement T01`, `Run R04`, or `Audit G00`:

1. locate the single matching Markdown file by stage prefix;
2. read it completely before planning;
3. implement only that stage;
4. obey its dependencies, non-goals, tests, and acceptance criteria;
5. do not ask the user to paste the stage file.

If no unique matching file exists, report the lookup problem without guessing.

## Working method

- Work on one stage or issue at a time.
- Inspect current code, tests, documentation, build configuration, and recent related changes before editing.
- Prefer focused, reviewable commits.
- Add a regression test before or with a bug fix where practical.
- Preserve unrelated code and formatting.
- Do not remove or weaken a failing test merely to make checks green.
- Do not retain Ruby objects in Rust without reviewing GC rooting, marking, and compaction.
- Update compatibility, architecture, verification, support, and changelog documents for user-visible changes.

## Verification

Use the repository's canonical verification command when present. Otherwise run the equivalent of:

```bash
bundle install
bundle exec rake compile
bundle exec rake test

cargo fmt --check --manifest-path ext/dry_validation_rust/Cargo.toml
cargo test --locked --manifest-path ext/dry_validation_rust/Cargo.toml
cargo clippy --manifest-path ext/dry_validation_rust/Cargo.toml \
  --all-targets --all-features -- -D warnings
cargo check --locked --manifest-path ext/dry_validation_rust/Cargo.toml

gem build dry-validation-rust.gemspec
```

## Mandatory delivery gate

For every task that changes code, tests, build configuration, CI, packaging, compatibility behavior, or public documentation:

1. load and follow the `dvr-delivery-gate` skill after implementation and before the final response;
2. perform its skeptical review;
3. fix only blocker and high-severity findings;
4. rerun focused and full verification;
5. produce its PR-ready final report.

For special situations, load the matching skill:

- failed test/build/CI/package check → `dvr-failure-diagnosis`;
- ambiguous or regressing benchmark → `dvr-benchmark-regression`;
- upstream differential mismatch → `dvr-upstream-mismatch`.

## Forbidden actions

Do not:

- publish a gem;
- create or push a tag;
- create or finalize a GitHub release;
- change repository visibility or branch protection;
- add long-lived RubyGems credentials;
- commit secrets, signing keys, crash dumps, or arbitrary local benchmark output;
- make remote GitHub changes unless explicitly requested;
- advertise untested platforms or compatibility.

## Final response

Include:

1. summary;
2. files changed;
3. design decisions;
4. public API and compatibility impact;
5. exact checks and results;
6. benchmark evidence when relevant;
7. remaining limitations;
8. risks and rollback;
9. confirmation that no publication, tag, release, or repository-setting action occurred.
