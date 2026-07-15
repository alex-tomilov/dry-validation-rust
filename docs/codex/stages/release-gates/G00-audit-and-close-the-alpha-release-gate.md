# Codex release-gate stage G00: Audit and close the alpha release gate

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Assignment

Audit the current repository against the gate below, then implement only the smallest remaining blocker that can safely form one focused pull request.

First return a pass/fail/partial evidence table. Do not count documentation claims as proof without code, tests, CI, package, or artifact evidence.

# 5. Alpha release gate

A first public alpha may be published only when all items pass.

## Product/documentation

- [ ] precise product statement;
- [ ] safe API shown first;
- [ ] exact mode marked experimental;
- [ ] support matrix exists;
- [ ] compatibility matrix is versioned;
- [ ] migration/rollback basics exist;
- [ ] security and contribution files exist.

## Correctness

- [ ] compiled schema plans are deeply immutable;
- [ ] no Marshal schema copying;
- [ ] native plan types/predicates are strictly validated;
- [ ] unknown predicates cannot silently pass;
- [ ] exception classification is implemented;
- [ ] arbitrary-precision integer behavior is resolved;
- [ ] no known P0 correctness issue.

## Tests

- [ ] reproducible verification script;
- [ ] clean build from source;
- [ ] baseline fixtures;
- [ ] initial differential suite for all alpha-supported features;
- [ ] malformed-plan tests;
- [ ] concurrent-call smoke test.

## CI/package

- [ ] Linux CI for all supported Ruby versions;
- [ ] Rust MSRV and stable checks;
- [ ] source gem builds and clean-installs;
- [ ] package contents audited;
- [ ] no publication secret in PR CI.

## Release status

Release notes must say:

- alpha;
- not a full upstream replacement;
- safe-mode recommendation;
- exact-mode warning;
- source-build requirements;
- known unsupported features.

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
