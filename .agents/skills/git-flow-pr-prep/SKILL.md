---
name: git-flow-pr-prep
description: Review the current Git branch and draft a git-flow branch name, one Conventional Commit subject, a pull-request title, and a completed PR description from the repository template. Use when preparing an implementation branch for review or when asked for commit/PR metadata without creating commits, branches, or remote changes.
---

# Git-flow PR Prep

Inspect the current branch before drafting anything. This skill is read-only: do not create branches
or commits, stage files, push, open a PR, or alter repository settings.

## Workflow

1. Read the applicable repository instructions and `.github/pull_request_template.md` when present.
2. Inspect `git status --short`, the staged diff and working-tree diff, and recent non-merge commit
   subjects. Treat untracked files as out of scope unless the user explicitly includes them.
3. Review the diff for correctness, compatibility, safety, and missing behavioral coverage. Report
   only material findings with severity, file/line, impact, and a minimal fix. If none exist, say so
   and state residual risks briefly.
4. Infer the narrowest git-flow prefix from the change: `feature/`, `bugfix/`, `release/`, or
   `hotfix/`. Use a concise lowercase kebab-case name; propose it without creating it.
5. Draft exactly one imperative Conventional Commit subject in lowercase, under 72 characters,
   matching nearby repository history. Use the narrowest truthful type and scope.
6. Decide the changelog disposition before drafting the PR. Require an
   `Unreleased` entry for a user-visible behavior, compatibility, installation,
   or operational change. Treat new or materially expanded getting-started,
   installation, or migration documentation as user-visible. If a required
   entry is missing, report it as a material finding and include the exact
   entry needed; otherwise state that the PR needs the `no-changelog` label.
   Verify that any entry describes the observable diff, belongs under
   `Unreleased`, and does not claim unrun evidence or a release. Draft a
   concise PR title and fill every relevant section of the repository PR
   template. Keep unchecked items that were not performed; never claim
   verification, compatibility evidence, benchmarks, or releases that the diff
   and command output do not establish.

## Output

Return, in this order:

1. Review findings (or `No material findings`).
2. Proposed branch name in a code block.
3. Proposed commit subject in a code block.
4. PR title.
5. PR description in a Markdown code block ready to paste.

Distinguish an intentional breaking change from an accidental compatibility regression, and call out
rollback as reverting the proposed commit unless the diff shows a more specific procedure.
