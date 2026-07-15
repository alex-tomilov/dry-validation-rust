# Codex stage T03: correct Ruby exception handling across the Rust boundary

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Repository context

Work in the current `dry-validation-rust` repository. Inspect the branch, implementation, tests, documentation, and recent related changes before editing. Do not assume every path or API named below is still exact.

## Assignment

Implement only this technical-polishing stage. Keep it suitable for one focused pull request. When the stage is explicitly large, split it into the smallest dependency-ordered PRs and complete only the first coherent PR unless the user explicitly asks for the whole sequence.

**Priority:** P0  
**Suggested branch:** `fix/native-exception-propagation`  
**Risk:** High  
**Dependencies:** T2

## Problem

A conversion or predicate operation may call Ruby. Expected invalid-input exceptions may become validation errors, but unexpected exceptions must propagate.

Broad `.ok()`, `unwrap_or(false)`, or `unwrap_or(default)` behavior can hide:

- user-defined method failures;
- monkey-patched core behavior;
- encoding errors;
- programmer errors;
- internal extension defects.

## Semantic policy

Define and document:

| Operation | Expected invalid input | Unexpected Ruby exception |
|---|---|---|
| `Integer`, `Float`, date/time, decimal coercion | produce type/coercion validation error | re-raise |
| comparison predicate | ordinary false result creates validation error | re-raise method exception |
| `size` predicate | unsupported type or false size condition creates documented error | re-raise method exception |
| `odd?` / `even?` | false creates validation error | re-raise method exception |

Expected exception classes must be explicit. Usually `ArgumentError` and `TypeError` are candidates, but verify upstream behavior before finalizing.

## Implementation steps

1. Centralize Ruby calls in `ruby_bridge.rs`.
2. Add helpers such as:
   - `call_coercion`;
   - `call_predicate`;
   - `classify_exception`.
3. Preserve the original Ruby exception object and backtrace.
4. Do not create a new generic exception unless the failure is an extension-specific plan/build error.
5. Remove silent fallbacks one category at a time.
6. Add comments explaining each intentionally swallowed exception class.
7. Ensure Rust errors do not panic when converted back to Ruby.

## Tests

Create custom Ruby objects whose methods raise distinct exceptions:

```ruby
Class.new do
  def >(other)
    raise RuntimeError, "comparison exploded"
  end
end
```

Test:

- `>` raises `RuntimeError`;
- `size` raises custom error;
- `odd?` raises custom error;
- date conversion of invalid text becomes validation failure;
- a monkey-patched conversion raising an unexpected error propagates;
- backtrace includes the Ruby method that raised;
- no exception is converted into an unrelated predicate message.

## Acceptance criteria

- Expected malformed user input remains a validation result.
- Unexpected Ruby exceptions propagate unchanged where technically possible.
- No silent `unwrap_or`-style semantic fallback remains in Ruby-call paths.
- Exception behavior is documented and regression-tested.
- No Rust panic crosses FFI.

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
