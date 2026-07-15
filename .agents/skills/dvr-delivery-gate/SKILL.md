---
name: dvr-delivery-gate
description: Mandatory post-implementation review, focused remediation, verification, and PR-summary workflow for dry-validation-rust changes. Trigger after any task changes code, tests, CI, packaging, compatibility behavior, or public documentation, before returning the final response.
---

# dry-validation-rust delivery gate

Apply this workflow after implementation and before the final response.

## 1. Confirm scope

- Restate the requested stage or issue.
- Inspect `git status`, the complete diff, and changed-file list.
- Identify unrelated changes and revert them unless required and documented.

## 2. Perform a skeptical maintainer review

Read `references/review-checklist.md`.

Classify findings as:

- blocker;
- high;
- medium;
- low;
- informational.

Every blocker/high finding must include a reproduction or regression-test idea.

## 3. Remediate narrowly

Read `references/remediation-policy.md`.

- Fix blockers and high-severity findings only.
- Add regression tests.
- Do not broaden the original task.
- Do not hide failures by weakening tests, compatibility canonicalization, lint rules, or error handling.
- Perform one follow-up skeptical review.
- If a blocker remains, report it honestly instead of looping indefinitely.

## 4. Verify

Run:

- focused checks for changed areas;
- canonical full verification;
- affected differential scenarios;
- package clean-install checks when build/load/packaging changed;
- benchmark before/after checks for performance work.

## 5. Prepare the final report

Use `assets/pr-description-template.md`.

Include exact commands and concise outcomes. Never claim compatibility or performance beyond evidence.

## Safety

Never publish, tag, release, change repository settings, or add credentials.
