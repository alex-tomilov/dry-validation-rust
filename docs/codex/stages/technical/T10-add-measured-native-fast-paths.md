# Codex stage T10: add measured native fast paths

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Repository context

Work in the current `dry-validation-rust` repository. Inspect the branch, implementation, tests, documentation, and recent related changes before editing. Do not assume every path or API named below is still exact.

## Assignment

Implement only this technical-polishing stage. Keep it suitable for one focused pull request. When the stage is explicitly large, split it into the smallest dependency-ordered PRs and complete only the first coherent PR unless the user explicitly asks for the whole sequence.

**Priority:** P1  
**Suggested branch:** `perf/native-core-fast-paths`  
**Risk:** High  
**Dependencies:** T3, T6, T9, benchmark harness

## Principle

Do not assume that “implemented in Rust” is faster. Some native predicates still dispatch Ruby methods. Optimize only measured hotspots while preserving Ruby semantics.

## Candidate fast paths

- exact core `Integer` comparison;
- exact core `Float` comparison;
- exact core `String` length/emptiness;
- exact core `Array` and `Hash` size;
- direct symbol/string key lookup where Magnus provides safe APIs;
- precomputed runtime-class requirements;
- reduced path allocation;
- capacity reservation for output hashes/vectors where possible.

## Semantic fallback

For subclasses, custom objects, or uncertain semantics:

- call Ruby;
- preserve exceptions;
- retain upstream-compatible dispatch.

A possible policy:

```text
known exact core class -> Rust fast path
subclass/custom object -> Ruby semantic fallback
```

Verify whether exact-class checks themselves cost more than the saved dispatch for small cases.

## Benchmark protocol

For every optimization:

1. Add a focused microbenchmark.
2. Add a representative contract benchmark.
3. Run enough samples in fresh processes.
4. Record median, variation, allocations, and RSS.
5. Run compatibility fixtures.
6. Keep the optimization only if:
   - behavior remains correct;
   - improvement is reproducible;
   - complexity is justified.

## Acceptance criteria

- Every fast path has a semantic fallback test.
- Custom-object behavior remains correct.
- No unexpected Ruby exception is swallowed.
- The change improves its target benchmark beyond the agreed noise threshold.
- No major regression appears in other benchmark groups.

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
