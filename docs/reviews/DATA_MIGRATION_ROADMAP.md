# Data Class Migration Roadmap — `dry-validation-rust` 0.1.0.pre3

> Review date: 2026-08-10
> Target: develop branch @ 0.1.0.pre3
> Ruby requirement: `>= 3.3` (gemspec) — `Data` is fully available
> Philosophy: **Immutable value objects everywhere it makes sense.**

---

## Table of Contents

1. [Why `Data`?](#1-why-data)
2. [Classes to Migrate](#2-classes-to-migrate)
3. [Classes to Keep as Plain Classes](#3-classes-to-keep-as-plain-classes)
4. [Classes to Keep as `Struct`](#4-classes-to-keep-as-struct)
5. [Migration Order](#5-migration-order)
6. [Behavioral Changes to Watch](#6-behavioral-changes-to-watch)
7. [Quick-Win Checklist](#7-quick-win-checklist)

---

## 1. Why `Data`?

Ruby 3.2 introduced `Data` — an immutable, value-semantics alternative to `Struct` and hand-rolled value classes. It provides:

| Feature                                              | `Data`          | `Struct`                  | Plain class |
| ---------------------------------------------------- | --------------- | ------------------------- | ----------- |
| Immutable by default                                 | ✅              | ❌ (unless frozen)        | ❌ (manual) |
| Keyword init                                         | ✅              | ✅ (`keyword_init: true`) | ❌ (manual) |
| Value equality (`==`, `eql?`, `hash`)                | ✅ (all fields) | ✅ (all fields)           | ❌ (manual) |
| `with(field: new_value)` copy                        | ✅              | ❌                        | ❌ (manual) |
| Pattern matching (`deconstruct`, `deconstruct_keys`) | ✅              | ✅                        | ❌ (manual) |
| Custom methods                                       | ✅              | ✅                        | ✅          |
| No dynamic method definition                         | ✅              | ❌                        | ✅          |
| Memory overhead                                      | Low             | Higher (dynamic methods)  | Low         |

**The bottom line:** `Data` gives you immutable value semantics, automatic equality, and the `with` copy method — all with less boilerplate than a hand-rolled class and without the dynamic-method overhead of `Struct`.

---

## 2. Classes to Migrate

### 2.1 `Predicate` — P0, trivial

**Current:**

```ruby
# In schema.rb
Predicate = Struct.new(:name, :argument, keyword_init: true)
```

**After:**

```ruby
# In schema.rb (or schema/types.rb after file split)
Predicate = Data.define(:name, :argument) do
  def initialize(name:, argument: true)
    super(name: name.to_s.delete_suffix('?').to_sym, argument: argument)
  end
end
```

**Why:** Two-field value object. Used everywhere. `Data` gives automatic `with` for `deep_dup`:

```ruby
# Before (in FieldDefinition#deep_dup):
copy.predicates << Predicate.new(name: predicate.name, argument: duplicate_value(predicate.argument))

# After:
copy.predicates << predicate.with(argument: duplicate_value(predicate.argument))
```

**Impact:** Trivial. One-line change.

---

### 2.2 `OptionDefinition` — P0, trivial

**Current:**

```ruby
# In contract.rb
OptionDefinition = Struct.new(:name, :default, :optional, keyword_init: true)
```

**After:**

```ruby
# In contract.rb (or contract/types.rb)
OptionDefinition = Data.define(:name, :default, :optional) do
  def initialize(name:, default: Contract::Undefined, optional: false)
    super
  end
end
```

**Why:** Three-field value object. Never mutated after creation. `Data` equality means two option definitions with the same fields are equal — useful for testing and inheritance checks.

**Impact:** Trivial. One-line change.

---

### 2.3 `Message` — P0, high value

**Current:**

```ruby
# In message.rb
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

  def with_text(new_text)
    self.class.new(
      new_text, path: path, meta: meta, code: code, source: source,
      predicate: predicate, args: args
    )
  end

  def to_s
    text
  end

  def ==(other)
    other.is_a?(Message) && [text, path, meta, code, source] ==
      [other.text, other.path, other.meta, other.code, other.source]
  end
end
```

**After:**

```ruby
# In message.rb
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

  # Data#with replaces custom with_text
  # Usage: message.with(text: new_text)

  def to_s
    text
  end
end
```

**Why:**

- Eliminates 20 lines of boilerplate (`attr_reader`, `==`, `with_text`)
- `Data#with` replaces custom `with_text` — `message.with(text: "new")` instead of `message.with_text("new")`
- Automatic value equality includes all fields (the current `==` excludes `predicate` and `args` — this is likely a bug)
- Pattern matching support out of the box

**Call-site updates:**

```ruby
# Before:
message.with_text(new_text)

# After:
message.with(text: new_text)

# Before:
Message.new(text, path: path, code: code, ...)

# After:
Message.new(text: text, path: path, code: code, ...)  # same, but keyword-only
```

**Impact:** Low. One file, ~20 lines removed. Call sites need `with_text` → `with` update.

---

### 2.4 `SchemaResult` — P1, medium value

**Current:**

```ruby
# In schema.rb
class SchemaResult
  attr_reader :output, :messages

  def initialize(output, messages)
    @output = output
    @messages = messages
  end

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

  def error?(spec)
    path = Path.parse(spec)
    messages.any? { |message| Path.prefix?(message.path, path) }
  end

  def [](key)
    output[key]
  end

  def key?(key)
    output.key?(key)
  end
end
```

**After:**

```ruby
# In schema.rb (or schema/result.rb after file split)
SchemaResult = Data.define(:output, :messages) do
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

  def error?(spec)
    path = Path.parse(spec)
    messages.any? { |message| Path.prefix?(message.path, path) }
  end

  def [](key)
    output[key]
  end

  def key?(key)
    output.key?(key)
  end
end
```

**Why:**

- Eliminates `attr_reader` and `initialize` boilerplate
- Immutable by default (the current class is effectively immutable anyway)
- Value equality means two `SchemaResult`s with the same output and messages are equal — useful for testing

**Impact:** Low. One file, ~10 lines removed.

---

### 2.5 `MessageConfig` — P1, requires DSL change

**Current:**

```ruby
# In config.rb
class MessageConfig
  attr_accessor :backend, :default_locale, :top_namespace, :load_paths

  def initialize
    @backend = :yaml
    @default_locale = :en
    @top_namespace = :dry_validation
    @load_paths = []
  end

  def dup
    copy = super
    copy.load_paths = load_paths.dup
    copy
  end
end
```

**Problem:** `MessageConfig` is mutable (`attr_accessor`). It's used like this:

```ruby
config = MessageConfig.new
config.backend = :i18n
config.load_paths = ['config/locales']
```

**After:**

```ruby
# In config.rb
MessageConfig = Data.define(:backend, :default_locale, :top_namespace, :load_paths) do
  def initialize(backend: :yaml, default_locale: :en, top_namespace: :dry_validation, load_paths: [])
    super(
      backend: backend.to_sym,
      default_locale: default_locale.to_sym,
      top_namespace: top_namespace.to_s,
      load_paths: load_paths.dup.freeze
    )
  end
end
```

**Call-site updates:**

```ruby
# Before:
config = MessageConfig.new
config.backend = :i18n
config.load_paths = ['config/locales']

# After:
config = MessageConfig.new(backend: :i18n, load_paths: ['config/locales'])

# Before (in Config#dup):
copy.messages = messages.dup

# After:
copy = copy.with(messages: messages.with(...))  # or restructure Config too
```

**Why:** `MessageConfig` is a configuration value object. It's set once and passed around. Immutability prevents accidental mutation.

**Impact:** Medium. Requires updating all call sites that mutate `MessageConfig` after construction. The `Config` class also needs updates.

---

### 2.6 `Config` — P1, requires DSL change

**Current:**

```ruby
# In config.rb
class Config
  attr_reader :validate_keys
  attr_accessor :messages

  def initialize
    @validate_keys = false
    @messages = MessageConfig.new
  end

  def validate_keys=(value)
    @validate_keys = !!value
  end

  def dup
    copy = super
    copy.messages = messages.dup
    copy
  end
end
```

**After:**

```ruby
# In config.rb
Config = Data.define(:validate_keys, :messages) do
  def initialize(validate_keys: false, messages: MessageConfig.new)
    super(validate_keys: !!validate_keys, messages: messages)
  end
end
```

**Call-site updates:**

```ruby
# Before:
config = Config.new
config.validate_keys = true
config.messages.backend = :i18n

# After:
config = Config.new(validate_keys: true, messages: MessageConfig.new(backend: :i18n))
# Or incremental:
config = Config.new
config = config.with(validate_keys: true)
config = config.with(messages: config.messages.with(backend: :i18n))
```

**Why:** `Config` is a configuration value object. The current mutation pattern is convenient but error-prone. Immutability makes it clear that each change produces a new config.

**Impact:** Medium. Requires updating the contract DSL:

```ruby
# Before:
class MyContract < Dry::Validation::Rust::Contract
  config.validate_keys = true
  config.messages.backend = :i18n
end

# After:
class MyContract < Dry::Validation::Rust::Contract
  config Config.new(validate_keys: true, messages: MessageConfig.new(backend: :i18n))
end
```

Or keep the DSL but make it functional:

```ruby
# Alternative: keep the DSL, but make it return new instances
class Contract
  def self.config(options = {})
    if options.empty?
      @config
    else
      @config = @config.with(**options)
    end
  end
end

# Usage:
class MyContract < Dry::Validation::Rust::Contract
  config validate_keys: true
  config messages: { backend: :i18n }
end
```

This is a bigger design decision. **Recommendation:** Migrate `MessageConfig` first, then evaluate whether `Config` should follow.

---

## 3. Classes to Keep as Plain Classes

### 3.1 `Schema` — orchestrator with complex lifecycle

`Schema` manages a Rust engine reference, hooks, and message backend. It has `call` which mutates nothing but the object itself holds mutable references (engine, hooks). Not a value object.

### 3.2 `Contract` — class-level DSL with mutable state

`Contract` has `@config`, `@macro_registry`, `@own_rules`, `@schema_definition` — all class-level mutable state. It's a DSL engine, not a value object.

### 3.3 `FieldDefinition` — mutable builder state

`FieldDefinition` has `attr_accessor` for `name`, `required`, `nullable`, `filled`, `type`, `member`, `ruby_type`. It's built incrementally by `FieldBuilder`. Only after `deep_dup` is it effectively immutable. Converting to `Data` would require restructuring the builder pattern.

**Future possibility:** Split into `FieldDefinition` (immutable `Data`) and `FieldBuilder` (mutable accumulator that produces a `FieldDefinition`).

### 3.4 `FieldBuilder` / `PredicateBlock` — DSL builders with mutable state

These accumulate state via method calls. `Data` is inappropriate.

### 3.5 `Evaluator` — execution context with mutable state

`Evaluator` has `@result`, `@context`, `@paths`, `@default_path`, `@index`. It mutates during rule execution. Not a value object.

### 3.6 `MessageSet` — collection with cached views

`MessageSet` has `@messages` (mutable array), `@readonly_messages` (lazy cache), `@to_h` (lazy cache). It's a mutable collection wrapper. `Data` is inappropriate.

### 3.7 `Result` — mutable accumulator

`Result` has `@rule_messages` (mutable array). `add_error` mutates it. `finalize!` freezes it. Not a `Data` candidate unless `add_error` is restructured to return new instances.

### 3.8 `Values` — Hash delegate

`Values` delegates to a Hash and implements `method_missing`. Not a value object in the `Data` sense.

### 3.9 `MessageBackend` — service object with loaded state

`MessageBackend` loads YAML/i18n data in `initialize` and holds `@translations`. It's a service, not a value object.

### 3.10 `ProcessorHooks` — service object

`ProcessorHooks` is a namespace for static methods. No state. Not a `Data` candidate.

### 3.11 `Path` — utility module

`Path` is a module with static methods. No instances. Not a `Data` candidate.

### 3.12 `Rule` — needs review

I haven't seen the full `Rule` class. If it's immutable after construction (paths, block, keyword_params, macro_calls frozen), it could be a `Data` candidate. If it has mutable state or complex initialization, keep as plain class.

---

## 4. Classes to Keep as `Struct`

None. Both `Predicate` and `OptionDefinition` are currently `Struct`s and should migrate to `Data`. `Struct` has no advantages over `Data` for immutable value objects.

---

## 5. Migration Order

### Phase 0: Trivial migrations (no call-site changes)

1. **`Predicate` → `Data`** — One line. `deep_dup` uses `with` instead of `new`.
2. **`OptionDefinition` → `Data`** — One line. No call-site changes.

### Phase 1: Simple migrations (minor call-site changes)

3. **`Message` → `Data`** — Replace `with_text` with `with`. Update call sites in `MessageSet#full_message` and any tests.
4. **`SchemaResult` → `Data`** — No call-site changes if `initialize` signature stays compatible.

### Phase 2: Config migrations (DSL changes)

5. **`MessageConfig` → `Data`** — Update all mutation call sites. Restructure `Config#dup`.
6. **`Config` → `Data`** — Update contract DSL. Consider functional config DSL.

### Phase 3: Future possibilities

7. **`FieldDefinition` → `Data` + `FieldBuilder` refactor** — Split mutable builder from immutable definition.
8. **`Rule` → `Data`** — If immutable after construction.

---

## 6. Behavioral Changes to Watch

### 6.1 Value equality includes all fields

`Data` equality compares **all** fields. The current `Message#==` excludes `predicate` and `args`:

```ruby
# Current:
def ==(other)
  [text, path, meta, code, source] == [other.text, other.path, other.meta, other.code, other.source]
end

# Data: automatic, includes predicate and args
```

**Impact:** If you have tests that rely on messages being equal despite different `predicate`/`args`, they will break. This is likely a **bug fix**, not a regression — two messages with different predicates should not be equal.

### 6.2 `Data#with` requires all changes at once

```ruby
# Before (Message):
message.with_text("new").with(path: [:other])
# (if you had a chain of with_* methods)

# After (Data):
message.with(text: "new", path: [:other])
```

`Data#with` is a single method call. You can't chain `.with_text(x).with_path(y)` unless you define custom methods.

### 6.3 No `attr_accessor`

`Data` only provides readers. Any code that does `object.field = value` must change to `object = object.with(field: value)`.

### 6.4 `initialize` becomes keyword-only

```ruby
# Before (Struct):
Predicate.new(:gt, 18)  # positional works with keyword_init: true? No, keyword_init requires keywords
# Actually with keyword_init: true, it already requires keywords:
Predicate.new(name: :gt, argument: 18)

# After (Data):
Predicate.new(name: :gt, argument: 18)  # same
```

For `Message`, the current signature is `Message.new(text, path: ..., ...)` — positional `text` plus keyword options. `Data` requires all fields to be keywords:

```ruby
# Before:
Message.new("must be 18", path: [:age], code: :gt)

# After:
Message.new(text: "must be 18", path: [:age], code: :gt)
```

**Impact:** Medium. All `Message.new` call sites need updating. There are many in `schema.rb`, `contract.rb`, and tests.

### 6.5 `dup` behavior changes

`Data#dup` creates a shallow copy (same as `Struct#dup`). For deep copies, you still need custom logic. `FieldDefinition#deep_dup` will need to use `predicate.with(argument: duplicate_value(...))` instead of `Predicate.new(...)`.

---

## 7. Quick-Win Checklist

| #   | Task                                                            | File(s)                           | Effort  | Impact                                |
| --- | --------------------------------------------------------------- | --------------------------------- | ------- | ------------------------------------- |
| 1   | `Predicate = Data.define(:name, :argument)`                     | `schema.rb`                       | 5 min   | High (removes Struct overhead)        |
| 2   | `OptionDefinition = Data.define(:name, :default, :optional)`    | `contract.rb`                     | 5 min   | High (removes Struct overhead)        |
| 3   | `Message = Data.define(...)` + `with_text` → `with`             | `message.rb`                      | 30 min  | High (removes ~20 lines, adds `with`) |
| 4   | Update all `Message.new(text, ...)` → `Message.new(text:, ...)` | `schema.rb`, `contract.rb`, tests | 30 min  | Medium (call sites)                   |
| 5   | `SchemaResult = Data.define(:output, :messages)`                | `schema.rb`                       | 15 min  | Medium (removes boilerplate)          |
| 6   | `MessageConfig = Data.define(...)`                              | `config.rb`                       | 1–2 hrs | Medium (requires call-site updates)   |
| 7   | Evaluate `Config` → `Data`                                      | `config.rb`, `contract.rb`        | 2–4 hrs | Low (design decision)                 |

---

_End of Data class migration roadmap._
