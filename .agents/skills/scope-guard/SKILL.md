---
name: scope-guard
description: >
  Keep an engineering task within one coherent, independently useful,
  reviewable slice. Use this skill before implementation when a request
  is broad, ambiguous, likely to expand, or may introduce unnecessary
  abstractions, documentation, tests, or cleanup. Identify the smallest
  valuable outcome, define explicit non-goals, estimate the likely change,
  and split oversized work before coding. Do not use this skill to implement
  features, perform repository-wide planning, or create permanent process
  artifacts.
---

# Scope Guard

## Purpose

Prevent an engineering task from expanding beyond the smallest coherent change that delivers useful value.

This skill protects against:

- implementing several independent capabilities together;
- speculative abstractions;
- unrelated refactoring;
- documentation growth unrelated to changed behavior;
- excessive test infrastructure;
- premature release or architecture work;
- large diffs that are difficult to verify and review;
- spending implementation time on attractive follow-up ideas.

The desired result is not the smallest possible diff at any cost.

The desired result is:

> The smallest independently useful, correct, testable, and reviewable vertical slice.

## Use this skill when

Use this skill when:

- a task contains several features or concerns;
- requirements are broad or ambiguous;
- implementation could affect several subsystems;
- the request includes phrases such as “complete support,” “fully compatible,” “prepare everything,”
  or “refactor the whole area”;
- a new framework, registry, plugin system, or configuration layer is being considered;
- documentation or test infrastructure may become larger than the product change;
- implementation is likely to exceed repository guardrails;
- an investigation has uncovered several possible improvements;
- an agent proposes work beyond the requested outcome;
- a milestone needs to be divided into separate implementation runs.

## Do not use this skill for

Do not use this skill to:

- implement the selected feature;
- fix the selected defect;
- perform the selected refactoring;
- write a broad project roadmap;
- redesign the repository architecture;
- create permanent planning documents;
- generate a report for every ordinary task;
- replace normal issue or pull-request discussion;
- reject necessary complexity merely because a diff is large.

After the scope is approved, use the skill matching the actual work, such as:

- `feature-delivery`;
- `bug-fix`;
- `compatibility`;
- `performance`;
- `refactoring`.

## Core rule

One implementation task should normally deliver one coherent outcome.

A coherent outcome may require changes across several layers, such as:

- public API;
- application logic;
- persistence;
- native extension;
- tests;
- directly affected documentation.

Those changes may belong in one task when they are all necessary to make one capability work end to end.

They should be split when they deliver independent value, have different risks, or can be reviewed and released separately.

## Vertical slice test

A proposed slice is valid when all of the following are true:

- it produces an observable or operationally meaningful result;
- it can be tested independently;
- it has a clear completion condition;
- it does not require implementing unrelated backlog items;
- unsupported adjacent behavior can remain unsupported explicitly;
- it can be reviewed without understanding several unrelated changes;
- it leaves the repository in a valid state.

A slice is too small when it creates infrastructure with no usable behavior.

A slice is too large when it contains several independently useful outcomes.

## Before implementation

Do not modify files yet.

Inspect only the minimum repository context needed to understand:

- the requested behavior;
- the current implementation path;
- existing tests and patterns;
- affected public contracts;
- likely architecture boundaries;
- existing documentation that may become inaccurate.

Then state:

1. requested outcome;
2. smallest useful slice;
3. explicit non-goals;
4. likely files or subsystems affected;
5. verification plan;
6. estimated scope;
7. risks that could force another split;
8. follow-up ideas intentionally excluded.

Do not produce a long planning document.

A concise preflight response is sufficient.

## Decision tree

### 1. Does the request contain more than one independently useful capability?

- No: continue.
- Yes: split the task.

Examples of independent capabilities:

- adding two unrelated predicates;
- adding a feature and redesigning configuration;
- fixing a bug and performing broad cleanup;
- implementing source builds and precompiled releases;
- adding compatibility and a migration analyzer;
- improving throughput and reducing memory through unrelated mechanisms.

Choose the capability with the clearest immediate value.

Record the others as follow-up ideas without implementing them.

### 2. Is every proposed change required for the selected outcome?

- Yes: continue.
- No: remove unrelated changes from the task.

Typical unrelated changes include:

- formatting nearby files;
- renaming unrelated classes;
- updating unrelated dependencies;
- reorganizing documentation;
- rewriting tests that already protect correct behavior;
- cleaning historical code in the same directory;
- implementing another backlog item because the file is already open.

### 3. Is a new abstraction required?

Ask:

- Are at least two existing concrete cases using the same behavior?
- Does the abstraction reduce total conceptual complexity?
- Is its responsibility clear?
- Is its failure behavior clear?
- Is it required by the current slice rather than a hypothetical future feature?

If any answer is no, prefer a direct implementation.

Do not create:

- registries;
- plugin systems;
- adapter frameworks;
- generalized ASTs;
- extension APIs;
- configuration layers;
- factories;
- base classes;

for one anticipated use case.

### 4. Does the task require a new documentation file?

Create a document only when the information is durable and has no suitable authoritative location.

Prefer:

- updating an existing user guide;
- updating an existing compatibility matrix;
- adding a changelog entry;
- recording temporary context in the issue or pull request;
- expressing local reasoning in a code comment;
- expressing behavior in a test.

Do not create a document for:

- an ordinary implementation plan;
- a completed-task report;
- a temporary investigation;
- a checklist used only during one task;
- information already represented by tests;
- aspirational future architecture.

### 5. Does the task require new test infrastructure?

Use existing test patterns when possible.

Create new infrastructure only when:

- existing tools cannot test the important behavior;
- the new infrastructure will support more than one concrete current case;
- its maintenance cost is proportionate to the risk;
- it tests behavior rather than repository process.

Do not add tests for:

- Markdown headings;
- documentation wording;
- roadmap structure;
- issue-template contents;
- file counts;
- milestone completion;
- repository maturity claims.

### 6. Does the task require an ADR?

Use an ADR only when the decision is:

- cross-cutting;
- durable;
- costly to reverse;
- likely to affect several future features;
- likely to be reopened by multiple contributors.

Do not create an ADR for:

- method extraction;
- ordinary class design;
- routine dependency use;
- a local naming decision;
- one feature’s internal implementation;
- a temporary experiment.

### 7. Can the task fit the repository guardrails?

Use the limits defined in `AGENTS.md`.

When the repository has no explicit limits, use these defaults for an ordinary task:

- one public capability or one defect class;
- no more than approximately 1,000 added lines;
- no more than 5 new source files;
- no more than 3 new test files;
- no more than 2 new abstractions;
- no new documentation file;
- updates to no more than 2 existing documentation files;
- no more than approximately 150 added documentation lines.

These are warning thresholds, not rigid laws.

Exceeding a threshold requires one of these outcomes:

1. split the task;
2. explain why the complexity is indivisible;
3. perform an investigation before implementation;
4. request an explicit scope decision.

Do not silently proceed with an oversized change.

## Estimating scope

Before coding, classify the task.

### Small

Usually:

- one local behavior;
- one subsystem;
- focused tests;
- no new abstraction;
- no new document.

Proceed directly after stating the scope.

### Medium

Usually:

- one vertical feature across several layers;
- several existing files;
- one small abstraction;
- integration coverage;
- one or two documentation updates.

Proceed only after identifying explicit non-goals and verification.

### Large

Usually:

- several public capabilities;
- several subsystems with independent behavior;
- new architecture or extension mechanisms;
- platform or release work;
- migration across many callers;
- significant uncertainty.

Do not implement as one ordinary task.

Split it into small or medium slices.

## Splitting strategy

Split work by observable behavior, risk, or dependency.

Good split dimensions include:

- one feature variant at a time;
- one type or predicate family;
- valid behavior before optional enhancements;
- source packaging before precompiled artifacts;
- compatibility characterization before implementation;
- correctness before optimization;
- schema behavior before rule behavior;
- read path before write path;
- internal support before public API stabilization;
- one supported platform before expanding the matrix.

Avoid splitting by arbitrary file boundaries when the result would not work independently.

## Selecting the first slice

Prefer the slice with the best combination of:

- immediate user value;
- ability to verify behavior;
- low architectural uncertainty;
- compatibility demand;
- ability to fail explicitly outside the supported boundary;
- reuse of existing implementation patterns;
- reasonable implementation cost.

Do not automatically select the most technically interesting slice.

## Handling discoveries during implementation

When implementation reveals another issue, classify it.

### Required blocker

The selected capability cannot work correctly without addressing it.

Include the smallest necessary fix and report why it became part of the slice.

### Related follow-up

The selected capability works without it.

Record it and do not implement it.

### Existing defect

The defect is independent of the selected capability.

Create or recommend a separate bug-fix task.

### Architectural uncertainty

The task cannot proceed safely without a durable decision.

Stop implementation and recommend an investigation or architecture-decision task.

### Unrelated cleanup

Do not implement it.

## Documentation budget

For ordinary feature or defect work:

- update documentation only when public truth changed;
- prefer editing existing authoritative documentation;
- avoid duplicate explanations;
- avoid future-oriented claims;
- do not create reports describing work already visible in the diff;
- do not test prose or document layout unless machine-consumed.

Documentation should answer a user or maintainer question, not prove that the agent completed a process.

## Team-work requirements

Minimal bureaucracy must still leave enough context for another contributor.

The selected task should communicate:

- what outcome is being delivered;
- what is intentionally excluded;
- how correctness will be verified;
- which public or operational contract changes;
- which risks remain;
- which follow-up ideas were deferred.

This information normally belongs in:

- the issue;
- the pull-request description;
- focused tests;
- directly affected documentation.

Do not create another permanent artifact unless these locations are insufficient.

## Stop conditions

Stop before implementation when:

- no independently useful slice can be identified;
- requested behavior is too ambiguous to verify;
- several public capabilities are inseparable only because the design is unclear;
- the change requires speculative infrastructure;
- a new architecture must be selected first;
- expected scope materially exceeds repository guardrails;
- supported and unsupported behavior cannot be distinguished safely;
- success criteria cannot be stated;
- the task requires release, migration, or platform commitments not explicitly approved.

Stop during implementation when:

- the selected slice expands into another independent capability;
- more than one new general abstraction becomes necessary;
- documentation becomes a substantial portion of the diff;
- tests begin validating process rather than behavior;
- unrelated cleanup starts accumulating;
- compatibility requires recreating a major external subsystem;
- correctness cannot be preserved within the approved boundary.

Stopping is a valid result.

Report the smallest next decision or experiment instead of generating a broad new roadmap.

## Anti-patterns

Do not:

- implement the entire roadmap in one run;
- treat every nearby TODO as part of the task;
- create infrastructure before a concrete feature uses it;
- produce multiple planning and completion documents;
- add meta-tests to enforce documentation structure;
- freeze an API before its supported subset is proven;
- introduce deprecation machinery before stability requires it;
- prepare release automation during feature implementation;
- redesign architecture to avoid a small amount of duplication;
- broaden support claims beyond executable evidence;
- continue coding merely because token or time budget remains.

## Scope preflight format

Before implementation, respond using this compact structure:

```text
Outcome:
<one independently useful result>

Included:
- <required behavior>
- <required behavior>

Not included:
- <adjacent feature>
- <unrelated cleanup>
- <speculative infrastructure>

Likely affected areas:
- <file or subsystem>
- <file or subsystem>

Verification:
- <focused test or command>
- <canonical repository check>

Estimated scope:
Small | Medium | Large

Decision:
Proceed | Split | Investigate | Request clarification
```
