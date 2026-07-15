---
name: dvr-failure-diagnosis
description: Diagnose failed dry-validation-rust tests, builds, native compilation, CI jobs, package installation, or verification commands before editing. Trigger whenever an implementation or check fails unexpectedly.
---

# Failure diagnosis

Before editing, classify the failure as:

- implementation defect;
- incorrect test assumption;
- environment or toolchain problem;
- pre-existing repository failure;
- compatibility-policy ambiguity;
- flaky or nondeterministic test.

Report:

1. primary root cause;
2. evidence;
3. smallest correction;
4. risk that the correction could mask a real defect;
5. exact proof checks.

Then implement only the smallest correction.

Rules:

- Do not weaken a test merely to pass.
- Do not skip a failing platform without changing the documented support matrix.
- Do not replace an unexpected exception with a validation result.
- Rerun the failed check, its nearest suite, and canonical full verification.
- Finish with `dvr-delivery-gate`.
