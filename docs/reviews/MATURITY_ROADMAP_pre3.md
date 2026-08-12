# Maturity Roadmap: From Feature-Complete to Production-Ready

> Target: `dry-validation-rust` @ develop (0.1.0.pre3, post-PR #132)
> Review date: 2026-08-11
> Goal: Transform the feature-complete, internally clean compatibility layer into a mature, trusted public dependency.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [What pre3 Already Delivered](#2-what-pre3-already-delivered)
3. [Phase 0: Final Internal Cleanup](#3-phase-0-final-internal-cleanup)
4. [Phase 1: Distribution Ergonomics](#4-phase-1-distribution-ergonomics)
5. [Phase 2: Ecosystem Integration](#5-phase-2-ecosystem-integration)
6. [Phase 3: Community & Governance](#6-phase-3-community--governance)
7. [Appendix: Decision Log Template](#7-appendix-decision-log-template)

---

## 1. Executive Summary

pre3 is a **feature-complete, internally clean** compatibility layer. The monolithic `schema.rb` has been split into 7 focused files. The error buffer architecture has been rebuilt. Every item from the pre3 refactoring review has been addressed.

**The remaining work is external-facing:** distribution, social proof, documentation, and governance. The one remaining internal cleanup is the `Data` class migration for value objects (`Predicate`, `OptionDefinition`, `Message`, `Schema::Result`).

**The single most important insight remains:** Without precompiled native gems, 95% of Rubyists cannot install this. Without dry-rb maintainer outreach, you risk social/legal friction.

---

## 2. What pre3 Already Delivered

### Features

| Feature                             | PR   | Impact                                                 |
| ----------------------------------- | ---- | ------------------------------------------------------ |
| Predicate composition blocks        | #111 | `value(:integer) { gt? 18 }`                           |
| `config.validate_keys = true`       | #111 | Rejects unknown keys                                   |
| Custom dry-types fallback           | #109 | `value(MyApp::Types::Email)` via `RubyTypeProcessor`   |
| I18n / YAML message backend         | #110 | `config.messages.backend = :i18n` / `:yaml`            |
| `before` / `after` processor hooks  | #111 | `before(:value_coercer) { \|input\| input.strip }`     |
| Representative benchmark matrix     | #112 | 6 scenarios with throughput, latency, allocations, RSS |
| Allocation regression baseline gate | #113 | CI fails on >5% allocation regression                  |
| GVL integer coercion fast-path      | #117 | `fast_integer()` avoids `Kernel#Integer` callback      |
| Ruby engine stability fuzzer        | #116 | Random hash generation, no segfaults                   |
| Plan deserialization fuzz target    | #114 | `cargo fuzz` for `parse_plan`                          |

### Refactoring (post-review)

| Fix                                        | PR   | What changed                                                                                                 |
| ------------------------------------------ | ---- | ------------------------------------------------------------------------------------------------------------ |
| `schema.rb` split into `schema/` directory | #132 | 7 files: dsl, field_builder, field_definition, predicate_block, processor_hooks, result, ruby_type_processor |
| Error buffer → structured hashes           | —    | Rust returns `{path:, code:, text:}`; Ruby `native_errors_to_messages` eliminated                            |
| `dependency_error?` simplification         | #131 | Single prefix check                                                                                          |
| `run_evaluator` extraction                 | #130 | DRY for `execute_rule`/`execute_each`                                                                        |
| Range token interpolation                  | #129 | `size?: 3..5` produces `"3 to 5"`                                                                            |
| Predicate arity validation                 | #128 | `gt?(18, 19)` raises `ArgumentError`                                                                         |
| Hook shallow-copy docs                     | #127 | Documented `input.dup` behavior                                                                              |
| `non_finite_literal` allocation-free       | —    | `eq_ignore_ascii_case`                                                                                       |
| `report_unexpected_keys` HashSet           | —    | O(1) lookup                                                                                                  |
| Root-level `field_at_path` hash-ified      | —    | `@fields_by_name`                                                                                            |

---

## 3. Phase 0: Final Internal Cleanup

### Step 0.1 — Data class migration for value objects

**What:** Migrate `Predicate`, `OptionDefinition`, `Message`, and `Schema::Result` from `Struct` / hand-rolled classes to Ruby 3.2+ `Data`.

**Why:**

- `Data` is immutable by default, has automatic value equality, and provides `with` for copies
- `Message#==` currently excludes `predicate` and `args` — likely a bug that `Data` fixes automatically
- `Predicate` and `OptionDefinition` are still `Struct` — `Data` has lower overhead
- The gem requires Ruby `>= 3.3`, so `Data` is fully available

**Migration order:**

1. **`Predicate = Data.define(:name, :argument)`** — 5 min, update `deep_dup` to use `predicate.with(...)`
2. **`OptionDefinition = Data.define(:name, :default, :optional)`** — 5 min
3. **`Message = Data.define(:text, :path, :meta, :code, :source, :predicate, :args)`** — 30 min, update `with_text` → `with`, update all `Message.new` call sites
4. **`Schema::Result = Data.define(:output, :messages)`** — 15 min

**What NOT to migrate:** `Schema`, `Contract`, `FieldDefinition`, `FieldBuilder`, `Evaluator`, `MessageSet`, `Result` (Contract), `Values`, `MessageBackend`, `ProcessorHooks`, `Path`.

**Effort:** 1 hour
**Priority:** P0 — last internal cleanup

---

### Step 0.2 — Lock the public API for side-by-side mode

**What:** Declare `Dry::Validation::Rust::Contract` and its direct dependencies API-stable for the `0.1.x` line.

**Acceptance criteria:**

- All public methods on `Contract`, `Schema`, `Result`, `MessageSet`, `Evaluator`, `Values` have YARD documentation
- No breaking changes to side-by-side mode without a minor version bump
- Exact-compatibility mode remains explicitly experimental

**Effort:** 2–3 days
**Priority:** P0

---

### Step 0.3 — Establish a SemVer policy

**Policy draft:**

| Change type                         | Version bump    |
| ----------------------------------- | --------------- |
| New Ruby predicate / schema feature | Minor (`0.x.0`) |
| New platform gem                    | Minor (`0.x.0`) |
| Rust MSRV increase                  | Minor (`0.x.0`) |
| Removal of supported platform       | Major (`x.0.0`) |
| Public Ruby API change              | Major (`x.0.0`) |
| Native ABI change (Magnus version)  | Major (`x.0.0`) |

**Effort:** 1 day
**Priority:** P0

---

## 4. Phase 1: Distribution Ergonomics

> **Without this phase, adoption is near zero.**

### Step 1.1 — Integrate `rake-compiler-dock` for cross-compilation

**What:** Use `rb-sys-dock` to build native extensions for all target platforms.

**Target platforms (minimum viable):**

| Platform              | Gem platform name    | Priority |
| --------------------- | -------------------- | -------- |
| x86_64 Linux (glibc)  | `x86_64-linux`       | P0       |
| aarch64 Linux (glibc) | `aarch64-linux`      | P0       |
| x86_64 Linux (musl)   | `x86_64-linux-musl`  | P1       |
| aarch64 Linux (musl)  | `aarch64-linux-musl` | P1       |
| x86_64 macOS          | `x86_64-darwin`      | P0       |
| arm64 macOS           | `arm64-darwin`       | P0       |
| x64 Windows (UCRT)    | `x64-mingw-ucrt`     | P2       |

**Implementation:**

1. Add `rake-compiler` and `rake-compiler-dock` to `:development` dependencies.
2. Configure `Rake::ExtensionTask` with `cross_compile = true`.
3. Add GitHub Actions workflow for release tags that builds all platforms in parallel.

**Effort:** 3–5 days
**Blockers:** None

---

### Step 1.2 — Automate release pipeline

**What:** Pushing a git tag triggers:

1. Version bump verification
2. Full CI pass
3. Cross-compilation of all platform gems
4. Source gem build
5. Optional: Sigstore/cosign signing
6. Push to RubyGems.org

**Why:** Manual releases of native gems are error-prone.

**Effort:** 2 days

---

### Step 1.3 — Document installation paths

**What:** Update README with clear precompiled vs. from-source instructions.

````markdown
## Installation

### Precompiled (recommended)

```bash
gem install dry-validation-rust
```
````

### From source

Requires Rust 1.85+, libclang, and a C toolchain.

```bash
gem install dry-validation-rust --platform ruby
```

**Effort:** 2 hours

---

## 5. Phase 2: Ecosystem Integration

### Step 2.1 — Split exact-compat into optional gem

**What:** Move `require "dry/validation"` and `Dry::Validation::Contract` alias into `dry-validation-rust-compat`.

**Why:**

- Prevents accidental namespace collisions with upstream `dry-validation`
- Reduces support burden (collision issues go to the compat gem)
- Signals that exact mode is experimental and opt-in
- Allows independent versioning

**New structure:**

```

dry-validation-rust/ # safe namespace only
├── lib/dry/validation/rust.rb
dry-validation-rust-compat/ # exact shim (optional, depends on main gem)
├── lib/dry/validation.rb

```

**Migration path:**

1. Install `dry-validation-rust`, use side-by-side mode.
2. Once validated, add `dry-validation-rust-compat` and remove upstream gem.
3. If something breaks, remove `-compat` and fall back.

**Effort:** 2 days
**Priority:** P1

---

### Step 2.2 — Test Rails autoload / reload behavior

**What:** Ensure contracts defined in Rails models/controllers reload correctly in development.

**Why:** Native extensions can cache pointers or plans at the class level. If the Ruby class is reloaded but the Rust plan is not, subtle bugs appear.

**Test:**

```ruby
contract_class = Class.new(Dry::Validation::Rust::Contract) { ... }
Object.send(:remove_const, :MyContract) if defined?(:MyContract)
MyContract = contract_class
# Call it, verify results are correct
```

**Effort:** 1 day
**Priority:** P2

---

### Step 2.3 — Test `dry-auto_inject` integration

**What:** Verify contracts with injected options work when composed via `dry-auto_inject` or `dry-container`.

**Why:** Many dry-rb users rely on DI. If option resolution conflicts with auto-inject's keyword handling, it breaks the ecosystem promise.

**Effort:** 1 day
**Priority:** P2

---

### Step 2.4 — Explicit Ractor policy

**What:** Either certify Ractor safety or explicitly reject it with a clear error.

**Test:**

```ruby
contract = MyContract.new
ractor = Ractor.new(contract) do |c|
  c.call("age" => "21")
end
result = ractor.take
```

**If it crashes:** Add a guard:

```ruby
raise UnsupportedFeatureError, "Ractor usage is not supported" if defined?(Ractor) && Ractor.current != Ractor.main
```

**If it works:** Add to compatibility matrix as a selling point.

**Effort:** 1 day
**Priority:** P2

---

## 6. Phase 3: Community & Governance

### Step 3.1 — Reach out to dry-rb maintainers

**What:** Open a friendly issue/discussion with the Hanami/dry-rb team.

**Topics:**

- Goals (performance-oriented hybrid, not a hostile fork)
- Name acceptability (`dry-validation-rust`)
- Link in dry-rb docs as "alternative implementation"
- Licensing/attribution (`NOTICE.md` sufficiency)

**Why:** Getting ahead of social/legal friction is cheaper than dealing with it after you have users.

**Effort:** 1 day (writing) + async wait
**Priority:** P0

---

### Step 3.2 — Publish a "Getting Started" guide

**Required sections:**

1. Installation (precompiled vs. from source)
2. Your first contract (side-by-side mode)
3. Migration checklist from upstream dry-validation
4. Common pitfalls (exact mode collision, unsupported features)
5. Performance tuning tips

**Effort:** 2–3 days
**Priority:** P1

---

### Step 3.3 — Finish YARD API docs

**Classes to document:**

- `Dry::Validation::Rust::Contract`
- `Dry::Validation::Rust::Schema`
- `Dry::Validation::Rust::Result`
- `Dry::Validation::Rust::MessageSet`
- `Dry::Validation::Rust::Evaluator` (partially done)
- `Dry::Validation::Rust::Values`
- `Dry::Validation::Rust::Config` / `MessageConfig` / `MessageBackend`

**Effort:** 2 days
**Priority:** P1

---

### Step 3.4 — Establish a release cadence

**Proposal:**

- Patch releases (`0.1.x`) every 2 weeks for bug fixes
- Minor releases (`0.x.0`) every 6–8 weeks for new features
- Major release (`1.0.0`) when:
  - Side-by-side API is stable for 6+ months
  - All P0 compatibility features are implemented
  - Precompiled gems cover all Tier-1 platforms
  - At least one production user has publicly endorsed it

**Effort:** Ongoing
**Priority:** P1

---

### Step 3.5 — Create a public benchmark dashboard

**What:** GitHub Actions job that runs benchmarks on every commit to `main` and publishes results.

**Format:** Markdown table posted as a commit comment, or a simple GitHub Pages site.

**Example:**

```markdown
| Scenario            | dry-validation-rust | dry-validation | Ratio |
| ------------------- | ------------------: | -------------: | ----: |
| Small form (valid)  |            76,680/s |       36,879/s | 2.08× |
| Medium form (mixed) |             9,936/s |        2,880/s | 3.45× |
| Allocations/call    |                  85 |             49 | 1.73× |
```

**Effort:** 2 days
**Priority:** P2

---

## 7. Appendix: Decision Log Template

For each major decision during maturity work, record:

```markdown
## Decision: [Title]

- **Date:** YYYY-MM-DD
- **Context:** What problem were we solving?
- **Options considered:**
  1. Option A — pros/cons
  2. Option B — pros/cons
- **Decision:** We chose Option A because ...
- **Consequences:** What trade-offs did we accept?
- **Reversible?** Yes/No, and under what conditions.
```

Store these in `docs/decisions/`.

---

## Summary: Priority-Ordered Task List

### P0 — Blockers for any production claim

1. **Data class migration** (`Predicate`, `OptionDefinition`, `Message`, `Schema::Result`) — 1 hour
2. Lock side-by-side API + SemVer policy — 2–3 days
3. **Ship precompiled platform gems** — 3–5 days
4. **Reach out to dry-rb maintainers** — 1 day + wait

### P1 — Needed for confident adoption

5. Automate release pipeline with signing — 2 days
6. Split exact-compat into optional gem — 2 days
7. Publish Getting Started guide — 2–3 days
8. Finish YARD docs — 2 days
9. Establish release cadence — ongoing

### P2 — Nice to have, do after P0/P1

10. Test Rails autoload/reload — 1 day
11. Test `dry-auto_inject` — 1 day
12. Explicit Ractor policy — 1 day
13. Public benchmark dashboard — 2 days

---

_End of maturity roadmap (post-split)._"
