# AGENTS.md — Lean feature delivery

These instructions apply to coding agents working in this repository.

## Mission

Ship correct, reviewable user value with the least process needed to keep the codebase understandable and safe for a team.

Optimize for this order:

1. user-visible behavior;
2. correctness and safety;
3. focused verification;
4. maintainable code;
5. minimal affected documentation;
6. repository polish.

Do not optimize for the number of documents, tests, abstractions, or process artifacts produced.

## Project state and progress

Do not maintain a per-task or per-commit progress log.

Code, tests, differential fixtures, benchmarks, pull requests, and Git history
are the primary evidence that implementation work happened.

Use these authoritative locations instead:

- `docs/ROADMAP.md` — intended milestone outcomes, dependency order, and exit goals;
- `compat/status.yml` — small machine-readable current milestone/task state;
- `docs/COMPATIBILITY.md` — detailed supported and unsupported behavior;
- `docs/SUPPORT_MATRIX.md` — version, runtime, and platform support;
- benchmark sources/baselines and README benchmark sections — performance evidence;
- ADRs — durable cross-cutting decisions;
- issues/PRs/Git history — work history and temporary implementation context.

Update `compat/status.yml` only when a tracked durable state actually changes,
for example:

- a milestone moves between `not_started`, `active`, `blocked`, and `complete`;
- a named milestone task changes state;
- an external blocker is added or resolved;
- the declared release phase changes.

Do not update project-state files merely because:

- an ordinary bug fix or refactoring was completed;
- tests, fixtures, source files, or documentation counts changed;
- a commit was created;
- an investigation produced temporary notes;
- a benchmark experiment failed without changing a published claim;
- a follow-up idea was discovered.

When a compatibility, support, benchmark, or architecture truth changes, update
its authoritative location rather than duplicating the same fact in
`compat/status.yml`.

For milestone-driven work:

1. satisfy the milestone file's acceptance criteria;
2. run the required verification;
3. update `compat/status.yml` only if a tracked milestone/task state changed;
4. update user/developer documentation only where its durable truth changed;
5. keep completion details and follow-ups in the task/PR context;
6. do not create a separate completion-report document.

Documentation describes current durable truth; it is not an activity log.

## Default working mode

Work on one coherent capability, defect, or risk at a time.

Before editing:

1. read the relevant implementation and tests;
2. identify the smallest independently useful slice;
3. state the intended behavior, explicit non-goals, likely files, and verification plan;
4. reuse existing patterns before introducing new abstractions.

During implementation:

- keep unrelated code unchanged;
- prefer a direct implementation over speculative infrastructure;
- add focused behavioral tests;
- preserve explicit failures at unsupported or invalid boundaries;
- record follow-up ideas without implementing them;
- update only documentation whose truth changed.

At completion, report only:

1. behavior changed;
2. important files changed;
3. checks run and results;
4. remaining limitations or risks;
5. follow-up ideas intentionally not implemented.

## Scope guardrails

For an ordinary task, default limits are:

- one public capability or one defect class;
- at most 1,000 added lines, excluding generated code or fixtures that are the direct product requirement;
- at most 5 new source files;
- at most 3 new test files;
- at most 2 new abstractions;
- no new documentation file;
- updates to at most 2 existing documentation files;
- at most 150 added documentation lines.

If the likely change exceeds a limit, reduce it to the smallest useful vertical slice before coding. Do not silently continue with a large implementation.

These are agent guardrails, not rigid team policy. Exceed them only when the task explicitly requires it and the reason is stated before implementation.

## Tests

Tests should protect observable behavior, important regressions, safety boundaries, integration contracts, and packaging where relevant.

Before reporting a code-changing task as complete, run `bundle exec rubocop`
when Ruby source, tests, tooling, or CI configuration changed. Treat any
RuboCop failure as unfinished work: fix the offenses or report the remaining
baseline explicitly instead of claiming completion.

Prefer:

- focused unit tests for local behavior;
- integration tests for public flows;
- contract or differential tests for compatibility claims;
- regression tests for fixed defects;
- property, fuzz, or stress tests only for identified risk surfaces.

Do not add tests whose main purpose is checking:

- Markdown wording or headings;
- roadmap structure;
- documentation file presence or count;
- issue or pull-request template structure;
- stage completion;
- repository maturity claims;
- private implementation details already covered through public behavior.

Do not weaken or delete a failing test merely to make checks green.

## Documentation

Documentation exists to help users and maintainers make correct decisions.

Update documentation when a change affects:

- public behavior or API;
- configuration;
- installation or operation;
- compatibility or support boundaries;
- architecture ownership or data flow;
- a decision that would otherwise be repeatedly reopened.

Do not create a document for:

- an ordinary implementation plan;
- a completed task report;
- a temporary investigation;
- information already expressed clearly elsewhere;
- speculative future architecture.

Use comments for local reasoning, tests for executable behavior, `compat/status.yml`
for small machine-readable current milestone/task state, `docs/ROADMAP.md` for
intended outcomes, issues for planned work, pull requests for change context,
ADRs for durable cross-cutting decisions, and user documentation for supported
usage. Link between authoritative locations instead of copying the same state
into several documents.

## Abstractions

Do not add a framework, registry, adapter layer, plugin system, generic configuration mechanism, or extension point for one anticipated use case.

Generalize only when:

- at least two implemented cases need the same behavior;
- current duplication is concrete and meaningful;
- the abstraction reduces total conceptual surface;
- its ownership and failure behavior are clear.

Prefer duplication that is easy to remove over an abstraction that is difficult to understand.

## Failure behavior

Invalid, unsupported, or unsafe behavior must fail explicitly and predictably.

Never:

- silently ignore unsupported input;
- accept unsupported syntax as a no-op;
- approximate semantics without an explicit opt-in;
- hide an unexpected exception as a normal result;
- substitute a fallback that changes behavior without documentation;
- claim support because input parses successfully.

## Compatibility and performance claims

Compatibility claims require executable evidence against a pinned reference or a clearly documented contract.

Performance claims require reproducible before-and-after measurements on representative workloads. Report neutral and negative results as well as improvements. Never broaden a synthetic result into a general claim.

## Team decisions

Use an ADR only when a decision is durable, cross-cutting, costly to reverse, or likely to be reopened by multiple contributors.

An ADR should normally fit on one page and contain:

- context;
- decision;
- consequences;
- alternatives considered.

Do not write an ADR for routine implementation choices.

## Skill selection

Use the smallest set of skills needed for the active task.

Choose one primary skill for implementation or delivery. Preflight and review skills may be used before or after it, but they should not expand the task.

### Primary implementation skills

Use exactly one of these for ordinary implementation work:

- `.agents/skills/feature-delivery/SKILL.md` — implement one independently useful user-visible capability;
- `.agents/skills/bug-fix/SKILL.md` — reproduce and fix one defect class with regression coverage;
- `.agents/skills/compatibility/SKILL.md` — implement one verified compatibility slice against a pinned reference;
- `.agents/skills/migration/SKILL.md` — enable one realistic migration path with minimal user changes;
- `.agents/skills/performance/SKILL.md` — improve one measured bottleneck while preserving behavior;
- `.agents/skills/refactoring/SKILL.md` — improve internal structure without observable behavior changes;
- `.agents/skills/documentation/SKILL.md` — update documentation when documentation is the primary deliverable;
- `.agents/skills/release-readiness/SKILL.md` — verify an actual release candidate.

Do not combine several primary implementation skills in one ordinary task.

If a task appears to require two primary skills, select the dominant outcome and split the remaining work into a separate task unless the work is genuinely inseparable.

Examples:

- a feature that requires a small local refactoring remains a feature-delivery task;
- a bug fix that includes a benchmark to confirm no regression remains a bug-fix task;
- a compatibility feature required for a real migration may use migration as the primary skill and compatibility evidence as part of its workflow;
- release preparation must not include unrelated feature development.

### Preflight and decision skills

Use these before implementation when needed:

- `.agents/skills/scope-guard/SKILL.md` — define the smallest coherent slice and explicit non-goals before coding;
- `.agents/skills/investigation/SKILL.md` — inspect, reproduce, or evaluate without modifying implementation files;
- `.agents/skills/architecture-decision/SKILL.md` — evaluate a durable cross-cutting decision and create an ADR only when the ADR threshold is met.

These skills normally do not modify production code.

Use `scope-guard` when the request is broad, ambiguous, milestone-sized, or likely to exceed the scope guardrails.

Use `investigation` when the root cause, compatibility behavior, feasibility, or architecture boundary is not yet known.

Use `architecture-decision` only when implementation cannot proceed safely without resolving a durable cross-team decision.

After a preflight or decision task, start a separate implementation run with the selected primary skill and the approved scope.

### Review skills

Use these after implementation or for an existing diff:

- `.agents/skills/code-review/SKILL.md` — review correctness, compatibility, maintainability, and unnecessary complexity;
- `.agents/skills/safety-review/SKILL.md` — review panic safety, memory/resource ownership, concurrency, failure behavior, and other identified safety risks.

A review skill must not turn the review into unrelated implementation work.

Use `safety-review` only when the code touches a meaningful safety surface, such as:

- native or FFI boundaries;
- unsafe code;
- concurrency or synchronization;
- resource lifetime or cleanup;
- persistence or data-loss risk;
- authentication, authorization, or secrets;
- untrusted parsing or deserialization;
- panic or exception containment.

For ordinary changes, `code-review` alone is sufficient.

### Allowed skill sequences

Valid sequences include:

```text
scope-guard -> feature-delivery -> code-review
investigation -> bug-fix -> code-review
investigation -> performance -> code-review
architecture-decision -> feature-delivery -> code-review
scope-guard -> migration -> code-review
feature-delivery -> safety-review
release-readiness
```

The arrows represent separate phases or runs. They do not authorize all skills to broaden one implementation session.

### Skill routing rules

- Load only the skill needed for the current phase.
- Do not load every available skill by default.
- Do not let feature work automatically trigger release, documentation, architecture, or repository-cleanup work.
- Do not let review skills add unrelated requirements.
- Do not let `scope-guard` create permanent planning artifacts.
- Do not let `investigation` modify code unless the user explicitly starts a separate implementation phase.
- Do not let `documentation` rewrite unrelated documents.
- Do not let `refactoring` introduce behavior changes.
- Do not let `performance` optimize without a measured baseline.
- Do not let `compatibility` claim parity beyond executable evidence.
- Do not let `migration` become a complete reimplementation of the source system.
- Do not let `release-readiness` publish, tag, or release without explicit authorization.

## Working with scope guard

For a broad or ambiguous task, use this sequence:

1. apply `.agents/skills/scope-guard/SKILL.md` without modifying files;
2. identify one approved vertical slice;
3. select the matching primary implementation skill;
4. implement only the approved slice;
5. review the resulting diff with the smallest appropriate review skill.

The approved scope should state:

- outcome;
- included behavior;
- explicit non-goals;
- likely affected areas;
- verification plan;
- stop conditions.

Do not reopen or expand the approved scope during implementation unless a required blocker is discovered.

## Follow-up work

When work reveals additional ideas, classify them as:

- required blocker — include only the smallest necessary fix;
- related follow-up — report but do not implement;
- independent defect — recommend a separate bug-fix task;
- architectural uncertainty — stop and use investigation or architecture-decision;
- unrelated cleanup — leave unchanged.

Do not implement a follow-up merely because it is nearby or easy.

## Prohibited unless explicitly requested

Do not:

- publish artifacts or releases;
- create or push tags;
- make remote repository changes;
- change branch protection, visibility, or secrets;
- add credentials;
- create a new planning hierarchy;
- generate long compliance reports;
- reorganize documentation during unrelated feature work;
- implement backlog ideas discovered during the task;
- load every skill for every task;
- convert preflight or review work into an unapproved implementation task.
