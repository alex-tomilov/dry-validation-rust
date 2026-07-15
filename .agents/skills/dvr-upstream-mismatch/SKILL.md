---
name: dvr-upstream-mismatch
description: Classify and resolve differential mismatches between dry-validation-rust and pinned upstream dry-validation or dry-schema behavior. Trigger whenever the compatibility harness reports differing outputs, errors, exceptions, loading behavior, or definition behavior.
---

# Upstream mismatch classification

Before changing code, classify the mismatch as:

- implementation bug;
- intentional documented difference;
- unsupported feature;
- pinned-upstream version difference;
- harness or canonicalization bug;
- nondeterministic or user-defined behavior.

Required analysis:

1. identify the exact semantic difference;
2. inspect pinned upstream behavior and local implementation;
3. state the relevant compatibility promise;
4. determine the smallest correction;
5. define a deterministic regression scenario.

Rules:

- Change runtime code only for an implementation bug.
- Change the harness only for a demonstrated harness/canonicalization bug.
- Update `COMPATIBILITY.md` for intentional or unsupported differences.
- Do not change behavior to match an unpinned upstream branch.
- Do not weaken comparisons merely to turn the suite green.
- Finish with `dvr-delivery-gate`.
