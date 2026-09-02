# Migrating from `dry-validation`

`dry-validation-rust` supports a documented subset of `dry-validation` 1.11.1
and `dry-schema` 1.16.0. Migrate contract by contract in the side-by-side
namespace; do not treat a successful DSL parse as proof of equivalent behavior.
The complete, version-pinned support classification is
[COMPATIBILITY.md](COMPATIBILITY.md).

## Start side by side

Replace the require and contract superclass. The contract body can remain the
same when it uses supported schema and rule features.

```ruby
# Before: upstream dry-validation
require "dry/validation"

class UserContract < Dry::Validation::Contract
  params { required(:email).filled(:string) }
end

# After: dry-validation-rust
require "dry/validation/rust"

class UserContract < Dry::Validation::Rust::Contract
  params { required(:email).filled(:string) }
end
```

The side-by-side require defines only `Dry::Validation::Rust`, so it can be
loaded in a process that still uses upstream `dry-validation` elsewhere. Do
not use the deprecated `require "dry/validation"` or `require "dry/schema"`
entrypoints: they collide with the upstream gems.

## Replace schema factories

Qualify standalone schema factories with the Rust namespace:

| Upstream | dry-validation-rust |
| --- | --- |
| `Dry::Schema.Params { ... }` | `Dry::Validation::Rust::Schema.Params { ... }` |
| `Dry::Schema.JSON { ... }` | `Dry::Validation::Rust::Schema.JSON { ... }` |
| `Dry::Schema.define { ... }` | `Dry::Validation::Rust::Schema.define { ... }` |
| `Dry::Validation.Contract { ... }` | `Dry::Validation::Rust.Contract { ... }` |

For example, a reusable Params schema becomes:

```ruby
require "dry/validation/rust"

UserParams = Dry::Validation::Rust::Schema.Params do
  required(:email).filled(:string)
end

class UserContract < Dry::Validation::Rust::Contract
  params UserParams
end
```

Only schemas built by `Dry::Validation::Rust::Schema` can be passed as external
schemas. A contract may declare one schema; use contract inheritance to extend
an existing schema instead of declaring a second one.

## Adapt unsupported predicates

Keep supported predicates in schema declarations. For application-specific
checks, express the condition as a rule and add the failure yourself:

```ruby
class UserContract < Dry::Validation::Rust::Contract
  params { required(:email).filled(:string) }

  rule(:email) do
    key.failure("must use the example.com domain") unless value.end_with?("@example.com")
  end
end
```

Supported schema predicates are numeric comparisons, size checks, `odd?`,
`even?`, `format?`, `included_in?`, `excluded_from?`, `eql?`, and `not_eql?`.
Arbitrary predicate names fail explicitly at execution, rather than falling
back to upstream dry-logic behavior.

For boolean predicate ASTs, UUID predicates, and the filtering DSL, use the
copy-pasteable replacements in [MIGRATION_RECIPES.md](MIGRATION_RECIPES.md):

- replace boolean expressions with sequential supported predicates or a rule;
- replace `uuid?` with `format?` or a rule;
- replace schema filtering with an explicit `result.to_h.slice(...)`.

## Semantic differences and migration actions

The table below covers every boundary currently classified as partial or
unsupported in [COMPATIBILITY.md](COMPATIBILITY.md). Green entries are not
repeated; retain their existing contract code and verify it with representative
payloads.

| Difference | Migration action |
| --- | --- |
| Schema merge operators and AST access are unavailable. | Keep composition in Ruby application code, or define one supported Rust schema for the contract. Do not depend on a schema AST. |
| Schema processor hooks support only `:value_coercer`; before hooks receive a deep copy. | Move other processor work before `call`, or use a `:value_coercer` hook without relying on input-object identity or mutation. |
| Boolean predicate AST composition is unavailable. | Use the [boolean-predicate recipe](MIGRATION_RECIPES.md#boolean-predicate-composition). |
| The filtering DSL is unavailable. | Use the [filtering recipe](MIGRATION_RECIPES.md#schema-filtering-dsl). |
| Enums, maps, intersections, custom array-member types, and Params hash-to-array coercion are unavailable. | Normalize the input before validation, then validate it with supported primitive, hash, or array declarations. Keep type-specific errors in application code if required. |
| Custom dry-types conversion failures use `is invalid`, not dry-schema's type-specific messages. | Compare error codes and paths rather than exact text, or emit application-specific rule failures where message text is a contract. |
| UUID and other dry-logic predicates are unavailable. | Use the [UUID recipe](MIGRATION_RECIPES.md#uuid-and-other-dry-logic-predicates) or a contract rule. |
| Predicate blocks run only sequential supported calls. | Replace alternatives and conditional predicate logic with a rule. |
| Rule context is a `Hash`, not `Concurrent::Map`. | Access context with normal hash operations; do not rely on concurrent-map-specific APIs. |
| Symbol/localized failure identifiers have only a small built-in fallback, and full localized macro templates are unavailable. | Use explicit string failures for contract-owned text, or configure the optional `i18n` gem for schema messages and verify each locale. |
| `errors.messages` is read-only. | Build a changed message set with `#add`; do not mutate the collection returned by `messages`. |
| `errors(full: true)` has simple path humanization and English wording is only partially equivalent. | Treat structured `errors.to_h`, error `path`, `code`, and `meta` as the integration contract; render user-facing text in the application when exact wording matters. |
| Hints, info message extensions, and monads are unavailable. | Keep these concerns at the application boundary. Calling `load_extensions` for monads raises explicitly. |
| Exact-mode loading is deprecated and cannot co-install with upstream gems. | Use the side-by-side namespace and factory replacements above. |
| `dry-auto_inject` is not certified, although keyword options are expected to work. | Pass required options explicitly and add an integration test before relying on automatic injection. |
| Predicate-as-macro support covers common numeric, size, and format cases only. | Use an ordinary rule or a global/per-contract macro whose behavior you own for other predicate macros. |
| Ruby 3.4/current and several non-Linux platforms are expected rather than fully verified; JRuby, TruffleRuby, Ractors, and GVL release are unsupported. | Deploy on tested CRuby/Linux x86-64 for the supported path. Treat other supported-design targets as application-tested, and keep unsupported runtimes or parallelism on upstream validation. |

## Verify each migrated contract

1. Capture production-shaped valid and invalid inputs before changing a
   contract.
2. Run the upstream and Rust versions in separate Ruby processes.
3. Compare successful output values and classes, plus failure paths, codes,
   metadata, and raised exceptions. Do not compare only `success?`.
4. Check the contract's DSL against [COMPATIBILITY.md](COMPATIBILITY.md), then
   apply the matching action above for every partial or unsupported feature.
5. Benchmark only after the contract's behavior is acceptable for its callers.

Unsupported behavior is intentionally an explicit error. Keep that boundary
visible during migration rather than silently approximating it.
