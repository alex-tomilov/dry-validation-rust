# Codex stage R09: project planning and issue hygiene

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Repository context

Work in the current `dry-validation-rust` repository. Inspect the branch, implementation, tests, documentation, and recent related changes before editing. Do not assume every path or API named below is still exact.

## Assignment

Implement only this public-repository maturity stage. Keep it suitable for one focused pull request. When the stage is explicitly large, split it into the smallest dependency-ordered PRs and complete only the first coherent PR unless the user explicitly asks for the whole sequence.

**Priority:** P1  
**Suggested branch:** `docs/project-management`

## Labels

Recommended:

```text
type:bug
type:compatibility
type:performance
type:feature
type:documentation
type:security
type:maintenance

priority:p0
priority:p1
priority:p2
priority:p3

area:ruby-dsl
area:rust-engine
area:ffi
area:rules
area:messages
area:compatibility
area:benchmark
area:packaging
area:ci
area:docs

status:needs-reproduction
status:blocked
status:needs-design
status:good-first-issue

breaking-change
upstream-difference
```

## Milestones

```text
0.1 alpha — correctness foundation
0.1 beta — compatibility and benchmark evidence
0.1 RC — native packaging and release readiness
1.0 — stable API and support policy
Future — experimental batch API
```

## Issue quality

Every implementation issue should include:

- problem;
- user impact;
- current behavior;
- desired behavior;
- non-goals;
- affected files;
- implementation notes;
- tests;
- acceptance criteria;
- dependencies;
- risk/rollback.

## Project board

Columns:

```text
Backlog
Ready
In progress
Review
Blocked
Done
```

Limit work in progress to one or two Codex implementation tasks.

## Acceptance criteria

- Roadmap items map to issues and milestones.
- P0 work is visible and ordered.
- No huge “make production ready” issue exists without decomposition.
- Contributors can identify small safe tasks.

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
