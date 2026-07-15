# Codex stage T05: split the Rust extension into modules without behavior changes

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Repository context

Work in the current `dry-validation-rust` repository. Inspect the branch, implementation, tests, documentation, and recent related changes before editing. Do not assume every path or API named below is still exact.

## Assignment

Implement only this technical-polishing stage. Keep it suitable for one focused pull request. When the stage is explicitly large, split it into the smallest dependency-ordered PRs and complete only the first coherent PR unless the user explicitly asks for the whole sequence.

**Priority:** P1  
**Suggested branch:** `refactor/rust-module-split`  
**Risk:** Medium  
**Dependencies:** T2–T4

## Goal

Make native code reviewable and independently testable.

## Suggested module layout

```text
ext/dry_validation_rust/src/
  lib.rs
  engine.rs
  plan.rs
  validation.rs
  traversal.rs
  coercion.rs
  predicates.rs
  errors.rs
  ruby_bridge.rs
  runtime_classes.rs
  tests/
```

Possible responsibilities:

- `lib.rs`: extension initialization and Ruby class/module definitions only.
- `engine.rs`: `Engine` lifecycle and call orchestration.
- `plan.rs`: serde models, engine version, structural validation.
- `validation.rs`: validation result types and high-level flow.
- `traversal.rs`: nested hash/array traversal and paths.
- `coercion.rs`: Params/JSON/plain coercion rules.
- `predicates.rs`: native predicate evaluation.
- `errors.rs`: internal errors and Ruby error mapping.
- `ruby_bridge.rs`: all direct Ruby method calls and exception classification.
- `runtime_classes.rs`: Date/DateTime/Time/BigDecimal lookup requirements.

## Rules

- No public Ruby behavior change.
- Prefer moving code before redesigning it.
- Keep commits separable:
  1. module extraction;
  2. visibility cleanup;
  3. unit-test relocation;
  4. naming cleanup.
- Avoid introducing new caching in this phase.
- `lib.rs` should become small enough to understand extension initialization at a glance.

## Tests

- Full baseline.
- Rust unit tests after each extraction.
- Compare baseline fixtures byte-for-byte.
- Build extension in debug and release modes.
- Run Clippy with warnings denied.

## Acceptance criteria

- `lib.rs` primarily initializes the extension.
- Each semantic area has focused unit tests.
- No behavior or benchmark regression beyond noise.
- No cyclic module dependencies.
- Ruby API remains unchanged.

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
