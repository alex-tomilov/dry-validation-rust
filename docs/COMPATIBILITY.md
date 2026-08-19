# Compatibility target and matrix

## Target

The public target for the `0.1.x` line is the common `dry-validation` contract
surface. The authoritative machine-readable pin is `dry-validation` 1.11.1 in
the root `Gemfile`; its locked `dry-schema` dependency is 1.16.0. This is not a
claim of full behavioral compatibility. `bundle exec rake compatibility:differential`
executes the initial corpus against both engines in separate Ruby processes.

Version, platform, and release-line support are documented in
[SUPPORT_MATRIX.md](SUPPORT_MATRIX.md).

## Runtime build dependencies

The source gem supports `bigdecimal` 3.1.x through 4.x. CI compiles and runs
the test suite with 3.1.0, 3.2.0, and 4.0.0. The lower bound keeps support for
the earliest version used by the supported Ruby line; the `< 5.0` bound makes a
new major release an explicit compatibility decision.

The source extension supports `rb_sys` 0.9.100 through the latest 0.9.x. CI
tests 0.9.100, 0.9.128, and the latest resolvable 0.9.x. Its native `rb-sys`
crate enables only `stable-api-compiled-fallback`: the fallback supplies a
compiled stable Ruby C API implementation when `rb-sys` has no generated stable
API candidate for the running Ruby. No default or unrelated `rb-sys` features
are enabled.

For `0.1.x`, the side-by-side API rooted at
`Dry::Validation::Rust::Contract` is stable: a breaking change to its documented
public surface, including its nested `Result` and `Values` types and the `Schema`,
`MessageSet`, and `Evaluator` types, requires a minor release. Exact-compatibility
entrypoints remain experimental and are excluded from this compatibility promise.

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

| Surface                                   | Status | Notes                                                             |
| ----------------------------------------- | ------ | ----------------------------------------------------------------- |
| `params do ... end`                       | ✅     | HTTP-like key/scalar coercion                                     |
| `json do ... end`                         | ✅     | Key normalization, no scalar coercion                             |
| `schema do ... end`                       | ✅     | Symbol keys, no coercion                                          |
| `required(:key)`                          | ✅     |                                                                   |
| `optional(:key)`                          | ✅     |                                                                   |
| `value(:type)`                            | ✅     |                                                                   |
| `filled(:type)` / `filled`                | ✅     | Nil and empty String/Array/Hash                                   |
| `maybe(:type)`                            | ✅     | Params empty string becomes nil                                   |
| `hash do ... end`                         | ✅     | Recursive                                                         |
| `array(:type)`                            | ✅     | Coerced primitive members                                         |
| `array(:hash) { ... }`                    | ✅     | Nested member schema                                              |
| External schema arguments                 | ✅     | Rust schemas only                                                 |
| Contract schema inheritance               | ✅     | Child schema extends parent                                       |
| Multiple schema declaration guard         | ✅     | Raises `DuplicateSchemaError`                                     |
| Key validation when declaring rules       | ✅     | Common nested paths                                               |
| Predicate-composition blocks              | ✅     | Supported predicates only; boolean AST composition is unsupported |
| Schema `before` / `after` processor hooks | ✅     | `:value_coercer` only; callbacks run outside the native engine. Before hooks receive an isolated deep copy of the input. |
| Schema merge operators / AST access       | ❌     |                                                                   |
| `config.validate_keys = true`             | ✅     | Rejects unknown keys in `params` and `json` schemas               |
| Filtering DSL                             | ❌     |                                                                   |

## Types and coercions

| Type                           | Params | JSON/schema checks | Notes                                                                                                                                          |
| ------------------------------ | ------ | ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `:any`                         | ✅     | ✅                 |                                                                                                                                                |
| `:nil`                         | N/A    | ✅                 |                                                                                                                                                |
| `:bool` / `:true` / `:false`   | ✅     | ✅                 | `true/false`, `t/f`, `1/0`, `on/off`, `yes/no`, and `y/n` strings                                                                              |
| `:integer`                     | ✅     | ✅                 | Native signed-64-bit decimal, underscore, and `0x`/`0b`/`0o` paths; Ruby fallback preserves Bignums and unusual syntax                         |
| `:float`                       | ✅     | ✅                 | Native finite decimal/scientific literals; Ruby fallback preserves overflow and other syntax; literal `Infinity` and `NaN` rejected            |
| `:decimal`                     | ✅     | ✅                 | Native finite `bigdecimal` parse followed by BigDecimal construction; Ruby fallback preserves arbitrary precision; infinities and NaN rejected |
| `:string`                      | ✅     | ✅                 | No non-string-to-string coercion                                                                                                               |
| `:symbol`                      | ✅     | ✅                 |                                                                                                                                                |
| `:array` / `:hash`             | ✅     | ✅                 |                                                                                                                                                |
| `:date`                        | ✅     | ✅                 | Native `YYYY-MM-DD`; Ruby ISO 8601 fallback for broader date syntax                                                                            |
| `:date_time` / `:datetime`     | ✅     | ✅                 | Native whole-second RFC 3339 and timezone-free `YYYY-MM-DDTHH:MM:SS`; Ruby fallback otherwise                                                  |
| `:time`                        | ✅     | ✅                 | Native RFC 3339; Ruby `Time.parse` fallback for time-only and broader syntax                                                                   |
| dry-types objects/constructors | ✅     | ✅                 | Ruby-owned fields call `#try`; conversion failures use the generic `is invalid` message                                                        |
| Sum types                      | ✅     | ✅                 | Ruby-owned direct `value(type)` fields only                                                                                                    |
| Enums/maps/intersections       | ❌     | ❌                 |                                                                                                                                                |
| Params hash-to-array coercion  | ❌     | N/A                |                                                                                                                                                |

The supported scalar corpus is differentially checked against the pinned
upstream version for numeric boundaries, boolean spellings, temporal parsing,
and symbols. This is a focused compatibility slice, not a claim of complete
`dry-types` coercion parity. Custom type objects are intentionally processed
by Ruby after native traversal; their conversion output is preserved, but
dry-schema's type-specific failure-message compilation and custom array-member
types remain unsupported.

## Schema predicates

| Predicate                           | Status | Owner                                          |
| ----------------------------------- | ------ | ---------------------------------------------- |
| `gt?`, `gteq?`, `lt?`, `lteq?`      | ✅     | Rust                                           |
| `size?`, `min_size?`, `max_size?`   | ✅     | Rust                                           |
| `odd?`, `even?`                     | ✅     | Rust                                           |
| `format?`                           | ✅     | Ruby Regexp                                    |
| `included_in?`, `excluded_from?`    | ✅     | Ruby                                           |
| `eql?`, `not_eql?`                  | ✅     | Ruby                                           |
| Arbitrary/custom predicate name     | ❌     | Explicit error at execution                    |
| Boolean predicate AST composition   | ❌     | Predicate blocks support sequential calls only |
| UUID and other dry-logic predicates | ❌     |                                                |

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

| Surface                               | Status | Notes                                                                  |
| ------------------------------------- | ------ | ---------------------------------------------------------------------- |
| `success?` / `failure?`               | ✅     |                                                                        |
| `to_h` / `[]` / `key?` / `values`     | ✅     |                                                                        |
| `errors.to_h`                         | ✅     | Nested hashes and integer indexes                                      |
| Enumerable errors                     | ✅     |                                                                        |
| Mutable `errors.messages` collection  | 🟡     | Read-only view; mutate a set through `#add`                            |
| `errors[:path]`                       | ✅     | Prefix filter                                                          |
| `errors.filter(:base?)`               | ✅     | Also `schema?` and `rule?`                                             |
| `errors(full: true)`                  | 🟡     | Simple humanized paths                                                 |
| Error `text`, `path`, `meta`, `code`  | ✅     |                                                                        |
| Hash pattern matching                 | ✅     |                                                                        |
| Tuple values/context pattern matching | ✅     |                                                                        |
| YAML messages/configured load paths   | ✅     | Supports localized schema templates and `%{token}` interpolation       |
| I18n backend/locales                  | ✅     | Delegates to the optional `i18n` gem; add it to the application bundle |
| Exact upstream message wording        | 🟡     | Common English messages only                                           |
| Hints/info message extensions         | ❌     |                                                                        |
| Monads extension                      | ❌     | `load_extensions` raises explicitly                                    |

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
