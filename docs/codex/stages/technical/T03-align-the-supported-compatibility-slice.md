# Codex stage T03: align the supported compatibility slice

**Priority:** P0/P1  
**Dependencies:** `T02`

## Assignment

Define and close one coherent gap in the supported dry-validation-style API at
a time, using separate-process differential tests against pinned upstream
versions. Audit existing `maybe`, `filled`, predicates, rules, messages, and
composition before implementing anything named by the roadmap.

## Work

- Maintain an executable case inventory for supported and intentional-difference
  behavior.
- Add high-value built-in predicates in ownership-based slices: declarative
  native operations in Rust, arbitrary Ruby semantics in Ruby.
- Align `maybe`, `filled`, `value`, coercion modes, ordered errors, rule behavior,
  and schema composition only where a differential mismatch is demonstrated.
- Design custom predicates and localization as Ruby-owned features with stable
  compiled metadata; implement them as separate focused pull requests.

## Files

Compatibility harness/fixtures, Ruby DSL/evaluator/message code, native plan and
predicate code, and the canonical compatibility matrix.

## Scope control

No claim of “full predicate set,” “drop-in replacement,” or percentage parity.
Unknown predicates never pass through Rust for later handling unless the plan
explicitly records and validates a Ruby-owned operation.

## Acceptance criteria

- Every compatibility change has pinned upstream pass/fail/boundary evidence.
- Unexpected Ruby exceptions remain exceptions.
- Unsupported behavior stays explicit and tested.
- Documentation changes only the canonical compatibility claim affected.
