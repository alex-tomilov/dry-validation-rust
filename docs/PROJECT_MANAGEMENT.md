# Project management

The public outcome roadmap is [ROADMAP.md](ROADMAP.md). Current
machine-readable milestone/task state lives in
[`compat/status.yml`](../compat/status.yml). The authoritative milestone
specifications are the numbered files in `docs/codex/`, and
`.github/project-management.yml` is the declarative source for optional GitHub
issue/project synchronization.

Git history, issues, and pull requests are the work history. Do not maintain a
second prose activity log.

## Working rules

- Use one stable milestone key (`A` through `G`) per managed roadmap issue.
- Work on one coherent slice at a time; Milestone E is explicitly one selected
  compatibility feature, not a single large implementation.
- Move work to `Ready` only when current evidence, non-goals, dependencies,
  acceptance criteria, and rollback are explicit.
- Compatibility claims need pinned separate-process differential evidence.
- Performance claims need reproducible before/after evidence.
- Documentation, file presence, coverage percentage, and metadata counts are not
  substitutes for behavior or artifact evidence.
- Update `compat/status.yml` only when a tracked durable milestone/task state or
  external blocker changes; do not update it once per commit.
- Keep temporary discoveries and completion details in issues/PRs rather than
  promoting them automatically into permanent project-state documentation.
- Limit active implementation work to one item by default.

## Milestones

| Key | Milestone                            | Outcome                                                                          | Depends on    |
| --- | ------------------------------------ | -------------------------------------------------------------------------------- | ------------- |
| `A` | Trustworthy baseline                 | Pinned compatibility evidence, explicit unsupported forms, source-gem smoke test | —             |
| `B` | Common schema path                   | Dependable nested schema behavior for the documented subset                      | `A`           |
| `C` | Ordinary contract rules              | Predictable supported rule execution and state isolation                         | `B`           |
| `D` | Performance proof                    | Reproducible evidence for favourable, neutral, and unfavourable workloads        | `C`           |
| `E` | Migration-driven compatibility slice | One selected, upstream-evidenced migration blocker                               | `C`           |
| `F` | Packaging and platforms              | Clean installation on a small verified support matrix                            | `A`, `C`      |
| `G` | Stable supported subset              | Narrow 1.0 go/no-go decision based on prior evidence                             | `D`, `E`, `F` |

The milestone files define their own detailed acceptance criteria and exit gates;
this table only records the management order.

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
Roadmap issues use `<!-- dvr-roadmap:KEY -->` markers. Replacing the local
roadmap does not automatically close obsolete remote issues; review those
manually before any authorized synchronization.
