# Codex stage T04: support arbitrary-precision Ruby integers

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Repository context

Work in the current `dry-validation-rust` repository. Inspect the branch, implementation, tests, documentation, and recent related changes before editing. Do not assume every path or API named below is still exact.

## Assignment

Implement only this technical-polishing stage. Keep it suitable for one focused pull request. When the stage is explicitly large, split it into the smallest dependency-ordered PRs and complete only the first coherent PR unless the user explicitly asks for the whole sequence.

**Priority:** P0  
**Suggested branch:** `fix/big-integer-coercion`  
**Risk:** Medium  
**Dependencies:** T3

## Goal

Match Ruby integer semantics rather than limiting Params coercion to `i64`.

## Recommended strategy

Use a fast path plus semantic fallback:

1. Parse normal values into `i64` when possible.
2. On numeric overflow, use Ruby's strict integer conversion.
3. Preserve arbitrary-precision `Integer`.
4. Reject malformed strings exactly as the documented Params mode requires.
5. Do not accept formats that upstream rejects merely because a Rust parser accepts them.

## Cases to test

- `0`, positive, negative;
- `i64::MIN`, `i64::MAX`;
- one below/above those boundaries;
- hundreds or thousands of digits;
- leading plus/minus;
- whitespace;
- underscores;
- decimal points;
- exponent notation;
- hexadecimal-looking strings;
- empty string;
- non-UTF-8 Ruby strings, if reachable;
- custom objects with conversion methods.

Use upstream differential fixtures to determine intended syntax, not intuition.

## Performance test

Compare:

- small integer fast path;
- overflow fallback;
- invalid input;
- upstream dry-schema behavior.

The small integer path must not become materially slower merely to support rare huge integers.

## Acceptance criteria

- Valid arbitrary-precision integer strings produce Ruby `Integer`.
- Boundary behavior matches the pinned upstream reference or is explicitly documented.
- Small integer throughput remains within the agreed regression budget.
- Invalid formats produce stable validation errors rather than exceptions, except where upstream itself raises.

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
