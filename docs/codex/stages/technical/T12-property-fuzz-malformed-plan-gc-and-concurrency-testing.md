# Codex stage T12: property, fuzz, malformed-plan, GC, and concurrency testing

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Repository context

Work in the current `dry-validation-rust` repository. Inspect the branch, implementation, tests, documentation, and recent related changes before editing. Do not assume every path or API named below is still exact.

## Assignment

Implement only this technical-polishing stage. Keep it suitable for one focused pull request. When the stage is explicitly large, split it into the smallest dependency-ordered PRs and complete only the first coherent PR unless the user explicitly asks for the whole sequence.

**Priority:** P1/P2  
**Suggested branches:** separate by test type  
**Risk:** Medium  
**Dependencies:** T2–T6

## Property tests

Generate supported schema plans and payloads. Assert:

- execution never panics;
- identical immutable contract/input gives stable output;
- output contains only declared normalized keys;
- error paths are valid;
- a successful coerced value has the promised Ruby type;
- missing and present/nil remain distinguishable;
- Rust and upstream agree for the supported generated subset.

Use a Ruby property library or a small custom generator. Keep seeds reproducible.

## Rust fuzz targets

Suggested targets:

```text
fuzz_plan_json
fuzz_plan_validation
fuzz_scalar_coercion
fuzz_nested_traversal
```

Properties:

- no panic;
- no unbounded allocation from small malicious inputs;
- invalid plans return errors;
- recursion/size limits behave predictably.

## GC tests

Especially important if Ruby objects/classes are cached:

- repeated `GC.start`;
- `GC.compact` where supported;
- create/drop many engines;
- call contracts after compaction;
- validate regex and Ruby predicate argument lifetime;
- verify no use-after-free or missing mark function.

## Concurrency tests

- many Ruby threads using one compiled contract;
- many contracts in parallel;
- concurrent calls with distinct contexts;
- Ractor behavior should be either tested and supported or explicitly unsupported;
- fork behavior should be documented if relevant.

## Safety limits

Consider explicit limits for:

- schema nesting;
- plan bytes;
- field count;
- runtime data depth;

only if denial-of-service or stack-safety tests justify them. Limits must be documented.

## Acceptance criteria

- Fuzzing runs for a documented minimum duration in scheduled/manual CI.
- Every discovered crash becomes a deterministic regression test.
- GC compaction tests pass on supported Ruby versions.
- Concurrency claims match actual tests.
- No “thread-safe” claim is interpreted as GVL-free parallelism.

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
