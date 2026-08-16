---
name: Feature Delivery

description: >
  Implement one independently useful user-visible capability as the
  smallest reviewable vertical slice.

  Use for ordinary feature development.

  Do not use for release preparation, repository cleanup,
  documentation-only work, architecture redesign,
  or implementing multiple backlog features at once.
---

# Skill: Feature delivery

Use this skill to implement one user-visible capability.

## Input required

- desired behavior or example;
- explicit included scope;
- explicit non-goals;
- acceptance criteria.

If some input is absent, infer the narrowest useful scope from the issue and existing code. Do not broaden the task.

## Workflow

1. Inspect the current public path, tests, and nearest implementation pattern.
2. Restate the smallest vertical slice and likely files before editing.
3. Add or update a focused behavioral test.
4. Implement the direct path.
5. Add explicit validation or failure behavior at adjacent unsupported boundaries.
6. Run focused checks, then the repository's canonical verification.
   If Ruby files, tooling, or CI configuration changed, also run
   `bundle exec rubocop` and resolve or explicitly report any offenses.
7. Update only documentation whose truth changed. When the slice adds or
   changes a public Ruby API, add or update its inline YARD documentation and
   run `bundle exec yard --fail-on-warning`.
8. Report follow-up ideas without implementing them.

## Definition of done

- the requested example works;
- invalid and boundary cases behave deliberately;
- focused and existing tests pass;
- no unrelated refactoring or infrastructure was added;
- public documentation is accurate where affected;
- the diff remains independently reviewable.

## Stop conditions

Stop and report instead of expanding scope when:

- more than one public capability is required;
- a new general subsystem is needed;
- expected size exceeds AGENTS.md guardrails;
- semantics are ambiguous and cannot be established from existing contracts;
- safety requires an architectural decision.
