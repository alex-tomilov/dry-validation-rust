# Refactoring, Optimization & Polish — `dry-validation-rust` 0.1.0.pre2

> Review date: 2026-08-04  
> Target: develop branch @ 0.1.0.pre2  
> Scope: Rust native extension, Ruby contract layer, build & packaging

---

## What has already been fixed since pre1

The following items from the pre1 review have been implemented in pre2 and are **no longer actionable**:

| # | Previous recommendation | Status | Evidence |
|---|------------------------|--------|----------|
| 1 | Flatten `engine.rs` traversal into discrete phases | ✅ Done | `process_field`, `resolve_field_input`, `coerce_and_validate_type`, `process_children`, `apply_field_predicates` |
| 2 | Eliminate `to_ascii_lowercase()` allocation in boolean coercion | ✅ Done | `eq_ignore_ascii_case` in `coercion.rs` |
| 3 | Replace runtime string matching with `PredicateOp` enum | ✅ Done | `PredicateOp` enum in `plan.rs`, match in `predicates.rs` |
| 4 | Cache class lookups via `used_kinds` HashSet | ✅ Done | `collect_used_kinds` + `RuntimeClasses::new` |
| 5 | Build `error_paths` Set in `apply_ruby_predicates` | ✅ Done | `error_paths = messages.to_set(&:path)` |
| 6 | Store `FieldDefinition#children` as Hash + Array | ✅ Done | `children_by_name` + `child_at` |
| 7 | Cache `block.parameters` at rule definition | ✅ Done | `BlockKeywordParameters.extract` in `rule.rb` |
| 8 | Optimize `dependency_error?` with Sets | ✅ Done | `schema_error_paths` + `schema_error_path_prefixes` |
| 9 | Relax Magnus pin to `~0.8.2` | ✅ Done | `Cargo.toml` |
| 10 | Add `cargo package --list` to CI | ✅ Done | `.github/workflows/ci.yml` |
| 11 | Reduce transient Ruby objects in error reporting | ✅ Done | Flat native error buffer with version header |

---

## 1. Rust Core — Remaining Opportunities

### 1.1 `coercion.rs` — `non_finite_literal` still allocates

**Current state:**

```rust
fn non_finite_literal(source: &str) -> bool {
    matches!(
        source.trim().to_ascii_lowercase().as_str(),
        "infinity" | "+infinity" | ...
    )
}
```

**Problem:** `trim().to_ascii_lowercase()` allocates a `String` on every float coercion attempt. This was fixed for `params_boolean` but not here.

**Fix:** Use `eq_ignore_ascii_case` on the trimmed view, or match byte slices:

```rust
fn non_finite_literal(source: &str) -> bool {
    let s = source.trim();
    s.eq_ignore_ascii_case("infinity")
        || s.eq_ignore_ascii_case("+infinity")
        || s.eq_ignore_ascii_case("-infinity")
        || s.eq_ignore_ascii_case("inf")
        || s.eq_ignore_ascii_case("+inf")
        || s.eq_ignore_ascii_case("-inf")
        || s.eq_ignore_ascii_case("nan")
        || s.eq_ignore_ascii_case("+nan")
        || s.eq_ignore_ascii_case("-nan")
}
```

**Impact:** Low effort, eliminates allocation on every float field validation.

---

### 1.2 `engine.rs` — `native_error_buffer_version` does 4 Ruby constant lookups per call

**Current state:**

```rust
fn native_error_buffer_version(ruby: &Ruby) -> Result<usize, Error> {
    let dry: RModule = ruby.class_object().const_get("Dry")?;
    let validation: RModule = dry.const_get("Validation")?;
    let rust: RModule = validation.const_get("Rust")?;
    let schema: RClass = rust.const_get("Schema")?;
    let version: Integer = schema.const_get("NATIVE_ERROR_BUFFER_VERSION")?;
    version.to_usize()
}
```

**Problem:** This runs on **every** `Engine::call`, doing 4 nested `const_get` calls into Ruby's constant tables. For high-throughput validation this is pure overhead.

**Fix:** Cache the version integer once at engine construction time:

```rust
pub(crate) struct Engine {
    plan: SchemaPlan,
    classes: RuntimeClasses,
    plan_bytes: usize,
    error_buffer_version: usize, // <-- add this
}

impl Engine {
    pub(crate) fn new(ruby: &Ruby, json: String) -> Result<Self, Error> {
        let plan = parse_plan(ruby, &json)?;
        let classes = RuntimeClasses::new(ruby, &plan)?;
        let error_buffer_version = native_error_buffer_version(ruby)?; // <-- cache here
        Ok(Self {
            plan,
            classes,
            plan_bytes: json.len(),
            error_buffer_version,
        })
    }

    pub(crate) fn call(&self, input: RHash) -> Result<(RHash, RArray), Error> {
        // ...
        ruby_errors.push(self.error_buffer_version)?; // <-- use cached value
        // ...
    }
}
```

**Impact:** Low effort, removes 4 Ruby API calls from every validation.

---

### 1.3 `engine.rs` — `within_depth_limit` allocates on error path

**Current state:**

```rust
errors.push(NativeError::new(
    path,
    DEPTH_ERROR_CODE,
    format!("schema nesting depth exceeds limit ({MAX_TRAVERSAL_DEPTH})"),
));
```

**Problem:** `format!` allocates a `String` only when the depth limit is exceeded. For hostile/malformed payloads this could be frequent.

**Fix:** Use a static error message or `format_args!`:

```rust
const DEPTH_ERROR_TEXT: &str = "schema nesting depth exceeds limit (128)";
// or if you need the dynamic number:
fn depth_error_text() -> &'static str {
    // Since MAX_TRAVERSAL_DEPTH is const, the message is statically known
    "schema nesting depth exceeds limit (128)"
}
```

**Impact:** Trivial, reduces allocation on adversarial input.

---

### 1.4 `engine.rs` — `process_field` closure pattern is unnecessary

**Current state:**

```rust
fn process_field(...) -> Result<(), Error> {
    let name = field.name.as_deref().unwrap_or_default();
    path.push(PathPart::Key(name.to_owned()));
    let result = (|| match resolve_field_input(...) {
        Some(raw) => { ... }
        None => { ... }
    })();
    path.pop();
    result
}
```

**Problem:** The immediately-invoked closure `(|| { ... })()` is used solely to ensure `path.pop()` runs after the match. This is clever but adds an unnecessary closure layer and makes stack traces slightly harder to read.

**Fix:** Use `try`/`finally` semantics via `drop` guard or explicit control flow:

```rust
fn process_field(...) -> Result<(), Error> {
    let name = field.name.as_deref().unwrap_or_default();
    path.push(PathPart::Key(name.to_owned()));
    let result = match resolve_field_input(input, traversal.ruby, traversal.mode, name) {
        Some(raw) => output.aset(...),
        None => { report_missing_field(...); Ok(()) }
    };
    path.pop();
    result
}
```

**Impact:** Trivial, improves readability and stack traces.

---

### 1.5 `ruby_bridge.rs` — `mark` iterates over 4 `Option` branches every GC cycle

**Current state:**

```rust
pub(crate) fn mark(&self, marker: &Marker) {
    for class in [self.date, self.date_time, self.time, self.big_decimal]
        .into_iter()
        .flatten()
    {
        marker.mark(class);
    }
}
```

**Problem:** Every GC mark phase iterates an array of 4 options and flattens them. This is negligible but could be slightly more efficient.

**Fix:** Store classes in a small `Vec<Opaque<RClass>>` or use a const array of active slots:

```rust
pub(crate) fn mark(&self, marker: &Marker) {
    if let Some(c) = self.date { marker.mark(c); }
    if let Some(c) = self.date_time { marker.mark(c); }
    if let Some(c) = self.time { marker.mark(c); }
    if let Some(c) = self.big_decimal { marker.mark(c); }
}
```

Or keep the array but pre-compute it at construction time. This is truly micro-optimization territory.

**Impact:** Trivial.

---

### 1.6 `plan.rs` — `ensure_plan_json_nesting` is hand-rolled JSON parsing

**Current state:** A byte-by-byte scanner that tracks `{`, `}`, `[`, `]`, and `"` with escape handling.

**Problem:** While it works for the specific purpose of counting nesting depth, it is ~40 lines of code that must be maintained. Any edge case in JSON string escaping (e.g., `"`) could theoretically confuse it, though the consequences are harmless (just a wrong depth count).

**Fix options:**
1. **Keep it** — it's simple and works. Add a comment explaining why serde's built-in limit isn't used.
2. **Use `serde_json::StreamDeserializer`** with a custom depth tracker — more complex, not obviously better.
3. **Document the invariant** that plan JSON is always machine-generated and never contains exotic escape sequences.

**Recommendation:** Add a comment in the source:

```rust
// This scanner assumes the plan JSON is machine-generated by the Ruby DSL
// and does not contain Unicode escapes or other exotic string content.
// It exists because serde_json's depth limit was disabled to support
// very wide (but not deep) schemas.
```

**Impact:** Trivial, prevents future maintainers from "fixing" it unnecessarily.

---

## 2. Ruby Layer — Remaining Opportunities

### 2.1 `schema.rb` — `native_errors_to_messages` is complex manual buffer parsing

**Current state:** ~50 lines of manual index arithmetic to decode the flat native error buffer.

**Problem:** This is error-prone and tightly coupled to the Rust buffer layout. If the Rust side changes header sizes, this will silently misparse or crash.

**Fix:** Move the buffer-to-messages conversion to a small Rust helper method, or at minimum add a Ruby-level schema validation test that deliberately corrupts the buffer and asserts a `NativeExtensionError` is raised.

**Better fix:** Add a Rust method `Engine#decode_errors` that returns an array of `Message`-like hashes:

```rust
// In lib.rs
class.define_method("decode_errors", method!(Engine::decode_errors, 1))?;

// In engine.rs
pub(crate) fn decode_errors(&self, ruby_errors: RArray) -> Result<RArray, Error> {
    // Parse the flat buffer and return [ {path: [...], code: :sym, text: "..."}, ... ]
}
```

This would eliminate the Ruby-side parsing entirely and keep the format logic in one place.

**Impact:** Medium effort, significantly reduces coupling risk.

---

### 2.2 `schema.rb` — `field_at_path` still does linear search at root level

**Current state:**

```rust
// In field_at_path:
definition = if definition
  definition.child_at(part)
else
  definitions.find { |field| field.name == part.to_sym }
end
```

**Problem:** The root-level `definitions` is still an Array. `child_at` is O(1) for nested children, but the top level is O(siblings).

**Fix:** Store top-level fields in a Hash as well, or make `Schema#fields` return a wrapper with both array and hash views:

```ruby
class Schema
  def initialize(mode:, fields:)
    @fields = fields.freeze
    @fields_by_name = fields.to_h { |f| [f.name, f] }.freeze
    # ...
  end

  def field_at_path(path)
    definition = nil
    path.each do |part|
      if part.is_a?(Integer)
        return nil unless definition&.member
        definition = definition.member
      else
        definition = definition ? definition.child_at(part) : @fields_by_name[part.to_sym]
        return nil unless definition
      end
    end
    definition
  end
end
```

**Impact:** Low effort, completes the O(1) path lookup optimization.

---

### 2.3 `contract.rb` — `execute_rule` and `execute_each` duplicate evaluator pattern

**Current state:**

```ruby
def execute_rule(rule, result, context)
  evaluator = Evaluator.new(...)
  evaluator.execute(rule.block, rule.macro_calls, keyword_params: rule.keyword_params)
    .failures.each { |failure| result.add_error(failure) }
end

def execute_each(rule, result, context)
  # ...
  evaluator = Evaluator.new(...)
  evaluator.execute(rule.block, rule.macro_calls, keyword_params: rule.keyword_params)
    .failures.each { |failure| result.add_error(failure) }
  # ...
end
```

**Problem:** The `Evaluator` construction + execution + failure collection is duplicated.

**Fix:** Extract a helper:

```ruby
def run_evaluator(rule, result, context, paths:, index: nil)
  evaluator = Evaluator.new(
    contract: self,
    result: result,
    paths: paths,
    context: context,
    index: index
  )
  evaluator.execute(rule.block, rule.macro_calls, keyword_params: rule.keyword_params)
    .failures.each { |failure| result.add_error(failure) }
end
```

**Impact:** Trivial, DRY.

---

### 2.4 `contract.rb` — `dependency_error?` second check is partially redundant

**Current state:**

```ruby
def dependency_error?(schema_error_paths, schema_error_path_prefixes, path)
  return true if schema_error_path_prefixes.include?(path)

  path.length.downto(0).any? { |length| schema_error_paths.include?(path.take(length)) }
end
```

**Problem:** The `schema_error_path_prefixes` Set contains *all* prefixes of all error paths. If an error path is `[:profile, :age]`, then `[:profile]` and `[:profile, :age]` are in the prefixes Set. The second check (`path.take(length)`) checks if any prefix of `path` is an error path. But if `path` is `[:profile, :age, :name]`, then `[:profile, :age]` is a prefix of `path` and is also in `schema_error_path_prefixes` (as a prefix of the error path `[:profile, :age]`). Wait — `schema_error_path_prefixes` contains prefixes of *error paths*, not prefixes of *rule paths*. So `[:profile, :age]` is in `schema_error_path_prefixes` because it's a prefix of the error path `[:profile, :age]`. And `[:profile, :age]` is also a prefix of the rule path `[:profile, :age, :name]`. So the first check `schema_error_path_prefixes.include?(path)` would only match if `path` itself is exactly `[:profile, :age]` or `[:profile]`. It would NOT match `[:profile, :age, :name]` because that exact array is not in the prefixes Set.

So both checks are indeed needed:
- Check 1: `path` is a prefix of an error path (e.g., rule path `[:profile]`, error at `[:profile, :age]`)
- Check 2: A prefix of `path` is an error path (e.g., rule path `[:profile, :age, :name]`, error at `[:profile, :age]`)

However, check 2 could be optimized by also including all error paths themselves in the prefixes Set (they are already there as length-N prefixes). Actually they are! `schema_error_path_prefixes` is built as:

```ruby
schema_error_path_prefixes = schema_error_paths.each_with_object(Set.new) do |error_path, prefixes|
  (0..error_path.length).each { |length| prefixes << error_path.take(length) }
end
```

So `error_path.take(error_path.length)` equals `error_path` itself. Therefore `schema_error_path_prefixes` contains ALL error paths AND all their prefixes. This means check 2 is actually covered by check 1 if we reframe it: if any prefix of `path` is an error path, then that prefix is in `schema_error_path_prefixes`. But check 1 asks if `path` itself is in `schema_error_path_prefixes`. That's not the same as asking if any prefix of `path` is in `schema_error_path_prefixes`.

Actually, we could replace both checks with one:

```ruby
def dependency_error?(schema_error_path_prefixes, path)
  path.length.downto(1).any? { |length| schema_error_path_prefixes.include?(path.take(length)) }
end
```

This checks if any prefix of `path` (including `path` itself) is a prefix of any error path. This is equivalent to the original logic but does only one Set lookup per prefix.

**Impact:** Low effort, slightly cleaner.

---

### 2.5 `schema.rb` — `apply_ruby_predicates_at` mutates `error_paths` Set during recursion

**Current state:**

```ruby
def apply_ruby_predicates_at(definitions, data, prefix, messages, error_paths)
  # ...
  messages << predicate_message(predicate, path)
  error_paths << path
  # ...
end
```

**Problem:** While Ruby Sets are safe for `include?` during mutation, mutating a collection during recursive descent is generally discouraged as it creates hidden coupling between levels.

**Fix:** Return newly discovered error paths from the recursive method instead of mutating the shared Set:

```ruby
def apply_ruby_predicates_at(definitions, data, prefix, messages, error_paths)
  return [] unless data.is_a?(Hash)

  new_errors = []
  definitions.each do |field|
    # ...
    unless error_paths.include?(path) || new_errors.include?(path)
      # apply predicates...
      if invalid
        messages << predicate_message(...)
        new_errors << path
      end
    end
    new_errors.concat(apply_ruby_predicates_at(field.children, value, path, messages, error_paths + new_errors))
  end
  new_errors
end
```

This is more functional and easier to reason about, though slightly more verbose.

**Impact:** Low effort, improves maintainability.

---

### 2.6 `message_set.rb` — `messages` reader should return frozen view

**Current state:** `attr_reader :messages` returns the mutable internal array.

**Problem:** The changelog says "Changed `MessageSet#messages` to return a read-only view" but the code still exposes the raw array. Callers can accidentally mutate it.

**Fix:**

```ruby
def messages
  @messages.dup.freeze
end
```

Or if performance is a concern:

```ruby
def messages
  @messages.freeze # freeze once, return frozen reference
  @messages
end
```

**Impact:** Trivial, honors the documented contract.

---

## 3. Build & Packaging

### 3.1 `Cargo.toml` — `version` still says `0.1.0-pre.1`

**Current state:**

```toml
[package]
name = "dry_validation_rust_native"
version = "0.1.0-pre.1"
```

**Problem:** The gem is at `0.1.0.pre2` but the Rust crate is still at `0.1.0-pre.1`. This is confusing for debugging and could cause issues if the crate is ever published separately.

**Fix:** Bump to `0.1.0-pre.2` or derive from a shared source of truth.

**Impact:** Trivial.

---

### 3.2 `gemspec` — `spec.files` includes `ext/dry_validation_rust/src/**/*.rs` but not test data

**Current state:** The gemspec explicitly lists source files. This is good, but verify that no test fixtures or benchmark data leak into the gem.

**Recommendation:** Add a CI step that runs `gem contents dry-validation-rust` after `gem install` to verify the installed file list matches expectations.

**Impact:** Trivial.

---

## 4. Testing & Quality

### 4.1 Add a test for native error buffer version mismatch

**What:** Deliberately corrupt the buffer version byte and assert `NativeExtensionError` is raised.

**Why:** The flat buffer format is a tight coupling. A version mismatch test ensures graceful failure instead of silent mis-parsing.

```ruby
def test_native_error_buffer_version_mismatch
  # This would require mocking the engine or using a private API
  # Alternatively, test via a future schema feature that bumps the version
end
```

**Impact:** Low effort, safety net.

---

### 4.2 Add a test for `non_finite_literal` allocation path

**What:** Ensure that passing `"Infinity"` to a float field does not allocate a `String` on the coercion path.

**Why:** This is the remaining allocation hotspot after the `params_boolean` fix.

**Impact:** Low effort, can be verified with `MemoryProfiler`.

---

## 5. Quick-Win Checklist (pre2)

| # | Task | File(s) | Effort | Impact |
|---|------|---------|--------|--------|
| 1 | Fix `non_finite_literal` allocation | `coercion.rs` | 10 min | Medium |
| 2 | Cache `native_error_buffer_version` in Engine | `engine.rs` | 15 min | Medium |
| 3 | Use static string for depth limit error | `engine.rs` | 5 min | Low |
| 4 | Remove IIFE closure in `process_field` | `engine.rs` | 10 min | Low |
| 5 | Add comment to `ensure_plan_json_nesting` | `plan.rs` | 5 min | Low |
| 6 | Move error buffer parsing to Rust or add corruption test | `schema.rb` / `engine.rs` | 2–4 hrs | High |
| 7 | Hash-ify root-level field lookup in `field_at_path` | `schema.rb` | 20 min | Medium |
| 8 | Extract `run_evaluator` helper in Contract | `contract.rb` | 15 min | Low |
| 9 | Simplify `dependency_error?` to single prefix check | `contract.rb` | 15 min | Low |
| 10 | Freeze `MessageSet#messages` return value | `message_set.rb` | 5 min | Low |
| 11 | Bump `Cargo.toml` version to match gem | `Cargo.toml` | 2 min | Low |

---

*End of pre2 refactoring review.*
