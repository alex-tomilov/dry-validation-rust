---
name: Bug Fix

description: >
  Reproduce one defect, identify the root cause,
  implement the smallest correct fix,
  add regression coverage,
  and avoid unrelated refactoring.

  Do not use for feature development
  or broad code cleanup.
---

# Skill: Bug fix

Use this skill for one reproducible defect class.

## Workflow

1. Reproduce the defect with the smallest failing test or command.
2. Identify the violated invariant and the narrowest root cause.
3. Fix the cause, not only the observed symptom.
4. Add a regression test at the lowest useful level.
5. Check adjacent cases likely to share the root cause.
6. Run focused and canonical verification.
   If Ruby files, tests, tooling, or CI configuration changed, also run
   `bundle exec rubocop`; do not report completion while it fails.
7. For a user-visible fix, add a concise entry under `Unreleased` in
   `CHANGELOG.md`. For an internal-only fix, record that the PR needs the
   `no-changelog` label. Update documentation only if previously documented
   behavior was wrong or the user-facing workaround changed. If the fix changes
   a public Ruby API or its documented behavior, update its inline YARD
   documentation and run `bundle exec yard --fail-on-warning`.

## Rules

- Do not perform broad cleanup while fixing the defect.
- Do not rewrite tests to match incorrect behavior.
- Do not catch broad exceptions unless the public contract requires it.
- Do not create a postmortem or ADR unless the defect reveals a durable cross-cutting design decision.

## Delivery

Report reproduction, root cause, fix, regression coverage, and remaining risk.
