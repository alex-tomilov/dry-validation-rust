# Milestone F — Package and platform hardening

## Role of this task

Make installation and native-extension failure behavior dependable on platforms the project explicitly advertises. Do not multiply platform commitments prematurely.

## Primary outcome

A clean consumer project can install the built gem and run a basic contract on every advertised Ruby/platform pair verified by CI.

## Scope

### Included

- source-gem build/install smoke tests;
- explicit CRuby/platform support matrix;
- CI verification for advertised pairs;
- native-extension load errors;
- panic and exception-boundary review;
- GC review for retained Ruby objects;
- targeted memory/thread stress tests;
- compiler/native dependency documentation;
- precompiled gems only if maintainable and separately proven.

### Explicitly excluded

- JRuby support;
- Ractor claims;
- every OS/architecture combination;
- precompiled gems for untested platforms;
- signing/release publication unless explicitly requested later;
- unrelated compatibility features.

## Step 1 — Audit current packaging

Inspect:

- gemspec file list and extensions;
- `extconf.rb`/rb-sys/magnus setup;
- Cargo lock/profile configuration;
- Rake build tasks;
- CI matrix;
- README installation instructions;
- native load fallback/error behavior.

Identify the smallest initial advertised matrix. Prefer platforms already exercised by contributors or CI.

## Step 2 — Source-gem consumer smoke test

Automate a clean temporary consumer flow:

1. build the gem;
2. create an empty temporary Bundler project;
3. install the built gem without repository load paths;
4. require the public namespace;
5. define and call a minimal contract;
6. verify result and native extension loading.

This test must use packaged files, not source-tree shortcuts.

## Step 3 — Package contents

Ensure the built gem includes only required:

- Ruby runtime files;
- Rust/native build sources needed for source installation;
- lock/build metadata needed for reproducibility;
- license;
- concise user documentation.

Exclude:

- local build products;
- raw benchmarks;
- temporary plans;
- upstream checkouts;
- editor/agent artifacts;
- secrets or crash dumps.

Do not add tests that merely snapshot every filename unless package-content regression has caused a real problem. Prefer a focused denylist/required-files smoke check.

## Step 4 — Supported matrix

For each advertised pair, CI must:

- install prerequisites;
- build the native extension;
- run Ruby and Rust verification;
- build the gem;
- install it in a clean consumer project;
- execute the smoke contract.

Mark unverified pairs as untested, not supported.

Keep the matrix small enough to maintain.

## Step 5 — Native load failures

Test failure cases such as:

- missing compiled extension;
- incompatible architecture;
- missing build toolchain for source installation where detectable;
- incompatible Ruby version.

Produce concise actionable errors. Do not silently fall back to a semantically different Ruby engine unless such a fallback is an explicit product feature.

## Step 6 — Panic and Ruby exception boundaries

Review every exported native entry point.

Requirements:

- Rust panics are prevented or contained;
- Ruby exceptions propagate through supported mechanisms;
- no `unwrap`/`expect` remains in user-controlled runtime paths without a documented invariant;
- conversion failures become explicit Ruby exceptions;
- unsupported plan nodes never reach unreachable code.

Add focused tests for actual boundary risks, not blanket meta-tests.

## Step 7 — GC and retained objects

Inventory whether Rust stores any Ruby object beyond the immediate call.

For each retained object, verify:

- rooting/marking;
- compaction handling;
- lifetime ownership;
- thread restrictions;
- cleanup.

Prefer storing Rust-owned immutable plan data instead of Ruby objects.

Do not create a generic GC abstraction if no object retention requires it.

## Step 8 — Stress tests

Add bounded stress cases for actual risk areas:

- repeated contract creation/destruction;
- repeated invalid nested payloads;
- exceptions during rules;
- multiple threads under the GVL;
- large but realistic arrays;
- extension load/unload assumptions where applicable.

Measure for unbounded growth rather than requiring perfectly flat RSS.

## Step 9 — Precompiled gem decision

Treat precompiled gems as a separate experiment.

Proceed only when:

- source installation is stable;
- target platforms are verified;
- CI/release tooling is maintainable;
- artifact provenance and testing are clear.

Do not add all platforms at once. Begin with one high-value platform pair and prove the release path without publishing.

## Acceptance criteria

- The built source gem installs in a clean consumer project.
- Every advertised platform/Ruby pair passes build, install, and smoke tests in CI.
- Native load failures are actionable.
- No known panic crosses FFI.
- Retained Ruby objects, if any, have correct GC handling.
- Stress cases show no obvious unbounded leak in supported use.
- Package contents exclude local/generated clutter.
- Documentation claims only verified platforms.

## Required verification

Run:

- full canonical verification;
- source gem build;
- clean consumer install smoke;
- CI matrix or equivalent local containers for advertised pairs;
- targeted panic/GC/stress tests;
- package content inspection.

## Stop conditions

Stop platform expansion when:

- the platform cannot be tested in CI;
- maintenance cost exceeds current user value;
- precompiled artifacts cannot be verified reproducibly;
- support requires architecture changes unrelated to packaging.

## Exit gate

Milestone F is complete when installation behavior is dependable for a deliberately small verified matrix. It is not complete merely because the gem builds on one developer machine.
