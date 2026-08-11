# Maturity Roadmap: From Prototype to Production-Ready Library

> Target: `dry-validation-rust` @ develop (0.1.0.pre3)  
> Review date: 2026-08-10  
> Goal: Transform the current feature-complete prototype into a mature, trusted public dependency.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [What pre3 Already Delivered](#2-what-pre3-already-delivered)
3. [Phase 0: Foundation](#3-phase-0-foundation)
4. [Phase 1: Distribution Ergonomics](#4-phase-1-distribution-ergonomics)
5. [Phase 2: Architecture Hardening](#5-phase-2-architecture-hardening)
6. [Phase 3: Ecosystem Integration](#6-phase-3-ecosystem-integration)
7. [Phase 4: Community & Governance](#7-phase-4-community--governance)
8. [Appendix: Decision Log Template](#8-appendix-decision-log-template)

---

## 1. Executive Summary

pre3 is a feature-complete compatibility layer. The internal architecture is solid: phased Rust engine, enum predicate dispatch, hash-backed lookups, cached rule parameters, flat error buffers, GVL fast-paths, fuzzing, benchmarks, and allocation regression gates. The gap between "feature-complete" and "mature library" is now **almost entirely about distribution, social proof, and organizational cleanliness**.

**The single most important insight:** Without precompiled native gems, 95% of Rubyists cannot install this. Without dry-rb maintainer outreach, you risk social/legal friction. Without splitting the monolithic `schema.rb`, the codebase will become unmaintainable as more contributors arrive.

---

## 2. What pre3 Already Delivered

Since pre2, the following major features landed:

| Feature | PR | Impact |
|---------|-----|--------|
| Predicate composition blocks | #111 | `value(:integer) { gt? 18 }` syntax |
| `config.validate_keys = true` | #111 | Rejects unknown keys in params/json mode |
| Custom dry-types fallback | #109 | `value(MyApp::Types::Email)` via `RubyTypeProcessor` |
| I18n / YAML message backend | #110 | `config.messages.backend = :i18n` / `:yaml` |
| `before` / `after` processor hooks | #111 | `before(:value_coercer) { \|input\| input.strip }` |
| Representative benchmark matrix | #112 | 6 scenarios with throughput, latency, allocations, RSS |
| Allocation regression baseline gate | #113 | CI fails if allocations per call regress >5% |
| GVL integer coercion fast-path | #117 | `fast_integer()` avoids `Kernel#Integer` callback for canonical forms |
| Ruby engine stability fuzzer | #116 | Random hash generation, no segfaults |
| Plan deserialization fuzz target | #114 | `cargo fuzz` for `parse_plan` |

The project has crossed from **"feasibility prototype"** to **"feature-complete compatibility layer"**.

---

## 3. Phase 0: Foundation

### Step 0.1 — Lock the public API for side-by-side mode

**What:** Declare `Dry::Validation::Rust::Contract` and its direct dependencies API-stable for the `0.1.x` line.

**Why:** You cannot iterate on distribution or compatibility if the API is still moving.

**Acceptance criteria:**
- All public methods on `Contract`, `Schema`, `Result`, `MessageSet`, `Evaluator`, `Values` have YARD documentation.
- No breaking changes to side-by-side mode without a minor version bump.
- Exact-compatibility mode remains explicitly experimental.

**Effort:** 2–3 days

---

### Step 0.2 — Establish a SemVer policy

**What:** Document what constitutes a breaking change for a native gem.

**Policy draft:**

| Change type | Version bump |
|-------------|-------------|
| New Ruby predicate / schema feature | Minor (`0.x.0`) |
| New platform gem | Minor (`0.x.0`) |
| Rust MSRV increase | Minor (`0.x.0`) |
| Removal of supported platform | Major (`x.0.0`) |
| Public Ruby API change | Major (`x.0.0`) |
| Native ABI change (Magnus version) | Major (`x.0.0`) |

**Effort:** 1 day

---

### Step 0.3 — File organization (split monolithic files)

**What:** Split `schema.rb` (23,874 bytes, 8 concepts) and reorganize `contract.rb` nested classes.

**Why:**
- **Cognitive load:** Contributors fixing a predicate-block bug must read through `Schema::Result`, `ProcessorHooks`, `RubyTypeProcessor`, `DSL`, and `FieldDefinition` to understand the file.
- **Merge conflicts:** PRs adding `each` support and PRs adding custom-type handling both touch `schema.rb`.
- **Test isolation:** Testing `FieldDefinition#deep_dup` requires loading the entire engine, DSL, hooks, and message backend.
- **YARD docs:** 8 classes in one file make generated docs noisy.

**Proposed structure:**

```
lib/dry/validation/rust/
├── schema/
│   ├── result.rb              # Schema::Result
│   ├── processor_hooks.rb     # ProcessorHooks
│   ├── field_definition.rb    # FieldDefinition + Predicate
│   ├── field_builder.rb       # FieldBuilder + PredicateBlock
│   ├── ruby_type_processor.rb # RubyTypeProcessor
│   └── dsl.rb                 # DSL
├── schema.rb                  # Schema (orchestrator only)
├── contract/
│   ├── result.rb              # Contract::Result
│   └── values.rb              # Contract::Values
├── contract.rb                # Contract (orchestrator)
└── ...
```

**What stays in `schema.rb`:**
- `Schema.define`, `Schema.Params`, `Schema.JSON`
- `Schema#initialize`, `Schema#call`, `Schema#key_paths`, `Schema#inspect`
- Private helpers: `paths_for`, `apply_ruby_predicates`, `predicate_valid?`, `predicate_message`, `native_predicate_details`

**What NOT to split:**
- `PredicateBlock` stays in `field_builder.rb` — only used by `FieldBuilder#value`.
- `Message` (~15 lines) stays in `message.rb`.
- `Path` (~20 lines) stays in `path.rb`.
- Don't create circular requires.

**Effort:** 1–2 days

---

## 4. Phase 1: Distribution Ergonomics

> **Without this phase, adoption is near zero.**

### Step 1.1 — Integrate `rake-compiler-dock` for cross-compilation

**What:** Use `rb-sys-dock` to build native extensions for all target platforms.

**Target platforms (minimum viable):**

| Platform | Gem platform name | Priority |
|----------|-------------------|----------|
| x86_64 Linux (glibc) | `x86_64-linux` | P0 |
| aarch64 Linux (glibc) | `aarch64-linux` | P0 |
| x86_64 Linux (musl) | `x86_64-linux-musl` | P1 |
| aarch64 Linux (musl) | `aarch64-linux-musl` | P1 |
| x86_64 macOS | `x86_64-darwin` | P0 |
| arm64 macOS | `arm64-darwin` | P0 |
| x64 Windows (UCRT) | `x64-mingw-ucrt` | P2 |

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

```markdown
## Installation

### Precompiled (recommended)
```bash
gem install dry-validation-rust
```

### From source
Requires Rust 1.85+, libclang, and a C toolchain.
```bash
gem install dry-validation-rust --platform ruby
```
```

**Effort:** 2 hours

---

## 5. Phase 2: Architecture Hardening

### Step 2.1 — Move error buffer decoding to Rust

**What:** Replace flat `[version, path_len, sym, idx, ...]` buffer with an array of `{path:, code:, text:}` hashes from Rust.

**Why:**
- Eliminates ~50 lines of fragile Ruby index arithmetic.
- Removes 6 cross-language coupling constants (`NATIVE_ERROR_BUFFER_VERSION`, `NATIVE_ERROR_BUFFER_HEADER_SIZE`, etc.).
- The format is private and versioned; moving it to Rust keeps the logic in one place.

**Implementation sketch:**

```rust
// In engine.rs
let messages = ruby.ary_new();
for error in errors {
    let hash = ruby.hash_new();
    let path_ary = ruby.ary_new();
    for part in &error.path {
        match part {
            PathPart::Key(key) => path_ary.push(ruby.to_symbol(key))?,
            PathPart::Index(index) => path_ary.push(index)?,
        }
    }
    hash.aset(ruby.to_symbol("path"), path_ary)?;
    hash.aset(ruby.to_symbol("code"), ruby.to_symbol(error.code))?;
    hash.aset(ruby.to_symbol("text"), ruby.str_new(error.text))?;
    messages.push(hash)?;
}
```

Then Ruby `Schema#call` becomes:

```ruby
def call(input)
  output, error_hashes = engine.call(input)
  messages = error_hashes.map do |hash|
    predicate, args = native_predicate_details(hash[:path], hash[:code])
    Message.new(
      native_error_message(hash[:code], hash[:text], predicate, args, hash[:path]),
      path: hash[:path], code: hash[:code], source: :schema,
      predicate: predicate, args: args
    )
  end
  # ...
end
```

**Effort:** 2–4 hours  
**Priority:** P1

---

### Step 2.2 — Profile GVL-holding path

**What:** Use `rbspy` or `perf` to identify the biggest contributors to GVL hold time.

**Likely hotspots:**
1. `RHash::get` / `RHash::aset` — can these be batched?
2. `coerce` calling back into Ruby (`Date.iso8601`, `Time.parse`, `BigDecimal`)
3. Float coercion still calls `Kernel#Float` (no fast-path yet)

**If profiling confirms significant time in Ruby callbacks:**
- Add `fast_float()` similar to `fast_integer()`
- Document which coercions hold the GVL and for how long
- Consider caching `Date.iso8601` results for repeated identical strings

**Effort:** 1–2 days  
**Priority:** P2

---

### Step 2.3 — Expand fuzzing coverage

**What:** The fuzz targets exist but should run in CI on every PR, not just scheduled.

**Actions:**
1. Add `cargo fuzz run parse_plan -- -max_total_time=60` to PR CI
2. Add Ruby fuzzer to PR CI (60 seconds of random hash generation)
3. Add a corpus of real-world plan JSONs to the fuzzer for guided mutation

**Effort:** 1 day  
**Priority:** P1

---

## 6. Phase 3: Ecosystem Integration

### Step 3.1 — Split exact-compat into optional gem

**What:** Move `require "dry/validation"` and `Dry::Validation::Contract` alias into `dry-validation-rust-compat`.

**Why:**
- Prevents accidental namespace collisions with upstream `dry-validation`
- Reduces support burden (collision issues go to the compat gem)
- Signals that exact mode is experimental and opt-in
- Allows independent versioning

**New structure:**

```
dry-validation-rust/           # safe namespace only
├── lib/dry/validation/rust.rb
dry-validation-rust-compat/    # exact shim (optional, depends on main gem)
├── lib/dry/validation.rb
```

**Migration path:**
1. Install `dry-validation-rust`, use side-by-side mode.
2. Once validated, add `dry-validation-rust-compat` and remove upstream gem.
3. If something breaks, remove `-compat` and fall back.

**Effort:** 2 days  
**Priority:** P1

---

### Step 3.2 — Test Rails autoload / reload behavior

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

### Step 3.3 — Test `dry-auto_inject` integration

**What:** Verify contracts with injected options work when composed via `dry-auto_inject` or `dry-container`.

**Why:** Many dry-rb users rely on DI. If option resolution conflicts with auto-inject's keyword handling, it breaks the ecosystem promise.

**Effort:** 1 day  
**Priority:** P2

---

### Step 3.4 — Explicit Ractor policy

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

## 7. Phase 4: Community & Governance

### Step 4.1 — Reach out to dry-rb maintainers

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

### Step 4.2 — Publish a "Getting Started" guide

**Required sections:**
1. Installation (precompiled vs. from source)
2. Your first contract (side-by-side mode)
3. Migration checklist from upstream dry-validation
4. Common pitfalls (exact mode collision, unsupported features)
5. Performance tuning tips

**Effort:** 2–3 days  
**Priority:** P1

---

### Step 4.3 — Finish YARD API docs

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

### Step 4.4 — Establish a release cadence

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

### Step 4.5 — Create a public benchmark dashboard

**What:** GitHub Actions job that runs benchmarks on every commit to `main` and publishes results.

**Format:** Markdown table posted as a commit comment, or a simple GitHub Pages site.

**Example:**

```markdown
| Scenario | dry-validation-rust | dry-validation | Ratio |
|----------|--------------------:|---------------:|------:|
| Small form (valid) | 450,000/s | 120,000/s | 3.75× |
| Medium form (mixed) | 180,000/s | 55,000/s | 3.27× |
| Allocations/call | 12 | 89 | 0.13× |
```

**Effort:** 2 days  
**Priority:** P2

---

## 8. Appendix: Decision Log Template

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
1. Lock side-by-side API + SemVer policy
2. Ship precompiled platform gems (Step 1.1)
3. Reach out to dry-rb maintainers (Step 4.1)
4. Split monolithic `schema.rb` into `schema/` directory (Step 0.3)

### P1 — Needed for confident adoption
5. Automate release pipeline with signing (Step 1.2)
6. Move error buffer decoding to Rust (Step 2.1)
7. Add fuzzing to PR CI (Step 2.3)
8. Split exact-compat into optional gem (Step 3.1)
9. Publish Getting Started guide (Step 4.2)
10. Finish YARD docs (Step 4.3)
11. Establish release cadence (Step 4.4)

### P2 — Nice to have, do after P0/P1
12. Profile GVL path for float fast-path (Step 2.2)
13. Test Rails autoload/reload (Step 3.2)
14. Test `dry-auto_inject` (Step 3.3)
15. Explicit Ractor policy (Step 3.4)
16. Public benchmark dashboard (Step 4.5)

---

*End of maturity roadmap (pre3).*"
