# Project management

This document is the repository source of truth for issue taxonomy, milestone
scope, roadmap ordering, and project-board flow. GitHub labels, milestones,
issues, and project fields are remote objects and must be created or updated by
the repository owner to match this policy.

The stable roadmap key is the stage prefix (`T03`, `R06`, `G00`, and so on).
GitHub issue titles for roadmap work should begin with that key so issues,
pull requests, and stage specifications remain searchable even if issue
numbers change.

## Labels

The canonical label catalog is `.github/labels.yml`. Every issue should have:

- exactly one `type:*` label;
- exactly one `priority:*` label after triage;
- at least one `area:*` label;
- only the applicable `status:*` and standalone flags.

Priority meanings:

- `priority:p0`: release-blocking correctness, security, data-safety, or
  unsupported-behavior work. P0 items are ordered and worked before lower
  priorities in the same milestone.
- `priority:p1`: important work on the current milestone's critical path.
- `priority:p2`: useful work that is not required for the current gate.
- `priority:p3`: future, exploratory, or deliberately deferred work.

`breaking-change` requires an explicit migration path and release impact.
`upstream-difference` requires pinned upstream versions and separate-process
evidence. `status:good-first-issue` is reserved for tasks with a bounded file
set, explicit expected behavior, focused tests, and no unresolved FFI,
compatibility, or release-design decision.

The issue forms reference canonical labels. GitHub ignores a form's default
label when that label has not been created, so synchronize the remote label
catalog before relying on automatic triage.

## Milestones

| Milestone | Goal | Exit gate |
| --- | --- | --- |
| `0.1 alpha - correctness foundation` | Resolve correctness and compatibility-claim blockers for the first public alpha | `G00` |
| `0.1 beta - compatibility and benchmark evidence` | Build broad differential, robustness, maintainability, and measured-performance evidence | `G01` |
| `0.1 RC - native packaging and release readiness` | Validate native artifacts, release automation, operations, and real-world rollback | `G02` |
| `1.0 - stable API and support policy` | Commit to a supportable stable subset and lifecycle policy | `G03` |
| `Future - experimental batch API` | Evaluate an opt-in Rust-owned batch path without delaying the core engine | No release commitment |

Milestone names intentionally use ASCII hyphens so issue forms, automation, and
manual setup use exactly the same values.

## Delivered foundations

These stage specifications have already produced repository changes and do not
need replacement umbrella issues:

| Key | Delivered evidence |
| --- | --- |
| `R00` | Product identity, safe/exact API positioning, and support matrix |
| `R02` | Community health, support, security, issue, and pull request templates |
| `R03` | Public gem metadata and source-package audit |
| `R04` | Ruby/Rust CI, compatibility preflight, security, package, and fuzz workflows |
| `R05` | Dependency update and audit policy |
| `T00` | Canonical verification, baseline fixtures, and benchmark smoke |
| `R09` | This project-management policy and issue taxonomy |

Completion here means the focused stage was delivered, not that a later release
gate is automatically satisfied.

## Ordered roadmap

Each row is an issue-sized specification. Create one GitHub issue per row with
the implementation form, assign the listed milestone and priority, and link the
stage file. If review shows that a row contains independent deliverables, split
it into dependency-ordered child issues before moving it to `Ready`.

### 0.1 alpha - correctness foundation

| Order | Key and issue specification | Priority | Depends on |
| --- | --- | --- | --- |
| 1 | [`R01` branch and contribution governance](codex/stages/repository/R01-choose-branch-and-contribution-governance.md) | P0 | None |
| 2 | [`T01` immutable compiled plans](codex/stages/technical/T01-separate-mutable-dsl-builders-from-immutable-compiled-plans.md) | P0 | `T00` |
| 3 | [`T02` strict typed native plan](codex/stages/technical/T02-introduce-a-typed-and-strictly-validated-native-plan.md) | P0 | `T01` |
| 4 | [`T03` Ruby exception handling across FFI](codex/stages/technical/T03-correct-ruby-exception-handling-across-the-rust-boundary.md) | P0 | `T02` |
| 5 | [`T04` arbitrary-precision Ruby integers](codex/stages/technical/T04-support-arbitrary-precision-ruby-integers.md) | P0 | `T03` |
| 6 | [`T06` initial differential compatibility harness](codex/stages/technical/T06-build-a-differential-compatibility-harness.md) | P0 for claims | `T00`, preferably `T04` |
| 7 | [`R08` documentation information architecture](codex/stages/repository/R08-documentation-information-architecture.md) | P0/P1 | Stable alpha scope |
| 8 | [`G00` alpha release-gate audit](codex/stages/release-gates/G00-audit-and-close-the-alpha-release-gate.md) | P0 | All alpha blockers |

Do not skip a blocked P0 by silently relabeling it. Record the blocker, move the
card to `Blocked`, and work the named dependency.

### 0.1 beta - compatibility and benchmark evidence

| Order | Key and issue specification | Priority | Depends on |
| --- | --- | --- | --- |
| 1 | [`T05` Rust module split](codex/stages/technical/T05-split-the-rust-extension-into-modules-without-behavior-changes.md) | P1 | `T02`-`T04` |
| 2 | [`T06` broad differential compatibility coverage](codex/stages/technical/T06-build-a-differential-compatibility-harness.md) | P1 | Alpha harness |
| 3 | [`T09` compiled rule metadata](codex/stages/technical/T09-normalize-rule-paths-and-compile-rule-metadata-once.md) | P1 | `T01`, `T06` |
| 4 | [`T11` multi-scenario benchmark suite](codex/stages/technical/T11-replace-the-benchmark-smoke-test-with-a-benchmark-suite.md) | P1 | `T00` |
| 5 | [`T07` indexed schema error paths](codex/stages/technical/T07-index-schema-error-paths.md) | P1 | `T00`, preferably `T06` |
| 6 | [`T08` cached result/message views](codex/stages/technical/T08-cache-finalized-result-message-views.md) | P1 | `T00` |
| 7 | [`T10` measured native fast paths](codex/stages/technical/T10-add-measured-native-fast-paths.md) | P1 | `T03`, `T06`, `T09`, benchmark suite |
| 8 | [`T12` property, fuzz, GC, and concurrency tests](codex/stages/technical/T12-property-fuzz-malformed-plan-gc-and-concurrency-testing.md) | P1/P2 | `T02`-`T06` |
| 9 | [`R10` public compatibility and performance evidence](codex/stages/repository/R10-public-performance-and-compatibility-evidence.md) | P1 | Differential and benchmark phases |
| 10 | [`G01` beta release-gate audit](codex/stages/release-gates/G01-audit-and-close-the-beta-release-gate.md) | P0 | All beta blockers |

### 0.1 RC - native packaging and release readiness

| Order | Key and issue specification | Priority | Depends on |
| --- | --- | --- | --- |
| 1 | [`R06` native binary gem strategy](codex/stages/repository/R06-native-binary-gem-strategy.md) | P1 | `R04`, correctness foundation |
| 2 | [`R07` release automation and version policy](codex/stages/repository/R07-release-automation-and-version-policy.md) | P1 | `R03`-`R06` |
| 3 | [`G02` release-candidate gate audit](codex/stages/release-gates/G02-audit-and-close-the-release-candidate-gate.md) | P0 | All RC blockers |

### 1.0 - stable API and support policy

| Order | Key and issue specification | Priority | Depends on |
| --- | --- | --- | --- |
| 1 | [`R11` adoption examples and supportability](codex/stages/repository/R11-adoption-examples-and-supportability.md) | P2 before stability review | Public alpha and representative use |
| 2 | [`R12` stable 1.0 governance](codex/stages/repository/R12-stable-1-0-governance.md) | P0 for 1.0 | Stable support evidence |
| 3 | [`G03` stable 1.0 gate audit](codex/stages/release-gates/G03-audit-and-close-the-stable-1-0-gate.md) | P0 | All stable blockers |

### Future - experimental batch API

| Order | Key and issue specification | Priority | Depends on |
| --- | --- | --- | --- |
| 1 | [`T13` batch/GVL-releasing API evaluation](codex/stages/technical/T13-evaluate-a-future-batch-gvl-releasing-api.md) | P3 | Stable normal API and benchmark evidence |

## Issue quality

Use `.github/ISSUE_TEMPLATE/implementation.yml` for roadmap implementation
work. Every implementation issue must include:

- problem;
- user or maintainer impact;
- current behavior and evidence;
- desired behavior;
- non-goals;
- affected files and ownership boundaries;
- implementation notes;
- tests and canonical verification;
- independently verifiable acceptance criteria;
- dependencies and blockers;
- risks and rollback.

An issue is not ready when it says only "make production ready", combines
independent roadmap stages, lacks a reproducer for a bug or regression, or
depends on an unresolved design decision.

## Project board

Use these columns in order:

| Column | Entry condition | Exit condition |
| --- | --- | --- |
| `Backlog` | Valid issue, but not selected for the current milestone | Priority and dependencies reviewed |
| `Ready` | Scoped, dependencies resolved, acceptance criteria testable | Work starts |
| `In progress` | One owner is actively implementing the issue | Pull request opened or issue becomes blocked |
| `Review` | Pull request is open and verification evidence is present | Merged, changes requested, or blocked |
| `Blocked` | Named dependency, external state, or maintainer decision prevents progress | Blocker resolved and card returns to the appropriate column |
| `Done` | Acceptance criteria are met and the change is merged | No further movement |

Limit work in progress to one active Codex implementation task by default and
two only when the tasks are independent and neither blocks review of the other.
Reviews and blocked items do not justify starting an unbounded queue.

## Triage and decomposition

1. Confirm the report belongs in this repository and is not a private security
   report.
2. Apply one type, one priority, and at least one area label.
3. Require reproduction evidence for bugs, compatibility mismatches, and
   performance reports before moving them to `Ready`.
4. Assign a milestone only when the issue has a clear gate relationship.
5. Split issues that cross independent Ruby/Rust ownership boundaries,
   multiple release gates, or separately verifiable behavior.
6. Keep P0 work ordered by dependency, not by arrival time.
7. Mark a task `status:good-first-issue` only after design and expected tests
   are settled.

Closing an issue as out of scope is preferable to keeping a vague umbrella
issue that cannot be implemented or reviewed coherently.

## Remote synchronization

`.github/project-management.yml` is the declarative source for remote
milestones, the Projects v2 board, and roadmap issues. The label definitions
remain in `.github/labels.yml`.

The synchronizer performs a live read-only plan by default:

```bash
script/sync-github-project-management
```

It requires an authenticated GitHub CLI session with issue write permission and
the `project` scope for Projects v2 mutations:

```bash
gh auth login -h github.com --scopes "project"
```

The user-owned project-view endpoint does not accept fine-grained personal
access tokens, so use the GitHub CLI OAuth login above (or a compatible classic
token) when the board view must be created.

When authentication is unavailable, an offline plan can validate the manifest
and show everything that would be created against an empty remote:

```bash
script/sync-github-project-management --offline
script/sync-github-project-management --offline --verbose
```

After reviewing a live plan, apply it explicitly:

```bash
script/sync-github-project-management --apply
```

Use `--only labels,milestones,project,issues` with any subset for staged
application. The synchronizer creates missing managed objects and updates
managed metadata, but never deletes unknown labels, milestones, issues, project
items, or views. Roadmap issues are identified by stable
`<!-- dvr-roadmap:KEY -->` markers so repeated runs do not create duplicates.
