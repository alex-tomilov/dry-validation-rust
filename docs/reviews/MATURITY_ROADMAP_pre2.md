# Maturity Roadmap: From Prototype to Production-Ready Library

> Target: `dry-validation-rust` @ develop (0.1.0.pre2)
> Review date: 2026-08-04
> Goal: Transform the current feasibility prototype into a mature, trusted public dependency.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [What pre2 Already Delivered](#2-what-pre2-already-delivered)
3. [Phase 0: Foundation (Do This First)](#3-phase-0-foundation)
4. [Phase 1: Distribution Ergonomics](#4-phase-1-distribution-ergonomics)
5. [Phase 2: Compatibility Surface Expansion](#5-phase-2-compatibility-surface-expansion)
6. [Phase 3: Performance & Trust](#6-phase-3-performance--trust)
7. [Phase 4: Ecosystem Integration](#7-phase-4-ecosystem-integration)
8. [Phase 5: Community & Governance](#8-phase-5-community--governance)
9. [Appendix: Decision Log Template](#9-appendix-decision-log-template)

---

## 1. Executive Summary

The codebase has evolved rapidly from pre1 to pre2. Many internal quality issues have been resolved: the Rust engine is now cleanly phased, predicate dispatch uses enums, Ruby-side path lookups use hashes, and rule parameter introspection is cached. The gap between "good prototype" and "mature library" is now **almost entirely about distribution, compatibility surface, and social proof** — not internal architecture.

**The single most important insight remains:** Without precompiled native gems, 95% of Rubyists cannot install this. Without `validate_keys` and predicate composition blocks, teams cannot migrate existing `dry-validation` code. Without real-world benchmarks, there is no answer to "why Rust?"

---

## 2. What pre2 Already Delivered

pre2 addressed a significant portion of the pre1 maturity feedback:

| Area                  | pre1 Gap                                                                      | pre2 Fix                                                                         |
| --------------------- | ----------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| **Rust architecture** | Monolithic `process_value`                                                    | Phased: `coerce_and_validate_type`, `process_children`, `apply_field_predicates` |
| **Native efficiency** | String-matched predicates, allocating boolean coercion                        | `PredicateOp` enum, `eq_ignore_ascii_case`                                       |
| **Ruby path lookups** | Linear scans in `dependency_error?`, `apply_ruby_predicates`, `field_at_path` | Hash-backed `child_at`, `error_paths` Set, `schema_error_path_prefixes`          |
| **Rule execution**    | `block.parameters` introspected on every call                                 | Cached via `BlockKeywordParameters.extract`                                      |
| **Error format**      | Tuple arrays created per-error                                                | Flat native buffer with version header                                           |
| **Class resolution**  | Recursive plan walk per engine instance                                       | `used_kinds` HashSet pre-computed at plan parse                                  |
| **Build hygiene**     | Magnus exact-pin, no package manifest check                                   | `~0.8.2` semver pin, `cargo package --list` in CI                                |
| **Safety**            | No depth limits                                                               | `MAX_TRAVERSAL_DEPTH` (128) + `MAX_PLAN_JSON_NESTING` (512)                      |

This is excellent progress. The remaining work is **external-facing** rather than **internal cleanup**.

---

## 3. Phase 0: Foundation (Do This First)

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

**Why:** Native gems have additional breaking-change vectors: Rust MSRV bumps, platform support removals, ABI changes.

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

---

### Step 0.3 — Create a `SECURITY.md` with actual process

**What:** You have the file. Make it actionable.

**Required additions:**

- A dedicated security email or GitHub private vulnerability reporting enabled.
- A documented embargo period (e.g., 90 days after fix release).
- A `cargo audit` + `bundle audit` schedule (weekly in CI).

**Effort:** 1 day

---

## 4. Phase 1: Distribution Ergonomics

> **Without this phase, adoption is near zero.**

### Step 1.1 — Integrate `rake-compiler-dock` for cross-compilation

**What:** Use `rb-sys-dock` (or `rake-compiler-dock` directly) to build native extensions for all target platforms without owning the hardware.

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

**Implementation path:**

1. Add `rake-compiler` and `rake-compiler-dock` to `:development` dependencies.
2. Create `Rakefile` tasks:

   ```ruby
   require "rake/extensiontask"
   require "rb_sys"

   Rake::ExtensionTask.new("dry_validation_rust/native") do |ext|
     ext.lib_dir = "lib/dry/validation/rust"
     ext.source_pattern = "ext/dry_validation_rust/**/*.{rs,toml}"
     ext.cross_compile = true
     ext.cross_platform = %w[x86_64-linux aarch64-linux x86_64-darwin arm64-darwin]
   end
   ```

3. Add a GitHub Actions workflow that runs on release tags, builds all platforms in parallel, and uploads artifacts.
4. Use `gem push` with multiple `--platform` arguments, or use a release script.

**Effort:** 3–5 days
**Blockers:** None

---

### Step 1.2 — Add a `rubygems:push` workflow with artifact signing

**What:** Automate the release so that pushing a git tag triggers:

1. Version bump verification (tag == `lib/dry/validation/rust/version.rb`).
2. Full CI pass.
3. Cross-compilation of all platform gems.
4. Source gem build.
5. Optional: Sigstore/cosign signing of native artifacts.
6. Push to RubyGems.org.

**Why:** Manual releases of native gems are error-prone. A single wrong platform binary breaks users.

**Effort:** 2 days

---

### Step 1.3 — Document installation paths

**What:** Update README with:

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

## 5. Phase 2: Compatibility Surface Expansion

> **Without this phase, migration from upstream dry-validation is near impossible.**

### Step 2.1 — Implement `config.validate_keys = true`

**What:** Reject unknown keys in `params` and `json` modes, matching upstream `dry-schema` behavior.

**Why:** This is one of the most commonly used dry-schema features. Its absence is a silent behavioral difference that breaks security-sensitive forms.

**Implementation sketch:**

1. Add `validate_keys` to the JSON plan.
2. In `engine.rs` `process_hash`, after processing declared fields, iterate remaining keys in the input hash.
3. Emit `NativeError` with code `"unexpected_key"`.
4. On the Ruby side, map `"unexpected_key"` to the standard dry-schema message text.

**Effort:** 1–2 days
**Priority:** P0

---

### Step 2.2 — Implement predicate composition blocks

**What:** Support `value(:integer) { gt? 18 }` syntax.

**Why:** Extremely common in real-world dry-validation contracts. Currently raises `UnsupportedFeatureError`.

**Implementation sketch:**

1. In `Schema::FieldBuilder#value`, accept a block.
2. If a block is given, evaluate it in a mini-DSL context that collects predicates.
3. Serialize the collected predicates into the plan as a nested `predicates` array.
4. The Rust engine already supports multiple predicates per field; this is mostly a Ruby DSL change.

**Effort:** 2–3 days
**Priority:** P0

---

### Step 2.3 — Support custom dry-types / constructor objects

**What:** Allow `value(MyApp::Types::Email)` where `MyApp::Types::Email` is a `Dry::Types` constructor or sum type.

**Why:** Production dry-validation usage almost always wraps primitives in domain types.

**Implementation options:**

1. **Short term:** Detect custom types and fall back to Ruby-side processing for that field. Mark it in the plan as `"ruby_owned": true` and skip it in the Rust engine.
2. **Long term:** Serialize the type's `try` / `call` behavior into the plan. This is hard and probably not worth it for v1.

**Recommendation:** Implement option 1. It gives users a migration path without requiring a full dry-types reimplementation in Rust.

**Effort:** 2–3 days
**Priority:** P1

---

### Step 2.4 — Implement I18n / YAML message backend

**What:** Support `config.messages.backend = :i18n` and `config.messages.load_paths`.

**Why:** Rails teams depend on localized validation messages. The current hardcoded English messages are a blocker.

**Implementation sketch:**

1. Add `MessageConfig` backend switching (already partially present).
2. For `:yaml`, load `.yml` files into a nested hash keyed by locale → key → text template.
3. Replace `predicate_message` in `schema.rb` with a lookup into the message backend.
4. Support token interpolation (`%{num}` → actual value).
5. For `:i18n`, delegate to the `i18n` gem with the standard dry-validation key namespace.

**Effort:** 4–5 days
**Priority:** P1

---

### Step 2.5 — Implement `before` / `after` processor hooks

**What:** Allow `before(:value_coercer) { |input| input.strip }` in schema definitions.

**Why:** Common for sanitization (strip whitespace, normalize phone numbers).

**Implementation sketch:**

1. Collect hooks in the Ruby DSL.
2. Apply them in order before/after the native engine call.
3. Because hooks are arbitrary Ruby blocks, they cannot run inside Rust. Run them on the Ruby side, feeding the sanitized hash into the engine.

**Effort:** 2 days
**Priority:** P2

---

## 6. Phase 3: Performance & Trust

> **Without this phase, the "why Rust?" question has no answer.**

### Step 3.1 — Build a representative benchmark matrix

**What:** Replace the single synthetic benchmark with a suite covering real shapes.

**Benchmark scenarios:**

| Scenario         | Schema size          | Payload   | Mix        | Why it matters        |
| ---------------- | -------------------- | --------- | ---------- | --------------------- |
| Small form       | 5 fields             | 5 keys    | 100% valid | Web request baseline  |
| Medium form      | 25 fields            | 25 keys   | 80% valid  | Typical API payload   |
| Large form       | 100 fields           | 100 keys  | 50% valid  | Stress test           |
| Nested object    | 10 levels deep       | 10 levels | 100% valid | Deep traversal cost   |
| Array of objects | 100 items × 5 fields | 500 keys  | 90% valid  | Array member overhead |
| All-invalid      | 20 fields            | 20 keys   | 0% valid   | Error-path allocation |

**Metrics to capture:**

- Throughput (validations/second)
- Latency (p50, p95, p99)
- Ruby allocations per call (`GC.stat`)
- Native allocations (if possible via `dhat` or custom counters)
- Peak RSS under sustained load

**Effort:** 3–4 days
**Priority:** P0

---

### Step 3.2 — Add a memory profiler regression test

**What:** A CI job that fails if allocations per call increase by >5% compared to `main`.

**Implementation:**

```ruby
# test/memory_regression_test.rb
require "memory_profiler"

def allocations_per_call
  report = MemoryProfiler.report do
    1000.times { contract.call(payload) }
  end
  report.total_allocated / 1000.0
end

baseline = JSON.parse(File.read("benchmark/baseline_allocations.json"))
actual = allocations_per_call

assert actual <= baseline["allocations_per_call"] * 1.05,
       "Allocations regressed: #{actual} vs baseline #{baseline["allocations_per_call"]}"
```

**Effort:** 1 day
**Priority:** P1

---

### Step 3.3 — Add `cargo fuzz` target for plan deserialization

**What:** Fuzz `parse_plan` with random JSON to ensure no panics, no undefined behavior, and graceful error handling.

**Implementation:**

```bash
cargo install cargo-fuzz
cargo fuzz add parse_plan
cargo fuzz run parse_plan -- -max_total_time=300
```

**Acceptance criteria:**

- 5 minutes of fuzzing without panics.
- All malformed JSON produces a clean `ArgumentError` on the Ruby side.

**Effort:** 1–2 days
**Priority:** P1

---

### Step 3.4 — Add Ruby-level fuzzer for engine stability

**What:** Generate random Ruby Hashes (including cyclic references, extremely deep nesting, and unexpected types) and ensure the engine never segfaults.

**Why:** Ruby objects are complex. A `Hash` with a custom `default_proc` or a cyclic reference could confuse the Rust traversal if assumptions are violated.

**Implementation sketch:**

```ruby
# test/fuzz_engine_test.rb
require "fuzzbert"

fuzz "random hash input" do
  data { FuzzBert::Generators.random }
  deploy do |raw|
    input = generate_random_hash(raw)
    contract.new.call(input)
  rescue => e
    # Expected: validation errors, ArgumentError, etc.
    # Not expected: SIGSEGV, SIGABRT, Magnus::Error unwind leaks
  end
end
```

**Effort:** 2 days
**Priority:** P1

---

### Step 3.5 — Profile and optimize the GVL-holding path

**What:** The README correctly notes that the engine holds the GVL. Profile with `rbspy` or `perf` to find the biggest contributors.

**Likely hotspots to verify:**

1. `RHash::get` / `RHash::aset` — can these be batched?
2. `coerce` calling back into Ruby (`Kernel#Integer`, `Kernel#Float`, `Date.iso8601`).
3. `native_error_buffer_version` doing 4 constant lookups per call (see Refactoring §1.2).

**If profiling confirms significant time in Ruby callbacks:** Document it and add a "fast path" for common coercions (e.g., inline integer parsing in Rust instead of calling `Kernel#Integer`).

**Effort:** 2–3 days
**Priority:** P2

---

## 7. Phase 4: Ecosystem Integration

### Step 4.1 — Split exact-compatibility mode into optional add-on

**What:** Move `require "dry/validation"` and the `Dry::Validation::Contract` alias into a separate `dry-validation-rust-compat` gem.

**Why:** The current exact shim is dangerous. If a transitive dependency pulls in upstream `dry-validation`, your gem raises a `LoadError` at boot time. In a Rails app with 200 gems, this is a support nightmare.

**New structure:**

```
dry-validation-rust/           # safe namespace only
├── lib/dry/validation/rust.rb
dry-validation-rust-compat/    # exact shim (optional, depends on main gem)
├── lib/dry/validation.rb
```

**Migration path for users:**

1. Install `dry-validation-rust`, use side-by-side mode.
2. Once fully validated, add `dry-validation-rust-compat` and remove upstream gem.
3. If something breaks, remove `-compat` and fall back to side-by-side.

**Effort:** 2 days
**Priority:** P1

---

### Step 4.2 — Test Rails autoload / reload behavior

**What:** Ensure contracts defined in Rails models/controllers reload correctly in development.

**Why:** Native extensions can cache pointers or plans at the class level. If the Ruby class is reloaded but the Rust plan is not, subtle bugs appear.

**Test:**

```ruby
# In a Rails integration test
contract_class = Class.new(Dry::Validation::Rust::Contract) { ... }
Object.send(:remove_const, :MyContract) if defined?(:MyContract)
MyContract = contract_class
# Call it, verify results are correct
```

**Effort:** 1 day
**Priority:** P2

---

### Step 4.3 — Test `dry-auto_inject` integration

**What:** Verify that contracts with injected options work when composed via `dry-auto_inject` or `dry-container`.

**Why:** Many dry-rb users rely on DI. If option resolution conflicts with auto-inject's keyword handling, it breaks the ecosystem promise.

**Effort:** 1 day
**Priority:** P2

---

### Step 4.4 — Explicit Ractor policy

**What:** Either certify Ractor safety or explicitly reject it with a clear error.

**Test:**

```ruby
contract = MyContract.new
ractor = Ractor.new(contract) do |c|
  c.call("age" => "21")
end
result = ractor.take
```

**If it crashes:** Add a guard in `Contract#call`:

```ruby
raise UnsupportedFeatureError, "Ractor usage is not supported" if defined?(Ractor) && Ractor.current != Ractor.main
```

**If it works:** Add to compatibility matrix as a selling point.

**Effort:** 1 day
**Priority:** P2

---

## 8. Phase 5: Community & Governance

### Step 5.1 — Reach out to dry-rb maintainers

**What:** Before claiming compatibility or marketing the gem, open a friendly issue/discussion with the Hanami/dry-rb team.

**Topics to cover:**

- Your goals (performance-oriented hybrid, not a hostile fork).
- The name (`dry-validation-rust`) — is it acceptable or should it change?
- Whether they'd accept a link in dry-rb docs as an "alternative implementation."
- Any licensing/attribution concerns (you already have `NOTICE.md`; verify it's sufficient).

**Why:** Getting ahead of social/legal friction is cheaper than dealing with it after you have users.

**Effort:** 1 day (writing) + async wait for response
**Priority:** P0

---

### Step 5.2 — Publish a "Getting Started" guide

**What:** A user-facing guide that assumes zero Rust knowledge.

**Required sections:**

1. Installation (precompiled vs. from source)
2. Your first contract (side-by-side mode)
3. Migration checklist from upstream dry-validation
4. Common pitfalls (exact mode collision, unsupported features)
5. Performance tuning tips

**Effort:** 2–3 days
**Priority:** P1

---

### Step 5.3 — Generate YARD API docs

**What:** Document every public class and method.

**Classes to document:**

- `Dry::Validation::Rust::Contract`
- `Dry::Validation::Rust::Schema`
- `Dry::Validation::Rust::Result`
- `Dry::Validation::Rust::MessageSet`
- `Dry::Validation::Rust::Evaluator`
- `Dry::Validation::Rust::Values`

**Effort:** 2 days
**Priority:** P1

---

### Step 5.4 — Establish a release cadence

**What:** Move from ad-hoc releases to a predictable schedule.

**Proposal:**

- Patch releases (`0.1.x`) every 2 weeks for bug fixes.
- Minor releases (`0.x.0`) every 6–8 weeks for new features.
- Major release (`1.0.0`) when:
  - Side-by-side API is stable for 6+ months
  - All P0 compatibility features are implemented
  - Precompiled gems cover all Tier-1 platforms
  - At least one production user has publicly endorsed it

**Effort:** Ongoing
**Priority:** P1

---

### Step 5.5 — Create a public benchmark dashboard

**What:** A GitHub Actions job (or separate repo) that runs benchmarks on every commit to `main` and publishes results.

**Format:** Markdown table posted as a commit comment, or a simple GitHub Pages site.

**Example output:**

```markdown
| Scenario            | dry-validation-rust | dry-validation | Ratio |
| ------------------- | ------------------: | -------------: | ----: |
| Small form (valid)  |           450,000/s |      120,000/s | 3.75× |
| Medium form (mixed) |           180,000/s |       55,000/s | 3.27× |
| Allocations/call    |                  12 |             89 | 0.13× |
```

**Effort:** 2 days
**Priority:** P2

---

## 9. Appendix: Decision Log Template

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
3. Implement `config.validate_keys = true` (Step 2.1)
4. Implement predicate composition blocks (Step 2.2)
5. Build representative benchmark suite (Step 3.1)
6. Reach out to dry-rb maintainers (Step 5.1)

### P1 — Needed for confident adoption

7. Automate release pipeline with signing (Step 1.2)
8. Support custom types via Ruby fallback (Step 2.3)
9. Implement I18n/YAML message backend (Step 2.4)
10. Add `cargo fuzz` + Ruby fuzzer (Step 3.3, 3.4)
11. Add memory regression test (Step 3.2)
12. Split exact-compat into optional gem (Step 4.1)
13. Publish Getting Started guide (Step 5.2)
14. Generate YARD docs (Step 5.3)
15. Establish release cadence (Step 5.4)

### P2 — Nice to have, do after P0/P1

16. Implement `before`/`after` hooks (Step 2.5)
17. Profile and optimize GVL path (Step 3.5)
18. Test Rails autoload/reload (Step 4.2)
19. Test `dry-auto_inject` (Step 4.3)
20. Explicit Ractor policy (Step 4.4)
21. Public benchmark dashboard (Step 5.5)

---

_End of maturity roadmap (pre2)._"
