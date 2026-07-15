# Codex stage R01: choose branch and contribution governance

> Feed Codex this entire file after `00-CODEX-GLOBAL-INSTRUCTIONS.md`.

## Repository context

Work in the current `dry-validation-rust` repository. Inspect the branch, implementation, tests, documentation, and recent related changes before editing. Do not assume every path or API named below is still exact.

## Assignment

Implement only this public-repository maturity stage. Keep it suitable for one focused pull request. When the stage is explicitly large, split it into the smallest dependency-ordered PRs and complete only the first coherent PR unless the user explicitly asks for the whole sequence.

**Priority:** P0  
**Suggested branch:** `docs/repository-governance`

## Recommended model

For a single-maintainer project:

- `main`: protected integration/release branch;
- short-lived feature branches;
- tags for releases;
- no permanent `develop` branch unless it solves a real release-management need.

Migration options:

### Conservative

Keep `develop` temporarily, create `main`, merge tested changes into `main`, then retire `develop`.

### Minimal disruption

Rename `develop` to `main` after CI exists and references are updated.

## Branch protection target

Configure manually after CI is stable:

- require pull requests;
- require selected status checks;
- block force pushes;
- block branch deletion;
- require conversation resolution;
- prefer squash merge or linear history;
- optionally require signed commits/tags later.

Codex may prepare documentation and workflow names, but repository settings should be changed manually by the owner.

## Contribution policy

Create `GOVERNANCE.md` describing:

- current maintainer;
- decision-making model;
- compatibility philosophy;
- how breaking changes are proposed;
- release authority;
- process for adding maintainers later;
- project independence from dry-rb.

## Acceptance criteria

- Default-branch strategy is documented.
- Required status-check names are stable.
- Merge policy is documented in `CONTRIBUTING.md`.
- Governance does not imply a multi-maintainer structure that does not exist.

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
