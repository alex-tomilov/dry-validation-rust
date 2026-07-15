# Codex stage T11: replace the benchmark smoke test with a benchmark suite

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Repository context

Work in the current `dry-validation-rust` repository. Inspect the branch, implementation, tests, documentation, and recent related changes before editing. Do not assume every path or API named below is still exact.

## Assignment

Implement only this technical-polishing stage. Keep it suitable for one focused pull request. When the stage is explicitly large, split it into the smallest dependency-ordered PRs and complete only the first coherent PR unless the user explicitly asks for the whole sequence.

**Priority:** P1  
**Suggested branch:** `perf/benchmark-suite`  
**Risk:** Low  
**Dependencies:** T0

## Proposed layout

```text
benchmark/
  README.md
  runner.rb
  scenarios/
    shallow_valid.rb
    shallow_invalid.rb
    wide_schema.rb
    deep_schema.rb
    arrays_primitives.rb
    arrays_hashes.rb
    coercions.rb
    rules_heavy.rb
    predicates_native.rb
    predicates_ruby.rb
    result_queries.rb
    compilation.rb
  support/
    statistics.rb
    process_runner.rb
    rss.rb
  results/.gitkeep
```

## Measurements

- validations/second;
- median latency;
- p95/p99 where sample method is appropriate;
- standard deviation or robust dispersion;
- allocated Ruby objects;
- GC count/time where available;
- peak RSS;
- schema compilation time;
- native plan bytes;
- source/native gem size.

## Methodology

- run engines in separate processes;
- pin upstream versions;
- print all environment versions;
- warm up;
- repeat complete samples;
- randomize engine order where helpful;
- output JSON and human-readable summaries;
- never make shared-runner performance a blocking CI check.

## Regression budgets

Use local or dedicated runners for performance gates. Example starting policy:

- correctness PR: no >10% median regression in a target scenario without explanation;
- performance PR: target scenario improves >10% across repeated runs;
- release report: provide raw samples and hardware details.

These values are initial policy suggestions, not universal truth. Adjust after observing noise.

## Acceptance criteria

- One command runs all scenarios.
- One command runs a selected scenario and engine.
- Output is machine-readable.
- Results include environment metadata.
- README explains why results are not universal.
- Public claims can be traced to stored raw results.

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
