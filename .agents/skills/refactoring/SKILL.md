---
name: Refactoring
description: >
  Improve the internal structure of existing code without changing
  externally observable behavior. Use this skill to reduce complexity,
  remove proven duplication, clarify ownership, improve readability,
  or simplify maintenance while preserving current semantics. Do not
  use it to add features, change public behavior, redesign unrelated
  architecture, or perform broad repository cleanup.
---

# Refactoring

## Purpose

Improve the structure of existing code while preserving its observable behavior.

A successful refactoring should make the code easier to understand, test, modify, or operate without introducing new product capabilities.

## Use this skill when

Use this skill for work such as:

- extracting a focused method, class, or module;
- reducing concrete duplication;
- simplifying complex control flow;
- clarifying responsibilities between existing components;
- replacing an unsafe or confusing implementation with an equivalent one;
- improving naming and local readability;
- removing dead code that is proven unused;
- consolidating repeated behavior behind an existing abstraction;
- preparing a narrow area for an already-approved feature.

## Do not use this skill for

Do not use this skill for:

- adding user-visible behavior;
- changing public API semantics;
- broad architecture redesign;
- implementing speculative extension points;
- introducing a framework for anticipated future features;
- repository-wide cleanup;
- formatting unrelated files;
- reorganizing documentation;
- changing dependencies without a direct refactoring need;
- combining refactoring with several bug fixes or features.

When observable behavior must change, use the feature-delivery or bug-fix skill instead.

## Core rule

Externally observable behavior must remain unchanged.

Observable behavior can include:

- return values;
- raised exceptions;
- error messages when they are part of the supported contract;
- side effects;
- ordering;
- persistence behavior;
- logging relied upon operationally;
- public method signatures;
- serialization formats;
- performance characteristics with operational significance;
- thread-safety and resource-lifetime behavior.

Do not assume behavior is internal merely because it is undocumented.

## Before editing

Inspect the relevant implementation and tests.

State:

1. the structural problem;
2. the behavior that must remain unchanged;
3. the smallest affected area;
4. the expected files to change;
5. the verification plan;
6. explicit non-goals.

Do not begin with a repository-wide cleanup.

## Decision tree

### Is observable behavior expected to change?

- Yes: stop using this skill and use feature-delivery or bug-fix.
- No: continue.

### Is there a concrete maintenance problem?

Examples include duplication, excessive branching, unclear ownership, unsafe lifetime handling, or difficult testing.

- No: do not refactor merely for stylistic preference.
- Yes: continue.

### Is a new abstraction necessary?

- No: prefer a local simplification.
- Yes: verify that at least two concrete existing cases need the abstraction.

Do not create an abstraction only for hypothetical future use.

### Can the refactoring be separated from feature work?

- Yes: keep it separate.
- No: limit the refactoring to what is strictly necessary for the approved feature and use the feature-delivery skill.

## Workflow

### 1. Establish current behavior

Use existing tests and, when necessary, add characterization tests before changing implementation.

Characterization tests should protect meaningful behavior, not incidental private structure.

### 2. Identify the narrowest transformation

Choose the smallest structural change that solves the concrete problem.

Prefer:

- local method extraction;
- clearer data flow;
- removal of duplicated branches;
- explicit ownership;
- smaller responsibilities;
- reuse of an existing pattern.

Avoid:

- broad rewrites;
- new framework layers;
- unrelated renaming;
- migration to a new architecture during an ordinary refactoring.

### 3. Refactor incrementally

Keep the code working after each meaningful step.

Do not mix several independent transformations into one large diff.

A useful sequence is:

1. add characterization coverage;
2. move or extract code without semantic changes;
3. simplify the resulting structure;
4. remove obsolete implementation;
5. run focused verification;
6. run the canonical project checks.

### 4. Preserve interfaces

Do not change public names, arguments, defaults, return types, exception behavior, or supported input unless explicitly approved.

When an internal interface must change, update all callers in the same coherent slice.

### 5. Verify behavior

Run:

- focused tests for the affected area;
- regression tests for characterized behavior;
- integration tests covering the public flow;
- the repository's canonical verification command.

For performance-sensitive code, compare representative before-and-after measurements when the structural change could materially affect performance.

### 6. Update documentation only when necessary

Ordinary internal refactoring should not require documentation changes.

Update documentation only when:

- architecture ownership or data flow changed materially;
- operational behavior changed despite preserving the public API;
- existing architecture documentation would become inaccurate.

Do not create:

- a refactoring report;
- a completed-task document;
- documentation meta-tests;
- a new ADR for a routine local transformation.

## Scope guardrails

An ordinary refactoring should normally affect:

- one subsystem or responsibility;
- one structural problem;
- no more than one new abstraction;
- no public capability;
- no unrelated documentation;
- no unrelated dependencies.

If the task expands into multiple subsystems, split it into independently reviewable changes.

## Tests

Prefer tests that protect:

- public behavior;
- important integration flows;
- regressions;
- safety boundaries;
- state and side-effect behavior.

Avoid tests that lock in:

- private method names;
- internal class layout;
- exact helper call sequences;
- file organization;
- implementation-specific object graphs;
- formatting or documentation structure.

Do not delete meaningful tests merely because they make refactoring difficult.

## Removing dead code

Remove code only when its lack of use is established through evidence such as:

- repository-wide call-site search;
- runtime instrumentation;
- test and application-path inspection;
- deprecation history;
- unreachable control flow.

Do not remove code solely because no nearby caller is visible.

## New abstractions

Introduce a new abstraction only when all of the following are true:

- at least two existing concrete cases share meaningful behavior;
- the shared responsibility has a clear name;
- ownership and failure behavior are clear;
- total conceptual complexity decreases;
- the abstraction does not promise unsupported future extensibility.

Prefer small explicit duplication over a premature general framework.

## Stop conditions

Stop and report instead of expanding implementation when:

- required behavior cannot be determined;
- tests reveal an existing defect that needs a separate bug-fix task;
- the change requires public API modification;
- more than one subsystem must be redesigned;
- a new framework or extension system would be required;
- the expected change exceeds the repository scope guardrails;
- performance or concurrency semantics cannot be preserved confidently;
- the task has become feature development.

Stopping is a valid result.

Recommend the smallest next task without implementing it.

## Definition of done

The refactoring is complete when:

- observable behavior is preserved;
- focused and canonical checks pass;
- the concrete structural problem is reduced;
- complexity is not merely moved elsewhere;
- no speculative infrastructure is introduced;
- no unrelated cleanup is included;
- affected documentation remains accurate;
- the diff is independently reviewable.

## Completion report

Report only:

1. structural problem addressed;
2. behavior preserved;
3. important files changed;
4. tests and checks run;
5. remaining risks or limitations;
6. follow-up ideas intentionally not implemented.

Do not create a separate report file unless explicitly requested.
