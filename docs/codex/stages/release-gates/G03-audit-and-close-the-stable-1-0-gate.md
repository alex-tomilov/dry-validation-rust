# Codex release-gate stage G03: Audit and close the stable 1.0 gate

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Assignment

Audit the current repository against the gate below, then implement only the smallest remaining blocker that can safely form one focused pull request.

First return a pass/fail/partial evidence table. Do not count documentation claims as proof without code, tests, CI, package, or artifact evidence.

# 8. Stable `1.0` gate

`1.0` means the documented subset is stable and supportable.

## API stability

- [ ] public API inventory exists;
- [ ] semantic versioning policy exists;
- [ ] deprecation policy exists;
- [ ] native plan versioning policy exists;
- [ ] exact compatibility mode status is final for the `1.x` line;
- [ ] breaking-change process exists.

## Compatibility

- [ ] pinned upstream reference policy;
- [ ] broad deterministic differential suite;
- [ ] no unresolved P0/P1 bug in supported behavior;
- [ ] intentional differences are stable and documented;
- [ ] unsupported features fail explicitly.

## Platforms

- [ ] supported Ruby/platform matrix is realistic;
- [ ] every combination is tested or clearly scoped;
- [ ] source and native installation paths are maintained;
- [ ] old Ruby/platform retirement policy exists.

## Security/release

- [ ] private reporting;
- [ ] security patch/backport policy;
- [ ] trusted, reproducible release process;
- [ ] dependency monitoring;
- [ ] artifact verification;
- [ ] maintainer recovery documentation for release credentials/settings.

## Performance

- [ ] repeatable reports;
- [ ] no misleading universal claim;
- [ ] memory as well as throughput measured;
- [ ] documented GVL behavior;
- [ ] regression review policy.

## Adoption

- [ ] safe migration guide;
- [ ] production-shaped evidence;
- [ ] examples;
- [ ] troubleshooting;
- [ ] realistic support expectations.

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
