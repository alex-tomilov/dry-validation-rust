# Milestone E — Implement one migration-driven compatibility slice

## How to use this file

Reuse this instruction once per selected feature. Replace the placeholders before giving it to Codex. Never ask Codex to implement all candidate features in one run.

## Selected capability

**Feature:** `[one feature only]`

**Realistic contract or user need:**

```ruby
# Paste the smallest realistic contract that cannot currently migrate.
```

**Expected supported syntax:**

```ruby
# Paste the exact syntax this slice will support.
```

**Expected unsupported adjacent syntax:**

```ruby
# Paste one or more nearby forms that must still fail explicitly.
```

## Primary outcome

Implement the smallest coherent form of the selected capability, backed by pinned upstream behavior and without creating a general subsystem for hypothetical future variants.

## Required selection evidence

Before coding, confirm all of the following:

- the feature blocks a realistic contract, benchmark, or reported use case;
- upstream behavior can be captured reliably;
- the feature fits the Ruby/Rust ownership boundary;
- supported and unsupported forms can be distinguished;
- the feature can be delivered as one reviewable vertical slice.

If any item fails, stop and report rather than implementing.

## Step 1 — Characterize upstream behavior

Add focused upstream fixtures before or with implementation.

Cover:

- one valid case;
- one invalid case;
- output Ruby classes if coercion is involved;
- error path and metadata at the supported level;
- inheritance/reuse interaction if relevant;
- one adjacent unsupported form;
- exception behavior for invalid DSL configuration.

Do not copy a broad upstream test directory.

## Step 2 — Define the exact support boundary

Write a concise implementation note in the task/issue, not a new repository document:

- supported form;
- unsupported forms;
- Ruby-side responsibilities;
- Rust-side responsibilities;
- expected failure class for unsupported forms;
- compatibility and performance risks.

Do not redesign architecture beyond this feature.

## Step 3 — Implement the direct path

Prefer:

- extending an existing plan node or predicate table;
- adding a focused Ruby DSL compiler branch;
- adding a focused native execution branch;
- reusing existing error normalization.

Avoid:

- a generic plugin framework;
- a feature registry for one feature;
- a new configuration subsystem;
- a broad AST abstraction;
- changes to unrelated predicates/types/rules;
- premature public API generalization.

## Step 4 — Fail loudly around the boundary

Adjacent unsupported forms must:

- be recognized deterministically;
- raise a specific documented exception;
- never become a no-op;
- never silently use different semantics;
- never be accepted only because the parser is permissive.

Add focused failure tests.

## Step 5 — Compatibility verification

Compare:

- normalized output values;
- Ruby classes;
- success/failure state;
- errors and paths;
- rule execution impact where relevant;
- exceptions;
- input mutation.

If exact parity is impractical, either narrow the supported form or keep the feature unsupported. Do not hide the difference in normalization.

## Step 6 — Performance safety check

Run representative existing benchmarks affected by the feature.

Requirements:

- no material regression without a documented reason;
- no benchmark-only shortcut;
- no new public performance claim unless measured across representative cases.

A feature may be accepted despite a small justified cost when it unlocks important compatibility, but the cost must be visible.

## Step 7 — Minimal documentation

Update only:

- `COMPATIBILITY.md` for support boundary;
- `CHANGELOG.md` for user-visible behavior, when appropriate.

Do not create a feature design document. Keep additions under the ordinary documentation budget.

## Acceptance criteria

- The realistic contract works for the selected form.
- Upstream fixtures exist for valid and invalid behavior.
- Output, errors, and exceptions match the declared compatibility level.
- Adjacent unsupported syntax raises explicitly.
- Existing tests pass.
- Representative performance does not materially regress without justification.
- No generic subsystem was introduced solely for this feature.
- No unrelated backlog feature was implemented.

## Stop conditions

Stop and report when:

- the feature requires complete `dry-types` or `dry-logic` compatibility;
- message parity requires implementing all I18n backends;
- the feature cannot be distinguished from unsupported variants;
- the implementation needs unsafe Ruby access outside the GVL;
- the diff will exceed the change-size guardrail;
- more than one public capability is necessary.

## Delivery response

Report:

1. selected supported form;
2. realistic contract now enabled;
3. files changed;
4. verification results;
5. unsupported variants and exception classes;
6. performance effect;
7. follow-up ideas intentionally left in the backlog.
