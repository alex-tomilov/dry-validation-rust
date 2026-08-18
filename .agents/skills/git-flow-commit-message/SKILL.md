---
name: git-flow-commit-message
description: Draft one concise Conventional Commit message that matches this repository's git-flow history. Use when asked to name the current staged or working-tree changes for a commit, including feature, bugfix, release, CI, performance, refactor, and documentation work.
---

# Git-flow Commit Message

Inspect the repository before drafting a message:

1. Run `git status --short`, `git diff --cached --stat`, and `git diff --stat`.
2. Read the relevant staged diff; when nothing is staged, read the working-tree diff. Treat untracked files as out of scope unless the user says they belong in the commit.
3. Inspect recent non-merge commit subjects with `git log --oneline` to match local scopes and wording.
4. Produce exactly one imperative Conventional Commit subject in lowercase. Match a nearby local form such as `feat(ci): summary`, `fix(scope): summary`, or `ci: summary`; keep it under 72 characters.

Choose the narrowest truthful type:

- `feat` for a user-visible capability;
- `fix` for a corrected defect;
- `ci` for workflow maintenance or corrective automation changes;
- `perf` for measured performance work;
- `refactor` for behavior-preserving structural work;
- `docs`, `test`, `build`, or `chore` when they are more precise.

For a new CI capability, prefer `feat(ci)` when that matches local history; use `ci` for a CI-only corrective change. Do not claim a release, breaking change, or behavior not evidenced by the diff. Do not create a commit or change files. Return the subject in a code block, followed by one short reason only if it helps disambiguate the type or scope.
