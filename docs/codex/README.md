# Codex automation layer for dry-validation-rust

This package replaces manual `H00–H05` prompt pasting with repository instructions and repo-scoped skills.

## Mapping

| Old helper | New mechanism |
|---|---|
| H00 skeptical review | `dvr-delivery-gate` |
| H01 fix blocking findings | `dvr-delivery-gate` |
| H02 diagnose failure | `dvr-failure-diagnosis` |
| H03 benchmark regression | `dvr-benchmark-regression` |
| H04 upstream mismatch | `dvr-upstream-mismatch` |
| H05 PR description | `dvr-delivery-gate` |

## Installation

Extract the archive into the repository root. The resulting paths must be:

```text
AGENTS.md
.agents/skills/dvr-delivery-gate/SKILL.md
.agents/skills/dvr-failure-diagnosis/SKILL.md
.agents/skills/dvr-benchmark-regression/SKILL.md
.agents/skills/dvr-upstream-mismatch/SKILL.md
docs/codex/README.md
```

Commit them if every Codex user of the repository should inherit the workflow.

Start a new Codex session after adding the files.

## Verify discovery

Ask Codex:

```text
List the AGENTS.md instruction sources and repository skills you loaded. Do not modify anything.
```

You can explicitly test the main skill:

```text
Use $dvr-delivery-gate to review the current branch without editing.
```

## Roadmap-stage convenience

Place the previously generated stage files under:

```text
docs/codex/stages/technical/
docs/codex/stages/repository/
docs/codex/stages/release-gates/
```

Then you can say:

```text
Implement T01.
Run R04.
Audit G00.
```

The root `AGENTS.md` tells Codex to find and read the matching stage file instead of asking you to paste it.

## Important limitation

`AGENTS.md` and implicit skill selection are instructions interpreted by the agent, not an external guaranteed hook. The workflow is strongly encoded, but CI remains the deterministic enforcement layer for tests, linting, package checks, and compatibility checks.
