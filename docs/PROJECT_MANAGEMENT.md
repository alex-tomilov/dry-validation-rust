# Project management

The public outcome roadmap is [ROADMAP.md](ROADMAP.md). The executable Codex
specifications live under `docs/codex/stages/`, and
`.github/project-management.yml` is the declarative source for optional GitHub
issue/project synchronization.

## Working rules

- Use one stable stage key (`T01`, `R03`, `G00`) per issue.
- Work on one coherent slice at a time; a stage is an outcome area, not a single
  giant pull request.
- Move work to `Ready` only when current evidence, non-goals, dependencies,
  acceptance criteria, and rollback are explicit.
- Compatibility claims need pinned separate-process differential evidence.
- Performance claims need reproducible before/after evidence.
- Documentation, file presence, coverage percentage, and metadata counts are not
  substitutes for behavior or artifact evidence.
- Limit active implementation work to one item by default.

## Milestones

| Milestone | Outcome | Gate |
|---|---|---|
| `0.1 prerelease - safe core` | Safe supported subset, robust verification, source package readiness | `G00` |
| `0.2-0.3 - evidence and adoption` | Broader compatibility/delivery evidence, maintained adoption paths, and profiled improvements | `G01` |
| `Future - batch and streaming experiments` | Optional Rust-owned processing experiments | No release commitment |

The ordered stage list and dependencies are maintained in
[ROADMAP.md](ROADMAP.md) and `.github/project-management.yml`; they are not
duplicated here.

## Labels and board

The canonical labels are `.github/labels.yml`. Apply one `type:*`, one
`priority:*` after triage, at least one `area:*`, and only relevant status/flags.
Use the board flow `Backlog` → `Ready` → `In progress` → `Review` → `Done`, with
`Blocked` for a named external or dependency blocker.

`status:good-first-issue` is appropriate only after design is settled and the
task has a bounded behavior change, focused test, and no unresolved FFI,
compatibility, release, or performance decision.

## Remote synchronization

The synchronizer is read-only by default:

```bash
script/sync-github-project-management
script/sync-github-project-management --offline
```

After reviewing a live plan, the repository owner may explicitly apply it:

```bash
script/sync-github-project-management --apply
```

It creates or updates managed metadata and never deletes unknown remote objects.
Roadmap issues use `<!-- dvr-roadmap:KEY -->` markers. Replacing the local roadmap
does not automatically close obsolete remote issues; review those manually before
any authorized synchronization.
