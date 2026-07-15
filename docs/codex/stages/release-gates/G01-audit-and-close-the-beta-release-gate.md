# Codex release-gate stage G01: Audit and close the beta release gate

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Assignment

Audit the current repository against the gate below, then implement only the smallest remaining blocker that can safely form one focused pull request.

First return a pass/fail/partial evidence table. Do not count documentation claims as proof without code, tests, CI, package, or artifact evidence.

# 6. Beta release gate

In addition to alpha gates:

## Compatibility

- [ ] every “supported” compatibility row links to executable scenarios;
- [ ] rule/macro/options/context/result scenarios are substantial;
- [ ] mismatch report has no unresolved P0 items;
- [ ] intentional differences are explicit.

## Maintainability

- [ ] Rust module split complete;
- [ ] Ruby builder/plan/rule lifecycle is documented;
- [ ] public/internal APIs are distinguishable;
- [ ] deprecation process drafted.

## Performance

- [ ] multi-scenario benchmark suite;
- [ ] raw result format;
- [ ] environment metadata;
- [ ] at least one representative real-world-shaped workload;
- [ ] no absolute “faster than dry-validation” claim;
- [ ] Ruby-rule-heavy limitations shown.

## Robustness

- [ ] property testing;
- [ ] scheduled/manual fuzzing;
- [ ] GC start/compaction tests;
- [ ] broader concurrency tests;
- [ ] dependency audits and update automation.

## Packaging

- [ ] at least one native Linux artifact clean-installed without Rust;
- [ ] native/source fallback behavior documented.

---

## Required output before editing

1. Gate checklist with exact evidence paths.
2. Blocking findings ordered by severity.
3. Missing evidence versus known failure.
4. Recommended issue/PR decomposition.
5. The single focused blocker selected for this run.

## Implementation rule

Implement only the selected blocker, add tests, run full verification, and update the gate table. Do not publish, tag, release, or change repository settings.

## Final response

Include the updated gate status, remaining blockers, exact tests, risks, and no-release confirmation.
