# Refactoring, Optimization & Polish — `dry-validation-rust` 0.1.0.pre3 (post-split)

> Review date: 2026-08-11
> Target: develop branch @ 0.1.0.pre3, commit `fdd43ff` + PR #132
> Scope: Rust native extension, Ruby layer, file organization, Data migration

---

## Table of Contents

1. [What Was Fixed Since Last Review](#1-what-was-fixed-since-last-review)
2. [Remaining Rust Opportunities](#2-remaining-rust-opportunities)
3. [Remaining Ruby Opportunities](#3-remaining-ruby-opportunities)
4. [Data Class Migration — The Next Internal Cleanup](#4-data-class-migration--the-next-internal-cleanup)
5. [File Organization — Remaining](#5-file-organization--remaining)
6. [Quick-Win Checklist](#6-quick-win-checklist)

---

## 1. What Was Fixed Since Last Review

PR #132 "refactor(schema): split schema collaborators" landed. The monolithic `schema.rb` (23,874 bytes) is now split into:

```
lib/dry/validation/rust/
├── schema.rb                  # 8,806 bytes — orchestrator only
└── schema/
    ├── dsl.rb                 # Schema::DSL
    ├── field_builder.rb       # Schema::FieldBuilder
    ├── field_definition.rb    # Schema::FieldDefinition
    ├── predicate_block.rb     # Schema::PredicateBlock
    ├── processor_hooks.rb     # Schema::ProcessorHooks
    ├── result.rb              # Schema::Result
    └── ruby_type_processor.rb # Schema::RubyTypeProcessor
```

**Previously fixed items (all done):**

| #   | Item                                       | Evidence                                                  |
| --- | ------------------------------------------ | --------------------------------------------------------- |
| 1   | `schema.rb` split into `schema/` directory | PR #132                                                   |
| 2   | `non_finite_literal` allocation-free       | `eq_ignore_ascii_case` in `coercion.rs`                   |
| 3   | `fast_integer()` GVL fast-path             | `coercion.rs`                                             |
| 4   | Error buffer → structured hashes           | `engine.call` returns `{path:, code:, text:}` hashes      |
| 5   | Root-level `field_at_path` hash-ified      | `@fields_by_name` in `Schema#initialize`                  |
| 6   | `report_unexpected_keys` HashSet           | `HashSet<&str>` in `engine.rs`                            |
| 7   | `dependency_error?` simplified             | Single prefix check in `contract.rb`                      |
| 8   | `run_evaluator` extracted                  | `contract.rb`                                             |
| 9   | `PredicateBlock` arity validation          | `SINGLE_ARGUMENT_PREDICATES` / `ZERO_ARGUMENT_PREDICATES` |
| 10  | Processor hooks shallow-copy docs          | Comment in `Schema#call`                                  |

---

## 2. Remaining Rust Opportunities

### 2.1 `fast_float()` coercion fast-path

**Current state:**

```rust
"float" if non_finite_literal(&source) => None,
"float" => ruby
    .module_kernel()
    .funcall::<_, _, Value>("Float", (source.as_str(),))
    .ok(),
```

**Problem:** Every float coercion calls back into Ruby's `Kernel#Float`, holding the GVL. For simple decimal strings like `"3.14"` or `"-0.5"`, this is unnecessary.

**Fix:** Add `fast_float()` analogous to `fast_integer()`:

```rust
fn fast_float(source: &str) -> Option<f64> {
    if source.is_empty() { return None; }
    let bytes = source.as_bytes();
    let mut start = 0;
    if bytes[0] == b'-' { start = 1; }
    let mut dot_seen = false;
    let mut digit_seen = false;
    for &b in &bytes[start..] {
        if b == b'.' {
            if dot_seen { return None; }
            dot_seen = true;
        } else if b.is_ascii_digit() {
            digit_seen = true;
        } else {
            return None;
        }
    }
    if !digit_seen { return None; }
    source.parse::<f64>().ok().filter(|f| f.is_finite())
}
```

Then in `coerce`:

```rust
"float" if non_finite_literal(&source) => None,
"float" => fast_float(&source)
    .map(|n| ruby.float_from_f64(n).as_value())
    .or_else(|| ruby.module_kernel()
        .funcall::<_, _, Value>("Float", (source.as_str(),))
        .ok()),
```

**Impact:** Medium. Float fields are common in params. This removes a GVL callback for the 80% case of simple decimals.

**Tests to add:**

```rust
#[test]
fn fast_float_handles_common_cases() {
    assert_eq!(fast_float("3.14"), Some(3.14));
    assert_eq!(fast_float("-0.5"), Some(-0.5));
    assert_eq!(fast_float("42"), Some(42.0));
    assert_eq!(fast_float("1_000.5"), None); // underscore → fallback
    assert_eq!(fast_float("1e10"), None);    // scientific → fallback
    assert_eq!(fast_float("Infinity"), None); // non-finite → fallback
}
```

---

### 2.2 `engine.rs` — `field_count` walks the tree on every call

**Current state:** `field_count()` recursively walks the entire plan tree every time.

**Problem:** `O(n)` where `n` is total fields. Only used in tests and diagnostics.

**Fix:** Cache at construction:

```rust
pub(crate) struct Engine {
    plan: SchemaPlan,
    classes: RuntimeClasses,
    plan_bytes: usize,
    field_count: usize, // <-- add
}

impl Engine {
    pub(crate) fn new(ruby: &Ruby, json: String) -> Result<Self, Error> {
        let plan = parse_plan(ruby, &json)?;
        let classes = RuntimeClasses::new(ruby, &plan)?;
        let field_count = count_fields(&plan.fields); // <-- compute once
        Ok(Self { plan, classes, plan_bytes: json.len(), field_count })
    }

    pub(crate) fn field_count(&self) -> usize {
        self.field_count
    }
}
```

**Impact:** Trivial. Not performance-critical but cleaner.

---

## 3. Remaining Ruby Opportunities

### 3.1 `PredicateBlock#validate_arity` — frozen arrays instead of Hash

**Current state:**

```ruby
SINGLE_ARGUMENT_PREDICATES = %i[gt gteq lt lteq min_size max_size size format included_in excluded_from eql not_eql].freeze
ZERO_ARGUMENT_PREDICATES = %i[odd even].freeze

def validate_arity(name, args, kwargs)
  normalized_name = name.to_s.delete_suffix('?').to_sym
  argument_count = args.length + (kwargs.empty? ? 0 : 1)

  if SINGLE_ARGUMENT_PREDICATES.include?(normalized_name) && argument_count != 1
    raise ArgumentError, "#{name} expects exactly one argument, got #{argument_count}"
  end

  return unless ZERO_ARGUMENT_PREDICATES.include?(normalized_name) && argument_count != 0
  raise ArgumentError, "#{name} expects no arguments, got #{argument_count}"
end
```

**Problem:** Two `include?` calls on frozen arrays. For common predicates, this does two linear scans.

**Fix:** Use a Hash for O(1) lookup:

```ruby
ARITY_MAP = {
  gt: 1, gteq: 1, lt: 1, lteq: 1, min_size: 1, max_size: 1, size: 1,
  format: 1, included_in: 1, excluded_from: 1, eql: 1, not_eql: 1,
  odd: 0, even: 0
}.freeze

def validate_arity(name, args, kwargs)
  normalized_name = name.to_s.delete_suffix('?').to_sym
  expected = ARITY_MAP[normalized_name]
  return unless expected

  argument_count = args.length + (kwargs.empty? ? 0 : 1)
  if argument_count != expected
    article = expected == 1 ? 'exactly one argument' : 'no arguments'
    raise ArgumentError, "#{name} expects #{article}, got #{argument_count}"
  end
end
```

**Impact:** Trivial. Arrays are tiny (14 and 2 elements), so this is micro-optimization. But it's cleaner and easier to extend.

---

### 3.2 `contract.rb` — `execute_each` mutates `item_path` array

**Current state:**

```ruby
def execute_each(rule, result, context)
  root = rule.paths.first
  collection = Path.fetch(result.to_h, root)
  return if collection.equal?(Path::Undefined) || collection.nil?
  return unless collection.respond_to?(:each_with_index)

  collection.each_with_index do |_item, index|
    item_path = [*root, index]
    next if result.schema_error?(item_path)
    run_evaluator(rule, result, context, paths: [item_path], default_path: item_path, index: index)
  end
end
```

**Problem:** `item_path = [*root, index]` creates a new array on every iteration. For large collections, this is unnecessary allocation.

**Fix:** Build the path incrementally:

```ruby
def execute_each(rule, result, context)
  root = rule.paths.first
  collection = Path.fetch(result.to_h, root)
  return if collection.equal?(Path::Undefined) || collection.nil?
  return unless collection.respond_to?(:each_with_index)

  collection.each_with_index do |_item, index|
    item_path = root.dup
    item_path << index
    next if result.schema_error?(item_path)
    run_evaluator(rule, result, context, paths: [item_path], default_path: item_path, index: index)
  end
end
```

Actually, `[*root, index]` is already efficient (it splats and appends). The `dup + <<` approach might be slightly faster for large arrays because it avoids the splat allocation. But this is truly micro-optimization.

**Recommendation:** Leave as-is. The current code is readable and the allocation is negligible.

---

## 4. Data Class Migration — The Next Internal Cleanup

Ruby 3.2+ `Data` provides immutable value semantics, automatic equality, and the `with` copy method. The gem requires Ruby `>= 3.3`, so `Data` is fully available.

### 4.1 `Predicate` — P0, trivial

**Current:**

```ruby
# In schema.rb
Predicate = Struct.new(:name, :argument, keyword_init: true)
```

**After:**

```ruby
Predicate = Data.define(:name, :argument) do
  def initialize(name:, argument: true)
    super(name: name.to_s.delete_suffix('?').to_sym, argument: argument)
  end
end
```

**Call-site update in `FieldDefinition#deep_dup`:**

```ruby
# Before:
copy.predicates << Predicate.new(name: predicate.name, argument: duplicate_value(predicate.argument))

# After:
copy.predicates << predicate.with(argument: duplicate_value(predicate.argument))
```

**Impact:** 5 minutes. One-line change. `Data` removes `Struct` overhead.

---

### 4.2 `OptionDefinition` — P0, trivial

**Current:**

```ruby
# In contract.rb
OptionDefinition = Struct.new(:name, :default, :optional, keyword_init: true)
```

**After:**

```ruby
OptionDefinition = Data.define(:name, :default, :optional) do
  def initialize(name:, default: Contract::Undefined, optional: false)
    super
  end
end
```

**Impact:** 5 minutes. One-line change.

---

### 4.3 `Message` — P0, high value

**Current:**

```ruby
class Message
  attr_reader :text, :path, :meta, :code, :source, :predicate, :args

  def initialize(text, path:, meta: {}, code: nil, source: :rule, predicate: nil, args: [])
    @text = text.to_s.freeze
    @path = Array(path).freeze
    @meta = meta.freeze
    @code = code&.to_sym
    @source = source
    @predicate = predicate&.to_sym
    @args = args.freeze
  end

  def with_text(new_text)
    self.class.new(new_text, path: path, meta: meta, code: code, source: source, predicate: predicate, args: args)
  end

  def ==(other)
    other.is_a?(Message) && [text, path, meta, code, source] ==
      [other.text, other.path, other.meta, other.code, other.source]
  end
  # ... 15 more lines
end
```

**Problem:**

- 30+ lines of boilerplate
- `with_text` is a custom copy method
- `==` excludes `predicate` and `args` — **likely a bug**

**After:**

```ruby
Message = Data.define(:text, :path, :meta, :code, :source, :predicate, :args) do
  def initialize(text:, path:, meta: {}, code: nil, source: :rule, predicate: nil, args: [])
    super(
      text: text.to_s,
      path: Array(path).freeze,
      meta: meta.freeze,
      code: code&.to_sym,
      source: source,
      predicate: predicate&.to_sym,
      args: args.freeze
    )
  end

  def base?
    path.compact.empty?
  end

  def schema?
    source == :schema
  end

  def rule?
    source == :rule
  end

  def payload
    meta.empty? ? text : { text: text, **meta }
  end

  def to_s
    text
  end
end
```

**Benefits:**

- Eliminates 20 lines of boilerplate (`attr_reader`, `==`, `with_text`)
- `Data#with` replaces `with_text` — `message.with(text: "new")`
- Automatic value equality includes **all** fields (fixes the `predicate`/`args` exclusion bug)
- Pattern matching support out of the box

**Call-site updates:**

```ruby
# Before:
Message.new(text, path: path, code: code, ...)
# After:
Message.new(text: text, path: path, code: code, ...)  # keyword-only

# Before:
message.with_text(new_text)
# After:
message.with(text: new_text)
```

All `Message.new` call sites in `schema.rb`, `contract.rb`, and tests need updating. There are ~10–15 call sites.

**Impact:** 30 minutes. High value (bug fix + cleaner code).

---

### 4.4 `Schema::Result` — P1, medium value

**Current:**

```ruby
class Result
  attr_reader :output, :messages

  def initialize(output, messages)
    @output = output
    @messages = messages
  end
  # ... 20 more lines
end
```

**After:**

```ruby
Result = Data.define(:output, :messages) do
  alias to_h output

  def success?
    messages.empty?
  end

  def failure?
    !success?
  end

  def errors(options = {})
    MessageSet.new(messages, options).with(options)
  end
  # ... remaining methods
end
```

**Impact:** 15 minutes. Eliminates boilerplate. Value equality useful for tests.

---

### 4.5 What NOT to migrate

| Class                             | Why not                                                                    |
| --------------------------------- | -------------------------------------------------------------------------- |
| `Schema`                          | Orchestrator with Rust engine reference. Not a value object.               |
| `Contract`                        | Class-level DSL with mutable state.                                        |
| `FieldDefinition`                 | Mutable builder state (`attr_accessor` for 7 fields). Built incrementally. |
| `FieldBuilder` / `PredicateBlock` | DSL builders that accumulate state via method calls.                       |
| `Evaluator`                       | Execution context with mutable state during rule evaluation.               |
| `MessageSet`                      | Mutable collection with lazy caches.                                       |
| `Result` (Contract)               | Mutable accumulator (`@rule_messages` grows via `add_error`).              |
| `Values`                          | Hash delegate with `method_missing`.                                       |
| `MessageBackend`                  | Service object with loaded YAML/i18n state.                                |
| `ProcessorHooks`                  | Static method namespace.                                                   |
| `Path`                            | Utility module.                                                            |
| `Rule`                            | Needs review — if immutable after construction, could be a candidate.      |

---

## 5. File Organization — Remaining

### 5.1 `contract.rb` nested classes

**Current:** `Contract::Result` and `Contract::Values` are defined inside `contract.rb` (10,134 bytes).

**Proposed:**

```
lib/dry/validation/rust/
├── contract/
│   ├── result.rb              # Contract::Result
│   └── values.rb              # Contract::Values
├── contract.rb                # Contract (orchestrator)
```

**Note:** Check if `Contract::Values` is identical to top-level `Values` in `values.rb`. If so, merge them. If different, keep the namespace.

**Impact:** 30 minutes. Low priority — `contract.rb` is not as large as `schema.rb` was.

---

## 6. Quick-Win Checklist

| #   | Task                                                            | File(s)                           | Effort | Impact |
| --- | --------------------------------------------------------------- | --------------------------------- | ------ | ------ |
| 1   | Add `fast_float()` coercion fast-path                           | `coercion.rs`                     | 30 min | Medium |
| 2   | Cache `field_count` at engine construction                      | `engine.rs`                       | 10 min | Low    |
| 3   | `Predicate = Data.define(:name, :argument)`                     | `schema.rb`                       | 5 min  | High   |
| 4   | Update `deep_dup` to use `predicate.with`                       | `schema/field_definition.rb`      | 5 min  | Low    |
| 5   | `OptionDefinition = Data.define(:name, :default, :optional)`    | `contract.rb`                     | 5 min  | High   |
| 6   | `Message = Data.define(...)` + `with_text` → `with`             | `message.rb`                      | 30 min | High   |
| 7   | Update all `Message.new(text, ...)` → `Message.new(text:, ...)` | `schema.rb`, `contract.rb`, tests | 30 min | Medium |
| 8   | `Schema::Result = Data.define(:output, :messages)`              | `schema/result.rb`                | 15 min | Medium |
| 9   | Hash-ify `PredicateBlock` arity map                             | `schema/predicate_block.rb`       | 10 min | Low    |
| 10  | Split `contract.rb` nested classes                              | `lib/dry/validation/rust/`        | 30 min | Low    |

---

_End of post-split refactoring review._
