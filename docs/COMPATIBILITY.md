# Compatibility target and matrix

## Target

The public target for the `0.1.x` line is the common `dry-validation` contract
surface. The authoritative machine-readable pin is `dry-validation` 1.11.1 in
the root `Gemfile`; its locked `dry-schema` dependency is 1.16.0. This is not a
claim of full behavioral compatibility. `bundle exec rake compatibility:differential`
executes the initial corpus against both engines in separate Ruby processes.

Version, platform, and release-line support are documented in
[SUPPORT_MATRIX.md](SUPPORT_MATRIX.md).

For `0.1.x`, the side-by-side API rooted at
`Dry::Validation::Rust::Contract` is stable: a breaking change to its documented
public surface, including `Schema`, `Result`, `MessageSet`, `Evaluator`, and
`Values`, requires a minor release. Exact-compatibility entrypoints remain
experimental and are excluded from this compatibility promise.

Legend:

- ✅ implemented and covered by this prototype's tests;
- 🟡 partial or intentionally narrower;
- ❌ not implemented;
- N/A intentionally left to Ruby rather than translated.

## Loading and factories

| Surface                                  | Status | Notes                               |
| ---------------------------------------- | ------ | ----------------------------------- |
| `require "dry/validation/rust"`          | ✅     | Side-by-side namespace              |
| `Dry::Validation::Rust::Contract`        | ✅     | Safe migration superclass           |
| `require "dry/validation"`               | ✅     | Exact replacement entrypoint        |
| `Dry::Validation::Contract`              | ✅     | Alias in exact mode                 |
| `Dry::Validation.Contract { ... }`       | ✅     | Exact factory                       |
| `Dry::Validation::Rust.Contract { ... }` | ✅     | Safe factory                        |
| `Dry::Schema.Params` / `JSON` / `define` | 🟡     | Minimal exact-mode factories        |
| Co-install exact mode with upstream gems | ❌     | Require path and constant collision |

## Schema definition

| Surface                                   | Status | Notes                                     |
| ----------------------------------------- | ------ | ----------------------------------------- |
| `params do ... end`                       | ✅     | HTTP-like key/scalar coercion             |
| `json do ... end`                         | ✅     | Key normalization, no scalar coercion     |
| `schema do ... end`                       | ✅     | Symbol keys, no coercion                  |
| `required(:key)`                          | ✅     |                                           |
| `optional(:key)`                          | ✅     |                                           |
| `value(:type)`                            | ✅     |                                           |
| `filled(:type)` / `filled`                | ✅     | Nil and empty String/Array/Hash           |
| `maybe(:type)`                            | ✅     | Params empty string becomes nil           |
| `hash do ... end`                         | ✅     | Recursive                                 |
| `array(:type)`                            | ✅     | Coerced primitive members                 |
| `array(:hash) { ... }`                    | ✅     | Nested member schema                      |
| External schema arguments                 | ✅     | Rust schemas only                         |
| Contract schema inheritance               | ✅     | Child schema extends parent               |
| Multiple schema declaration guard         | ✅     | Raises `DuplicateSchemaError`             |
| Key validation when declaring rules       | ✅     | Common nested paths                       |
| Predicate-composition blocks              | ❌     | Move logic to named predicates/rules      |
| Schema `before` / `after` processor hooks | ❌     | Arbitrary transforms need callback design |
| Schema merge operators / AST access       | ❌     |                                           |
| `config.validate_keys = true`             | ✅     | Rejects unknown keys in `params` and `json` schemas |
| Filtering DSL                             | ❌     |                                           |

## Types and coercions

| Type                               | Params | JSON/schema checks | Notes                                                                                |
| ---------------------------------- | ------ | ------------------ | ------------------------------------------------------------------------------------ |
| `:any`                             | ✅     | ✅                 |                                                                                      |
| `:nil`                             | N/A    | ✅                 |                                                                                      |
| `:bool` / `:true` / `:false`       | ✅     | ✅                 | `true/false`, `t/f`, `1/0`, `on/off`, `yes/no`, and `y/n` strings                    |
| `:integer`                         | ✅     | ✅                 | Ruby integer syntax, including arbitrary precision and underscores                   |
| `:float`                           | ✅     | ✅                 | Ruby float syntax, including numeric overflow; literal `Infinity` and `NaN` rejected |
| `:decimal`                         | ✅     | ✅                 | Finite BigDecimal values; infinities and NaN rejected                                |
| `:string`                          | ✅     | ✅                 | No non-string-to-string coercion                                                     |
| `:symbol`                          | ✅     | ✅                 |                                                                                      |
| `:array` / `:hash`                 | ✅     | ✅                 |                                                                                      |
| `:date`                            | ✅     | ✅                 | ISO 8601                                                                             |
| `:date_time` / `:datetime`         | ✅     | ✅                 | ISO 8601                                                                             |
| `:time`                            | ✅     | ✅                 | ISO 8601                                                                             |
| dry-types objects/constructors     | ❌     | ❌                 | Raises `UnsupportedFeatureError`                                                     |
| Enums/maps/intersections/sum types | ❌     | ❌                 |                                                                                      |
| Params hash-to-array coercion      | ❌     | N/A                |                                                                                      |

The supported scalar corpus is differentially checked against the pinned
upstream version for numeric boundaries, boolean spellings, temporal parsing,
and symbols. This is a focused compatibility slice, not a claim of complete
`dry-types` coercion parity.

## Schema predicates

| Predicate                           | Status | Owner                       |
| ----------------------------------- | ------ | --------------------------- |
| `gt?`, `gteq?`, `lt?`, `lteq?`      | ✅     | Rust                        |
| `size?`, `min_size?`, `max_size?`   | ✅     | Rust                        |
| `odd?`, `even?`                     | ✅     | Rust                        |
| `format?`                           | ✅     | Ruby Regexp                 |
| `included_in?`, `excluded_from?`    | ✅     | Ruby                        |
| `eql?`, `not_eql?`                  | ✅     | Ruby                        |
| Arbitrary/custom predicate name     | ❌     | Explicit error at execution |
| Boolean predicate AST composition   | ❌     |                             |
| UUID and other dry-logic predicates | ❌     |                             |

Ruby-owned predicates execute after structural processing and are skipped when
the same field already has a type/structural error.

## Contract rules

| Surface                              | Status | Notes                                      |
| ------------------------------------ | ------ | ------------------------------------------ |
| `rule(:key) { ... }`                 | ✅     | Ordered                                    |
| Multi-key rules                      | ✅     |                                            |
| Dot-string nested paths              | ✅     |                                            |
| Array path form                      | ✅     |                                            |
| Simple/multi hash path form          | ✅     |                                            |
| Skip when schema dependency fails    | ✅     | Prefix-aware                               |
| `value` / `values`                   | ✅     |                                            |
| `key?`                               | ✅     | Nested and indexed paths                   |
| `key.failure` / `key(path).failure`  | ✅     |                                            |
| `base.failure`                       | ✅     | Base key is nil in `to_h`                  |
| Explicit String failures             | ✅     |                                            |
| Hash failure metadata                | ✅     |                                            |
| Symbol/localized failure identifiers | 🟡     | Small built-in fallback, no locale backend |
| `schema_error?`                      | ✅     |                                            |
| `rule_error?` / `base_rule_error?`   | ✅     |                                            |
| `rule(:array).each`                  | ✅     | Provides `index:`                          |
| Rule context                         | ✅     | Hash rather than Concurrent::Map           |
| Delegate to contract methods         | ✅     | Includes private methods                   |
| Rule block exceptions                | ✅     | Propagate as Ruby exceptions               |

## Options and macros

| Surface                             | Status | Notes                                        |
| ----------------------------------- | ------ | -------------------------------------------- |
| Required `option :name`             | ✅     |                                              |
| Optional option                     | ✅     |                                              |
| Static/callable default             | ✅     | Callable receives no instance                |
| dry-auto_inject integration         | 🟡     | Likely works through keywords; not certified |
| Global macros                       | ✅     |                                              |
| Per-contract macros and inheritance | ✅     |                                              |
| Macro arguments and `macro:`        | ✅     |                                              |
| `rule.validate`                     | ✅     |                                              |
| Predicate-as-macro extension        | 🟡     | Common numeric/size/format cases only        |
| Full localized macro templates      | ❌     |                                              |

## Results and messages

| Surface                               | Status | Notes                                              |
| ------------------------------------- | ------ | -------------------------------------------------- |
| `success?` / `failure?`               | ✅     |                                                    |
| `to_h` / `[]` / `key?` / `values`     | ✅     |                                                    |
| `errors.to_h`                         | ✅     | Nested hashes and integer indexes                  |
| Enumerable errors                     | ✅     |                                                    |
| Mutable `errors.messages` collection  | 🟡     | Read-only view; mutate a set through `#add`        |
| `errors[:path]`                       | ✅     | Prefix filter                                      |
| `errors.filter(:base?)`               | ✅     | Also `schema?` and `rule?`                         |
| `errors(full: true)`                  | 🟡     | Simple humanized paths                             |
| Error `text`, `path`, `meta`, `code`  | ✅     |                                                    |
| Hash pattern matching                 | ✅     |                                                    |
| Tuple values/context pattern matching | ✅     |                                                    |
| YAML messages/configured load paths   | ❌     | Config object exists for migration visibility only |
| I18n backend/locales                  | ❌     |                                                    |
| Exact upstream message wording        | 🟡     | Common English messages only                       |
| Hints/info message extensions         | ❌     |                                                    |
| Monads extension                      | ❌     | `load_extensions` raises explicitly                |

## Runtime and platform

| Property         | Status                                   |
| ---------------- | ---------------------------------------- |
| CRuby 3.3        | ✅ compiled/tested                       |
| Ruby 3.4/current | 🟡 expected, not verified here           |
| Linux x86-64     | ✅                                       |
| Linux arm64/musl | 🟡 source design supports it; not tested |
| macOS            | 🟡 source design supports it; not tested |
| Windows          | ❌ untested                              |
| JRuby            | ❌                                       |
| TruffleRuby      | ❌                                       |
| Ruby threads     | ✅ call isolation tested                 |
| Ractors          | ❌ no compatibility promise              |
| GVL release      | ❌ native Ruby-object path holds GVL     |

## Migration guidance

1. Start with side-by-side mode and a small contract.
2. Build a fixture corpus from production-shaped valid and invalid payloads.
3. Run upstream and Rust contracts in separate processes.
4. Compare output values, classes, errors, paths, metadata, and exceptions.
5. Do not switch exact mode until every used feature is ✅ or explicitly
   adapted.
6. Benchmark only after semantic parity.

Any unsupported feature should fail loudly. A silent approximation is treated
as a bug in this prototype.
