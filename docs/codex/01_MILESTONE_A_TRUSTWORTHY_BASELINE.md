# Milestone A — Establish the trustworthy baseline

## Role of this task

Turn the existing prototype into a verifiable experimental baseline. Do not add broad new DSL capabilities. The main product change is trustworthy evidence about what already works and explicit failure for what does not.

## Primary outcome

A contributor can run one canonical command and obtain:

- the ordinary Ruby/Rust test results;
- a compact differential comparison against one pinned upstream `dry-validation` release;
- deterministic failures for recognized unsupported constructs;
- a source-gem build and clean-install smoke result.

## Scope

### Included

- pin one upstream compatibility target;
- establish a compact differential harness;
- add at least 25 representative contracts covering already advertised schema and rule behavior;
- compare processed values, Ruby classes, success state, errors, exceptions, and rule traces where needed;
- isolate exact compatibility mode from upstream in separate processes;
- define one canonical verification entry point;
- remove only redundant planning/meta-test artifacts that directly interfere with this workflow.

### Explicitly excluded

- new predicates or coercions;
- new rule forms;
- full upstream suite integration;
- API freezing;
- deprecation infrastructure;
- exhaustive YARD work;
- precompiled gems;
- broad documentation rewrite;
- benchmark optimization.

## Step 1 — Inventory current claims

Inspect:

- `README.md`;
- `COMPATIBILITY.md`;
- current Ruby DSL implementation;
- Rust plan/execution code;
- test files;
- existing differential or compatibility helpers;
- gemspec and Rake tasks.

Create a temporary local checklist outside the repository that maps each currently claimed feature to:

- existing test coverage;
- whether upstream evidence exists;
- whether unsupported adjacent syntax is rejected;
- likely fixture location.

Do not commit the checklist.

## Step 2 — Pin the upstream target

Choose one exact `dry-validation` version already compatible with the repository's Ruby requirements.

Requirements:

- store the version in one machine-readable place;
- avoid duplicating the version across scripts;
- ensure differential subprocesses load the intended engine and version;
- document the target in the existing compatibility document, not in a new file.

Do not update to the newest upstream version as a side task.

## Step 3 — Design the minimal differential format

The harness should accept fixture cases that can describe:

- contract source or a fixture identifier;
- input;
- result value;
- class names for coerced values;
- success/failure;
- normalized errors;
- expected exception class/message category;
- optional rule execution trace.

Prefer a simple format already natural to the repository, such as Ruby fixtures or compact JSON-safe snapshots. Do not build a generic test framework.

Normalize only unstable representation details. Never normalize away semantic differences.

## Step 4 — Process isolation

Run upstream and Rust-backed exact mode in separate Ruby processes so constants, require paths, and gems cannot contaminate one another.

Prove isolation with a focused regression test or subprocess smoke case.

Do not attempt to load both exact namespaces into one process merely to simplify the harness.

## Step 5 — Add the initial corpus

Add at least 25 representative cases, selected from behavior already claimed as supported:

- required and optional scalar keys;
- Params coercion;
- `filled` and `maybe`;
- nested hash;
- array of primitives;
- array of hashes;
- invalid coercion;
- missing keys;
- at least one predicate failure;
- single-key rule;
- multi-key rule;
- base failure;
- nested failure path;
- rule skipping;
- macro or option/context behavior already supported;
- inheritance or contract reuse already supported.

Include both successful and failing inputs.

## Step 6 — Unsupported feature fixtures

Select recognized unsupported constructs already listed in compatibility documentation. Add focused cases proving they raise a deterministic explicit exception.

At minimum consider:

- unsupported type objects;
- unknown predicates;
- unsupported schema mode or hook;
- unsupported predicate-composition syntax;
- unsupported extension/configuration syntax.

Do not convert unsupported syntax into a validation error.

## Step 7 — Fix only baseline mismatches

When the differential corpus exposes a mismatch:

1. determine whether the behavior is already claimed as supported;
2. if yes, fix the smallest semantic mismatch;
3. if no, make it fail explicitly and update `COMPATIBILITY.md` minimally;
4. do not implement an adjacent feature to make the fixture pass.

If a mismatch requires a large subsystem, mark the construct unsupported and stop that branch of work.

## Step 8 — Canonical verification command

Provide one existing or new minimal Rake task/script that runs the canonical baseline checks. It may orchestrate existing commands, but must not replace standard tooling with a custom framework.

The command should cover:

- compile;
- Ruby tests;
- Rust tests/lints required by the project;
- differential corpus;
- source gem build;
- clean-install smoke test.

Keep optional expensive benchmarks outside this command.

## Step 9 — Remove only proven redundancy

Delete stage prompts, duplicate planning documents, or meta-tests only when:

- the refreshed roadmap/AGENTS files supersede them;
- no unique technical knowledge would be lost;
- deletion directly reduces conflicting instructions.

Do not perform general repository cleanup.

## Acceptance criteria

- One exact upstream version is pinned in one authoritative place.
- At least 25 representative contracts execute against both engines.
- The comparison includes values, Ruby classes, success state, errors, and exceptions.
- Exact mode and upstream run in isolated processes.
- Every unsupported construct in the initial corpus raises explicitly.
- A clean checkout can build the source gem.
- A temporary consumer project can install and call a basic contract.
- The canonical verification command succeeds.
- No new planning hierarchy or documentation meta-tests are introduced.

## Required checks

Run the repository's actual equivalents of:

```bash
bundle exec rake compile
bundle exec rake test
cargo fmt --check --manifest-path ext/dry_validation_rust/Cargo.toml
cargo test --locked --manifest-path ext/dry_validation_rust/Cargo.toml
cargo clippy --manifest-path ext/dry_validation_rust/Cargo.toml --all-targets --all-features -- -D warnings
gem build dry-validation-rust.gemspec
```

Also run the canonical differential and clean-install smoke commands created or confirmed by this task.

## Exit gate

Milestone A is complete only when the existing supported subset has executable evidence and unsupported adjacent syntax is explicit. Do not begin Milestone B merely because the harness exists.
