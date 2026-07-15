# Codex stage T08: cache finalized result/message views

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Repository context

Work in the current `dry-validation-rust` repository. Inspect the branch, implementation, tests, documentation, and recent related changes before editing. Do not assume every path or API named below is still exact.

## Assignment

Implement only this technical-polishing stage. Keep it suitable for one focused pull request. When the stage is explicitly large, split it into the smallest dependency-ordered PRs and complete only the first coherent PR unless the user explicitly asks for the whole sequence.

**Priority:** P1  
**Suggested branch:** `perf/result-message-cache`  
**Risk:** Low–Medium  
**Dependencies:** T0

## Problem

`Result#errors`, `success?`, `failure?`, `error?`, and `inspect` can rebuild message collections repeatedly.

## Target behavior

Before `finalize!`:

- rule errors may be appended internally.

After `finalize!`:

- default combined messages are built once;
- the result is immutable except for explicitly documented context behavior;
- repeated `success?` and default `errors` calls do not allocate full new collections.

## Implementation steps

1. Decide result lifecycle and document it.
2. In `finalize!`, freeze rule messages and build the default `MessageSet`.
3. Cache default errors.
4. Keep option-specific message views lazy.
5. Cache or normalize parsed error-query paths where reasonable.
6. Consider freezing output/values only if compatible with upstream expectations.
7. Do not accidentally freeze caller-provided context unless the API promises it.

## Tests

- repeated `errors.object_id` behavior if a stable object is promised;
- repeated `success?` allocation smoke check;
- options still return correct filtered/full messages;
- errors cannot be added after finalize;
- context behavior is explicit;
- pattern matching still works;
- inspect output is unchanged or intentionally documented.

## Acceptance criteria

- Default message combination happens once per result.
- Rule errors cannot mutate after finalization.
- Public behavior matches the compatibility policy.
- Allocation benchmark shows improvement in repeated-result-query scenarios.

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
