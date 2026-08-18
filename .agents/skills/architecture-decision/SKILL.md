---
name: Architecture Decision
description: >
  Resolve one durable cross-cutting design decision that blocks safe
  implementation. Compare realistic options, make the smallest necessary
  decision, and create an ADR only when the repository's ADR threshold is met.
  Do not use for routine class design, local refactoring, or ordinary feature
  implementation.
---
# Skill: Architecture decision

Use this skill only when implementation cannot proceed safely without resolving a durable, cross-cutting choice.

## ADR threshold

An ADR is justified only when the decision is:

- durable;
- cross-cutting;
- costly to reverse;
- likely to affect several future capabilities;
- likely to be reopened by multiple contributors.

Routine method extraction, naming, class decomposition, dependency use, or one feature's internal design does not qualify.

## Workflow

1. State the blocking decision in one sentence.
2. Identify non-negotiable constraints:
   - public Ruby behavior;
   - dry-validation compatibility;
   - correctness and failure semantics;
   - Rust/Ruby ownership;
   - performance only where evidence makes it relevant;
   - packaging and maintainability where relevant.
3. Inspect the minimum current code, tests, compatibility evidence, and architecture context needed.
4. Compare 2–4 realistic options.
5. Evaluate each option for:
   - compatibility risk;
   - reversibility;
   - implementation complexity;
   - testability;
   - native/FFI implications;
   - operational or packaging impact.
6. Choose the smallest durable decision needed to unblock implementation.
7. If the ADR threshold is met, record one concise ADR containing:
   - context;
   - decision;
   - consequences;
   - alternatives considered.
8. Recommend the primary implementation skill for the follow-up and stop.

## Rules

- Do not implement the resulting feature in the same phase unless explicitly requested.
- Do not invent future extension points to justify an architecture.
- Prefer a reversible local decision when a cross-cutting commitment is unnecessary.
- Compatibility evidence outranks architectural elegance.
- Keep the decision narrower than the surrounding roadmap.

## Delivery

Return the decision, constraints, alternatives, rationale, consequences, and the next implementation task.
