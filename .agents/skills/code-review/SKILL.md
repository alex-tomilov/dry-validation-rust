---
name: Code Review

description: >
  Review an implementation for correctness,
  safety,
  maintainability,
  compatibility,
  and unnecessary complexity.

  Prioritize user-visible issues over style,
  and avoid requesting unrelated changes.
---

# Skill: Code review

Use this skill to review a proposed diff without expanding its scope.

## Review order

1. correctness and user-visible semantics;
2. safety, error handling, data loss, concurrency, and resource lifetime;
3. compatibility and migration impact;
4. missing focused tests;
5. unnecessary complexity or abstraction;
6. performance regressions where relevant;
7. documentation accuracy;
8. style only when it affects maintainability.

## Output

List findings by severity with file/line references, consequence, and smallest reasonable fix.

Do not:

- demand unrelated refactoring;
- request new documents without a concrete information need;
- require exhaustive tests for unchanged behavior;
- turn preferences into blockers;
- restate the whole diff.

If no material issue exists, say so and mention residual risks or untested areas briefly.
