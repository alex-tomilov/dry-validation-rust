# Codex stage T09: normalize rule paths and compile rule metadata once

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Repository context

Work in the current `dry-validation-rust` repository. Inspect the branch, implementation, tests, documentation, and recent related changes before editing. Do not assume every path or API named below is still exact.

## Assignment

Implement only this technical-polishing stage. Keep it suitable for one focused pull request. When the stage is explicitly large, split it into the smallest dependency-ordered PRs and complete only the first coherent PR unless the user explicitly asks for the whole sequence.

**Priority:** P1  
**Suggested branch:** `perf/compiled-rule-plans`  
**Risk:** Medium  
**Dependencies:** T1, T6

## Goal

Avoid repeated path parsing and make rules immutable.

## Target

Replace mutable/loosely structured rule internals with a compiled `RulePlan` containing:

- frozen canonical paths;
- `each` mode;
- macro calls;
- block;
- precomputed dependency lookup metadata.

## Steps

1. Normalize all rule specifications at class definition time.
2. Freeze path arrays and macro argument arrays where safe.
3. Validate paths against immutable schema key paths once.
4. Ensure inherited rules cannot be mutated through parent/child sharing.
5. Precompute data needed by `rule.each`.
6. Keep arbitrary blocks as Ruby callables.

## Tests

- all supported path syntaxes;
- inheritance;
- macro mutation attempts;
- invalid path errors;
- array placeholders;
- rule order;
- class re-opening behavior if supported;
- thread-safe concurrent calls.

## Acceptance criteria

- No repeated `Path.parse` in the call hot path for rule definitions.
- Rules are immutable after definition.
- Parent and child rule collections do not share mutable containers.
- Differential behavior is unchanged.

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
