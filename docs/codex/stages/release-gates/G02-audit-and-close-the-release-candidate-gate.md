# Codex release-gate stage G02: Audit and close the release-candidate gate

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Assignment

Audit the current repository against the gate below, then implement only the smallest remaining blocker that can safely form one focused pull request.

First return a pass/fail/partial evidence table. Do not count documentation claims as proof without code, tests, CI, package, or artifact evidence.

# 7. Release-candidate gate

In addition to beta gates:

## Platform artifacts

- [ ] all advertised Linux architectures pass;
- [ ] advertised macOS artifacts pass;
- [ ] Windows is either passing or clearly unsupported;
- [ ] no unverified platform appears in metadata.

## Release process

- [ ] complete release dry run;
- [ ] version consistency enforcement;
- [ ] checksums;
- [ ] trusted publishing configured;
- [ ] manual approval environment;
- [ ] post-publish smoke procedure;
- [ ] rollback/yank policy.

## Operations

- [ ] troubleshooting guide;
- [ ] issue templates;
- [ ] support policy;
- [ ] security reporting tested;
- [ ] branch protection configured;
- [ ] required status checks documented.

## Real-world evidence

- [ ] at least one real application or representative corpus evaluated;
- [ ] mismatches reviewed;
- [ ] memory/throughput recorded;
- [ ] rollback path demonstrated.

---

## Required output before editing

1. Gate checklist with exact evidence paths.
2. Blocking findings ordered by severity.
3. Missing evidence versus known failure.
4. Recommended issue/PR decomposition.
5. The single focused blocker selected for this run.

## Implementation rule

Implement only the selected blocker, add tests, run full verification, and update the gate table. Do not publish, tag, release, or change repository settings.

## Final response

Include the updated gate status, remaining blockers, exact tests, risks, and no-release confirmation.
