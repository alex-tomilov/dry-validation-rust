# Codex stage T13: evaluate a future batch/GVL-releasing API

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Repository context

Work in the current `dry-validation-rust` repository. Inspect the branch, implementation, tests, documentation, and recent related changes before editing. Do not assume every path or API named below is still exact.

## Assignment

Implement only this technical-polishing stage. Keep it suitable for one focused pull request. When the stage is explicitly large, split it into the smallest dependency-ordered PRs and complete only the first coherent PR unless the user explicitly asks for the whole sequence.

**Priority:** P3  
**Do not implement before:** stable normal API and benchmark evidence

## Hypothesis

A separate batch API could copy a restricted value subset into Rust-owned memory, release the GVL, validate many payloads, and convert results back.

## Required research

- serialization/copy cost;
- supported Ruby value subset;
- error reconstruction cost;
- ordering guarantees;
- cancellation;
- maximum batch size;
- memory amplification;
- whether Rayon or explicit worker threads help;
- compatibility limitations.

## Decision gate

Proceed only when:

- ordinary contract validation is mature;
- users have a real batch use case;
- a prototype beats normal calls after copy overhead;
- the API is clearly separate and does not silently change semantics.

This phase should not delay public alpha/beta of the core hybrid engine.

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
