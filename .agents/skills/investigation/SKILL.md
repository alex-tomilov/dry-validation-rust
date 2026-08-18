---
name: Investigation
description: >
  Inspect, reproduce, characterize, or evaluate one engineering question
  without modifying production implementation files. Use this skill when the
  root cause, compatibility behavior, feasibility, architecture boundary, or
  performance mechanism is not yet known. Produce evidence and recommend the
  smallest next implementation task. Do not use this skill to implement the
  discovered solution.
---
# Skill: Investigation

Use this skill when implementation should not begin until one uncertain question is answered.

## Workflow

1. State the exact question being investigated.
2. Inspect only the implementation, tests, fixtures, documentation, history, or external reference needed to answer it.
3. Reproduce the current behavior with the smallest useful command, test, script, or benchmark.
4. When compatibility is involved, identify the pinned reference version or contract and compare observable behavior directly.
5. Separate:
   - confirmed facts;
   - hypotheses or inferences;
   - unresolved uncertainty.
6. Identify the narrowest root cause, feasibility constraint, or architecture boundary supported by the evidence.
7. Recommend the smallest next task and its primary implementation skill.
8. Report commands/evidence used and stop.

## Allowed changes

By default, do not modify production implementation files.

If the investigation explicitly requires a durable characterization fixture or regression reproduction, add only the smallest test/fixture needed to preserve the discovered behavior. Do not implement the fix.

## Rules

- Do not guess when executable evidence is available.
- Do not turn an investigation into feature delivery, a bug fix, refactoring, or optimization.
- Do not create a broad roadmap or permanent investigation report.
- Do not create an ADR unless a durable cross-cutting decision is actually required.
- Do not expand into unrelated discoveries.

## Delivery

Report the question, evidence, confirmed findings, unresolved uncertainty, and the recommended next task/skill.
