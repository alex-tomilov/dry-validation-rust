# Refactoring, Optimization & Polish — `dry-validation-rust` 0.1.0.pre3

> Review date: 2026-08-10  
> Target: develop branch @ 0.1.0.pre3  
> Scope: Rust native extension, Ruby contract layer, file organization

---

## Table of Contents

1. [What pre3 Already Fixed](#1-what-pre3-already-fixed)
2. [Rust Core — Remaining](#2-rust-core--remaining)
3. [Ruby Layer — Remaining](#3-ruby-layer--remaining)
4. [File Organization — New for pre3](#4-file-organization--new-for-pre3)
5. [Quick-Win Checklist](#5-quick-win-checklist)

---

## 1. What pre3 Already Fixed

| # | Previous recommendation | Status | Evidence |
|---|------------------------|--------|----------|
| 1 | Cache `native_error_buffer_version` in Engine | ✅ Done | `error_buffer_version` field, resolved once in `Engine::new` |
| 2 | Integer coercion fast-path | ✅ Done | `fast_integer()` in `coercion.rs`, delegates to Ruby for non-canonical forms |
| 3 | `validate_keys` → Rust | ✅ Done | `Traversal.validate_keys`, `report_unexpected_keys` in `engine.rs` |
| 4 | `cargo fuzz` target for plan parsing | ✅ Done | PR #114 merged |
| 5 | Ruby-level engine stability fuzzer | ✅ Done | PR #116 merged |
| 6 | GVL-held integer coercion optimization | ✅ Done | PR #117 merged |

---

## 2. Rust Core — Remaining

### 2.1 `coercion.rs` — `non_finite_literal` still allocates

**Current state:**

```rust
fn non_finite_literal(source: &str) -> bool {
    matches!(
        source.trim().to_ascii_lowercase().as_str(),
        "infinity" | "+infinity" | "-infinity" | "inf" | "+inf" | "-inf" | "nan" | "+nan" | "-nan"
    )
}
```

**Problem:** `trim().to_ascii_lowercase()` allocates a `String` on every float coercion attempt. The same fix applied to `params_boolean` (using `eq_ignore_ascii_case`) was not applied here.

**Fix:**

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

### 2.2 `engine.rs` — `within_depth_limit` allocates on error path

**Current state:**

```rust
errors.push(NativeError::new(
    path,
    DEPTH_ERROR_CODE,
    format!("schema nesting depth exceeds limit ({MAX_TRAVERSAL_DEPTH})"),
));
```

**Problem:** `format!` allocates a `String` only when the depth limit is exceeded. For hostile/malformed payloads this could be frequent.

**Fix:** Use a statically formatted message or `format_args!`:

```rust
const DEPTH_ERROR_TEXT: &str = "schema nesting depth exceeds limit (128)";
// Or keep dynamic but use a lazy static:
fn depth_error_text() -> &'static str {
    "schema nesting depth exceeds limit (128)"
}
```

Since `MAX_TRAVERSAL_DEPTH` is a `const`, the message is statically known at compile time.

**Impact:** Trivial, reduces allocation on adversarial input.

---

### 2.3 `engine.rs` — `process_field` IIFE closure

**Current state:**

```rust
let result = (|| match resolve_field_input(...) {
    Some(raw) => { ... }
    None => { ... }
})();
path.pop();
result
```

**Problem:** The immediately-invoked closure is used solely to ensure `path.pop()` runs. This adds an unnecessary closure layer and makes stack traces slightly harder to read.

**Fix:**

```rust
path.push(PathPart::Key(name.to_owned()));
let result = match resolve_field_input(input, traversal.ruby, traversal.mode, name) {
    Some(raw) => {
        let processed = process_value(traversal, field, raw, path, depth)?;
        output.aset(traversal.ruby.to_symbol(name), processed)
    }
    None => {
        report_missing_field(traversal, field, path);
        Ok(())
    }
};
path.pop();
result
```

**Impact:** Trivial, improves readability and stack traces.

---

### 2.4 `engine.rs` — `report_unexpected_keys` is O(n·m)

**Current state:**

```rust
input.foreach(|key: Value, _: Value| {
    let mut declared = false;
    for field in fields {
        let name = field.name.as_deref().unwrap_or_default();
        if key.eql(traversal.ruby.to_symbol(name))? || key.eql(traversal.ruby.str_new(name))? {
            declared = true;
            break;
        }
    }
    // ...
})
```

**Problem:** For every key in the input hash, it scans all declared fields. For schemas with many fields and large input hashes, this is quadratic.

**Fix:** Build a `HashSet` of declared names once, before the loop:

```rust
fn report_unexpected_keys(
    traversal: &mut Traversal<'_>,
    fields: &[FieldPlan],
    input: RHash,
    path: &[PathPart],
) -> Result<(), Error> {
    if !traversal.validate_keys || traversal.mode == Mode::Schema {
        return Ok(());
    }

    let declared: std::collections::HashSet<&str> = fields
        .iter()
        .filter_map(|f| f.name.as_deref())
        .collect();

    input.foreach(|key: Value, _: Value| {
        let key_name: String = key.funcall("to_s", ())?;
        if !declared.contains(key_name.as_str()) {
            let mut error_path = path.to_vec();
            error_path.push(PathPart::Key(key_name));
            traversal.errors.push(NativeError::new(&error_path, "unexpected_key", ""));
        }
        Ok(ForEach::Continue)
    })
}
```

**Note:** The current code compares `key.eql(symbol)` and `key.eql(string)`. Using `HashSet<&str>` with `key_name` from `to_s` is equivalent for Symbol and String keys but avoids the per-key Ruby `eql` calls.

**Impact:** Low effort, significant speedup for wide schemas with `validate_keys`.

---

### 2.5 `engine.rs` — `report_unexpected_keys` pushes empty-string error text

**Current state:**

```rust
traversal.errors.push(NativeError::new(&error_path, "unexpected_key", ""));
```

**Problem:** The error text is empty. Ruby `schema.rb` has a fallback:

```ruby
fallback: code == :unexpected_key ? 'is not allowed' : native_text
```

This means the Rust side emits an empty string that Ruby immediately replaces. The two sides are coupled by a magic code name.

**Fix:** Emit the full text from Rust:

```rust
traversal.errors.push(NativeError::new(&error_path, "unexpected_key", "is not allowed"));
```

Then remove the special-case fallback in Ruby. This makes the error text authoritative in one place.

**Impact:** Trivial, reduces cross-language coupling.

---

## 3. Ruby Layer — Remaining

### 3.1 `schema.rb` — Root-level `field_at_path` is still linear

**Current state:**

```ruby
definition = if definition
  definition.child_at(part)
else
  definitions.find { |field| field.name == part.to_sym }
end
```

**Problem:** The top-level `definitions` is still an Array. `child_at` is O(1) for nested children (via `children_by_name` Hash), but the root level is O(siblings).

**Fix:** Store top-level fields in a Hash as well. Add `@fields_by_name` to `Schema`:

```ruby
def initialize(mode:, fields:, ...)
  @mode = mode.to_sym
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
```

**Impact:** Low effort, completes the O(1) path lookup optimization.

---

### 3.2 `schema.rb` — `native_errors_to_messages` is manual buffer parsing

**Current state:** ~50 lines of index arithmetic decoding the flat native buffer:

```ruby
def native_errors_to_messages(native_errors)
  unless native_errors.fetch(0) == NATIVE_ERROR_BUFFER_VERSION
    raise NativeExtensionError, ...
  end
  messages = []
  offset = NATIVE_ERROR_BUFFER_HEADER_SIZE
  while offset < native_errors.length
    path_length = native_errors.fetch(offset)
    # ... 30 more lines of arithmetic
  end
  messages
end
```

**Problem:** This is the last major coupling between Rust encoder and Ruby decoder. The format is private, versioned, and fragile. If the Rust side changes header sizes, this silently mis-parses or crashes.

**Fix options:**

**Option A (recommended):** Move decoding to Rust. Return an array of `{path:, code:, text:}` hashes:

```rust
// In engine.rs
let messages = ruby.ary_new();
for error in errors {
    let hash = ruby.hash_new();
    let path_ary = ruby.ary_new();
    for part in &error.path { ... }
    hash.aset(ruby.to_symbol("path"), path_ary)?;
    hash.aset(ruby.to_symbol("code"), ruby.to_symbol(error.code))?;
    hash.aset(ruby.to_symbol("text"), ruby.str_new(error.text))?;
    messages.push(hash)?;
}
let result = ruby.ary_new_capa(2);
result.push(output)?;
result.push(messages)?;
Ok(result)
```

Then Ruby becomes:

```ruby
def call(input)
  output, error_hashes = engine.call(input)
  messages = error_hashes.map do |hash|
    path = hash[:path]
    code = hash[:code]
    text = hash[:text]
    predicate, args = native_predicate_details(path, code)
    Message.new(...)
  end
  # ...
end
```

This eliminates:
- `NATIVE_ERROR_BUFFER_VERSION`
- `NATIVE_ERROR_BUFFER_HEADER_SIZE`
- `NATIVE_ERROR_RECORD_PATH_LENGTH_SIZE`
- `NATIVE_ERROR_RECORD_CODE_OFFSET`
- `NATIVE_ERROR_RECORD_TEXT_OFFSET`
- `NATIVE_ERROR_RECORD_TRAILER_SIZE`
- `native_errors_to_messages` method entirely

**Option B:** Keep the flat buffer but add a corruption test that deliberately mutates the buffer and asserts `NativeExtensionError`.

**Recommendation:** Option A. It removes ~40 lines of fragile Ruby code and ~6 constants.

**Impact:** Medium effort, high architectural cleanliness.

---

### 3.3 `schema.rb` — `ProcessorHooks.apply` mutates `input.dup` shallow copy

**Current state:**

```ruby
prepared_input = ProcessorHooks.apply(before_hooks, input.dup)
```

**Problem:** `input.dup` is a shallow copy. If a `before` hook mutates nested hashes in place, the original `input` is still mutated. This is surprising for callers.

**Fix options:**
1. **Document it:** Add a comment: "Hooks receive a shallow dup; in-place mutation of nested structures affects the original input."
2. **Deep copy:** Use `Marshal.load(Marshal.dump(input))` — expensive but safe.
3. **Freeze and document:** Freeze the input before passing to hooks, forcing hooks to return new hashes.

**Recommendation:** Option 1 for now (document the behavior). Option 3 if hooks become a common source of bug reports.

---

### 3.4 `schema.rb` — `PredicateBlock` lacks arity validation

**Current state:**

```ruby
def method_missing(name, *args, **kwargs, &block)
  if name.to_s.end_with?('?') && block.nil?
    argument = if kwargs.empty?
      args.length <= 1 ? args.first : args
    else
      kwargs
    end
    @definition.add_predicate(name, argument: argument.nil? || argument)
    return self
  end
  # ...
end
```

**Problem:** `gt?(18, 19)` produces `argument = [18, 19]`. When serialized to JSON, this becomes a JSON array. The Rust `PredicateArg::List` would deserialize it, but `gt?` expects a single numeric argument. This will likely panic or behave unexpectedly.

**Fix:** Add arity validation per predicate:

```ruby
# In PredicateBlock or FieldBuilder
SINGLE_ARG_PREDICATES = %i[gt gteq lt lteq min_size max_size size eql not_eql].freeze
LIST_ARG_PREDICATES = %i[included_in excluded_from format].freeze

def method_missing(name, *args, **kwargs, &block)
  normalized = name.to_s.delete_suffix('?').to_sym

  if SINGLE_ARG_PREDICATES.include?(normalized) && args.length > 1
    raise ArgumentError, "#{name} expects exactly one argument, got #{args.length}"
  end

  # ... existing logic
end
```

**Impact:** Low effort, prevents silent misbehavior from invalid DSL usage.

---

### 3.5 `schema.rb` — `MessageBackend#tokens_for` assumes single argument

**Current state:**

```ruby
def tokens_for(args, type)
  argument = args.first
  { num: argument, size: argument, left: argument, list: Array(argument).join(', '), type: type }
end
```

**Problem:** `size?` with a range (`size?: 3..5`) produces `argument = 3..5`. A template like `"must be %{num}"` stringifies as `"must be 3..5"`, which is unhelpful.

**Fix:** Handle Range arguments specially:

```ruby
def tokens_for(args, type)
  argument = args.first

  if argument.is_a?(Range)
    { num: argument.begin, size: argument, left: argument.begin, 
      right: argument.end, list: "#{argument.begin} to #{argument.end}", type: type }
  else
    { num: argument, size: argument, left: argument, 
      list: Array(argument).join(', '), type: type }
  end
end
```

**Impact:** Low effort, improves message quality for range predicates.

---

### 3.6 `contract.rb` — `execute_rule` and `execute_each` duplicate evaluator pattern

**Current state:**

```ruby
def execute_rule(rule, result, context)
  evaluator = Evaluator.new(...)
  evaluator.execute(...).failures.each { |failure| result.add_error(failure) }
end

def execute_each(rule, result, context)
  evaluator = Evaluator.new(...)
  evaluator.execute(...).failures.each { |failure| result.add_error(failure) }
end
```

**Problem:** The `Evaluator` construction + execution + failure collection is duplicated.

**Fix:** Extract a helper:

```ruby
def run_evaluator(rule, result, context, paths:, index: nil)
  evaluator = Evaluator.new(
    contract: self, result: result, paths: paths,
    default_path: rule.default_path, context: context, index: index
  )
  evaluator.execute(rule.block, rule.macro_calls, keyword_params: rule.keyword_params)
    .failures.each { |failure| result.add_error(failure) }
end
```

Then `execute_rule` becomes `run_evaluator(rule, result, context, paths: rule.paths)` and `execute_each` becomes `run_evaluator(rule, result, context, paths: [item_path], index: index)`.

**Impact:** Trivial, DRY.

---

### 3.7 `contract.rb` — `dependency_error?` can be simplified

**Current state:**

```ruby
def dependency_error?(schema_error_paths, schema_error_path_prefixes, path)
  return true if schema_error_path_prefixes.include?(path)
  path.length.downto(0).any? { |length| schema_error_paths.include?(path.take(length)) }
end
```

**Problem:** Two checks with overlapping semantics. `schema_error_path_prefixes` already contains all prefixes of all error paths (including the error paths themselves).

**Fix:** A single check suffices:

```ruby
def dependency_error?(schema_error_path_prefixes, path)
  path.length.downto(1).any? { |length| schema_error_path_prefixes.include?(path.take(length)) }
end
```

This checks if any prefix of `path` (including `path` itself) is a prefix of any error path. This is equivalent to the original logic.

**Impact:** Trivial, cleaner.

---

## 4. File Organization — New for pre3

### 4.1 `schema.rb` is 23,874 bytes with 8 distinct concepts

**Current contents:**
- `SchemaResult` (~30 lines)
- `ProcessorHooks` (~25 lines)
- `Schema` (~100 lines, main orchestrator)
- `DSL` (~50 lines)
- `FieldDefinition` (~60 lines)
- `FieldBuilder` + `PredicateBlock` (~120 lines)
- `RubyTypeProcessor` (~30 lines)
- `native_errors_to_messages` and buffer constants (~50 lines)

**Why split:**
- **Cognitive load:** A developer fixing a predicate-block bug must read through all 8 concepts.
- **Merge conflicts:** PRs adding `each` support and PRs adding custom-type handling both touch the same file.
- **Test isolation:** Testing `FieldDefinition#deep_dup` requires loading the entire engine, DSL, hooks, and message backend.
- **YARD docs:** 8 classes in one file make generated docs noisy.

**Proposed structure:**

```
lib/dry/validation/rust/
├── schema/
│   ├── result.rb              # SchemaResult
│   ├── processor_hooks.rb     # ProcessorHooks
│   ├── field_definition.rb    # FieldDefinition
│   ├── field_builder.rb       # FieldBuilder + PredicateBlock
│   ├── ruby_type_processor.rb # RubyTypeProcessor
│   └── dsl.rb                 # DSL
├── schema.rb                  # Schema (orchestrator only)
```

**What stays in `schema.rb`:**
- `Schema.define`, `Schema.Params`, `Schema.JSON`
- `Schema#initialize`, `Schema#call`, `Schema#key_paths`, `Schema#inspect`
- `Schema#field_at_path` (after hash-ifying root level)
- Private helpers: `paths_for`, `apply_ruby_predicates`, `predicate_valid?`, `predicate_message`, `native_predicate_details`

**What moves out:**
- `SchemaResult` → `schema/result.rb`
- `ProcessorHooks` → `schema/processor_hooks.rb`
- `FieldDefinition` + `Predicate` struct → `schema/field_definition.rb`
- `FieldBuilder` + `PredicateBlock` → `schema/field_builder.rb`
- `RubyTypeProcessor` → `schema/ruby_type_processor.rb`
- `DSL` → `schema/dsl.rb`

**Require graph in `lib/dry/validation/rust.rb`:**

```ruby
require_relative 'rust/schema/result'
require_relative 'rust/schema/processor_hooks'
require_relative 'rust/schema/field_definition'
require_relative 'rust/schema/field_builder'
require_relative 'rust/schema/ruby_type_processor'
require_relative 'rust/schema/dsl'
require_relative 'rust/schema'
```

---

### 4.2 `contract.rb` is 10,134 bytes with nested classes

**Current contents:**
- `Contract` class methods (`inherited`, `config`, `params`, `json`, `schema`, `rule`, `option`, `register_macro`, etc.)
- `Contract` instance methods (`initialize`, `call`, `macro_registered?`, `resolve_macro`, `inspect`)
- `Contract::Result` (used only by Contract)
- `Contract::Values` (used only by Contract)
- `Contract::Failures` (already in separate `failures.rb`)

**Proposed structure:**

```
lib/dry/validation/rust/
├── contract/
│   ├── result.rb              # Contract::Result
│   └── values.rb              # Contract::Values
├── contract.rb                # Contract (main orchestrator)
```

**What stays in `contract.rb`:**
- All class-level DSL methods
- `Contract#initialize`, `Contract#call`, `Contract#inspect`
- Private helpers: `initialize_options`, `dependency_error?`, `execute_rule`, `execute_each`

**What moves out:**
- `Contract::Result` → `contract/result.rb` (or merge with existing `result.rb` if namespace-compatible)
- `Contract::Values` → `contract/values.rb` (or merge with existing `values.rb`)

**Note:** There is already a top-level `Values` class in `values.rb`. Check if `Contract::Values` is the same concept or a different one. If different, keep the namespace prefix.

---

### 4.3 What NOT to split

- `PredicateBlock` stays in `field_builder.rb` — it's only used by `FieldBuilder#value`.
- `Message` (~15 lines) stays in `message.rb` — too small to split further.
- `Path` (~20 lines) stays in `path.rb` — fine as-is.
- Don't create circular requires. If `FieldBuilder` needs `FieldDefinition` and `FieldDefinition` needs `Predicate` (defined in `FieldBuilder`), keep `Predicate` in `field_builder.rb` or extract to a shared `schema/types.rb`.

---

## 5. Quick-Win Checklist

| # | Task | File(s) | Effort | Impact |
|---|------|---------|--------|--------|
| 1 | Fix `non_finite_literal` allocation | `coercion.rs` | 10 min | Medium |
| 2 | Static string for depth limit error | `engine.rs` | 5 min | Low |
| 3 | Remove IIFE closure in `process_field` | `engine.rs` | 10 min | Low |
| 4 | Hash-ify `report_unexpected_keys` | `engine.rs` | 20 min | Medium |
| 5 | Emit full error text from Rust for `unexpected_key` | `engine.rs` + `schema.rb` | 10 min | Low |
| 6 | Hash-ify root-level field lookup | `schema.rb` | 20 min | Medium |
| 7 | Move error buffer parsing to Rust | `engine.rs` + `schema.rb` | 2–4 hrs | High |
| 8 | Add arity validation to `PredicateBlock` | `schema.rb` | 20 min | Medium |
| 9 | Handle Range arguments in `tokens_for` | `message_backend.rb` | 15 min | Low |
| 10 | Extract `run_evaluator` helper | `contract.rb` | 15 min | Low |
| 11 | Simplify `dependency_error?` | `contract.rb` | 15 min | Low |
| 12 | Split `schema.rb` into `schema/` directory | `lib/dry/validation/rust/` | 1–2 hrs | High |
| 13 | Split `contract.rb` nested classes | `lib/dry/validation/rust/` | 30 min | Medium |

---

*End of pre3 refactoring review.*
