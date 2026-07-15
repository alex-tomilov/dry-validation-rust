# Codex stage R02: add community health and support files

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Repository context

Work in the current `dry-validation-rust` repository. Inspect the branch, implementation, tests, documentation, and recent related changes before editing. Do not assume every path or API named below is still exact.

## Assignment

Implement only this public-repository maturity stage. Keep it suitable for one focused pull request. When the stage is explicitly large, split it into the smallest dependency-ordered PRs and complete only the first coherent PR unless the user explicitly asks for the whole sequence.

**Priority:** P0  
**Suggested branch:** `docs/community-health`

## Files

```text
CONTRIBUTING.md
CODE_OF_CONDUCT.md
SECURITY.md
SUPPORT.md
GOVERNANCE.md
.github/ISSUE_TEMPLATE/config.yml
.github/ISSUE_TEMPLATE/bug.yml
.github/ISSUE_TEMPLATE/compatibility.yml
.github/ISSUE_TEMPLATE/performance.yml
.github/ISSUE_TEMPLATE/feature.yml
.github/pull_request_template.md
```

## CONTRIBUTING.md

Include:

- local prerequisites;
- setup commands;
- `script/verify`;
- test layers;
- how to add compatibility fixtures;
- Rust formatting/lint policy;
- changelog policy;
- benchmark evidence expectations;
- PR scope expectations;
- no generated binary commits unless release tooling requires them;
- Certificate of Origin or CLA decision.

A lightweight Developer Certificate of Origin sign-off is optional. Do not add a CLA without a reason.

## SECURITY.md

Include:

- supported release lines;
- private reporting route;
- what information to include;
- acknowledgement expectations;
- coordinated disclosure approach;
- explicit instruction not to open public issues for suspected vulnerabilities.

Use GitHub private vulnerability reporting when enabled.

## SUPPORT.md

Distinguish:

- bugs;
- compatibility mismatches;
- feature requests;
- usage questions;
- security reports.

State response-time expectations conservatively. Do not promise an SLA.

## Issue forms

### Bug

Collect:

- gem version;
- Ruby version;
- Rust version for source builds;
- platform;
- loading mode;
- minimal contract/input;
- expected/actual result;
- upstream comparison;
- backtrace;
- whether native gem or source build.

### Compatibility

Collect both upstream and Rust outputs and pinned upstream versions.

### Performance

Require reproducible script, iterations, warmup, hardware, RSS/allocations, and raw results.

## Acceptance criteria

- GitHub community profile is materially complete.
- Security reports have a private route.
- Issue templates collect enough data to reproduce native-extension bugs.
- Contribution instructions work from a clean checkout.

---

---

## Mandatory execution sequence

1. Inspect relevant code, tests, build files, and documentation.
2. Restate current behavior and the minimal proposed design.
3. Identify assumptions in this prompt that do not match the current repository.
4. Add/update regression and boundary tests.
5. Implement the focused change.
6. Run focused checks.
7. Run canonical full verification.
8. Review the diff for unrelated behavior or compatibility changes.
9. Update documentation/changelog only where justified.
10. Stop without publishing or changing remote repository settings.

## Scope control

- Do not perform adjacent roadmap stages.
- Do not add unrelated DSL features.
- Do not hide an upstream mismatch by weakening canonicalization or tests.
- Do not claim optimization without measurements.
- If the full stage cannot safely fit one PR, provide a PR breakdown and implement the first self-contained part.

## Final response format

Return:

1. **Summary**
2. **Current behavior confirmed**
3. **Files changed**
4. **Implementation details**
5. **Design decisions / rejected alternatives**
6. **Public API and compatibility impact**
7. **Tests and exact commands**
8. **Benchmark evidence**, if applicable
9. **Known limitations / follow-ups**
10. **Risks / rollback**
11. **No-release confirmation**
