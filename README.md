# dry-validation-rust

`dry-validation-rust` is a performance-oriented hybrid Ruby/Rust validation
engine with familiar dry-validation-style contract syntax and a precisely
documented compatible subset. Rust handles the immutable declarative schema
execution path; Ruby preserves dynamic rules and Ruby-specific semantics.

> Status: feasibility prototype / `0.1.0.pre1`. It is deliberately not
> presented as a production-ready drop-in replacement.

Read [the support matrix](docs/SUPPORT_MATRIX.md), [compatibility matrix](docs/COMPATIBILITY.md),
[architecture](docs/ARCHITECTURE.md), and [feasibility study](docs/FEASIBILITY.md)
before considering real use.

## What this project is

- Rust owns the immutable schema plan, key lookup and normalization, nested
  traversal, built-in coercion, type checks, native predicates, output
  filtering, and structural error collection.
- Ruby owns class-level DSL capture, arbitrary rule blocks, injected Ruby
  objects, macros, custom behavior, and Ruby-specific predicate semantics.

Rewriting arbitrary Ruby blocks into Rust is neither generally possible nor
desirable. Calling those blocks through Ruby preserves the feature that makes
`dry-validation` useful: domain validation can be normal Ruby.

## What this project is not

- It is not a proven drop-in replacement for upstream `dry-validation`.
- It is not a full Rust rewrite of the dry-rb validation stack.
- It does not claim full upstream compatibility without fixture-backed,
  version-pinned differential evidence.
- It does not claim general speedups without representative benchmarks.

## Primary safe API

Use the side-by-side namespace first:

```ruby
require "dry/validation/rust"

class NewUserContract < Dry::Validation::Rust::Contract
  params do
    required(:email).filled(:string, format?: /\A[^@]+@[^@]+\z/)
    required(:age).value(:integer)
    optional(:display_name).maybe(:string)

    required(:addresses).array(:hash) do
      required(:city).filled(:string)
      required(:postcode).filled(:string)
    end
  end

  rule(:age) do
    key.failure("must be at least 18") if value < 18
  end
end

result = NewUserContract.new.call(
  "email" => "jane@example.org",
  "age" => "17",
  "display_name" => "",
  "addresses" => [{"city" => "Astana", "postcode" => "010000"}]
)

result.to_h
result.success?
result.errors.to_h
```

This is the primary supported API. Version, platform, and upstream-reference
targets are listed in [SUPPORT_MATRIX.md](docs/SUPPORT_MATRIX.md). Supported
DSL and semantic differences are listed in [COMPATIBILITY.md](docs/COMPATIBILITY.md).

## Migration-compatible subset

The safe API intentionally keeps familiar contract syntax where that behavior
is implemented and covered. Use it for comparison work and gradual migration
without taking over upstream constants:

```ruby
require "dry/validation/rust"

class AgeContract < Dry::Validation::Rust::Contract
  params do
    required(:age).value(:integer)
  end
end
```

## Exact compatibility shim

Exact compatibility mode keeps upstream-like require paths and constants:

```ruby
require "dry/validation"

class AgeContract < Dry::Validation::Contract
  params do
    required(:age).value(:integer)
  end
end
```

> Collision warning: exact compatibility mode is experimental and opt-in. Do
> not install or activate upstream `dry-validation` / `dry-schema` in the same
> process when using `require "dry/validation"` or `require "dry/schema"` from
> this gem. Both implementations own the same require paths and constants. This
> gem raises a clear `LoadError` when it can detect such a collision.

The exact shim currently lives in this gem. If maintaining the shim separately
becomes necessary, the intended product split is `dry-validation-rust` for the
safe namespace and `dry-validation-rust-compat` for the upstream-like require
paths. No split is planned for the `0.1.x` line without concrete maintenance
evidence.

## Loading modes

### Side-by-side mode

`require "dry/validation/rust"` exposes only the
`Dry::Validation::Rust` namespace. It does not define
`Dry::Validation::Contract` or `Dry::Schema`.

### Exact compatibility mode

`require "dry/validation"` defines:

- `Dry::Validation::Contract` and related result/message aliases;
- minimal `Dry::Schema.Params`, `Dry::Schema.JSON`, and
  `Dry::Schema.define` factories for reusable schemas.

The collision warning above applies to every exact-mode entrypoint.

## Supported highlights

This section is a summary. Version and platform support is authoritative in
[SUPPORT_MATRIX.md](docs/SUPPORT_MATRIX.md); feature support is authoritative
in [COMPATIBILITY.md](docs/COMPATIBILITY.md).

- `params`, `json`, and plain `schema` modes.
- String-key normalization for Params and JSON.
- Integer, float, decimal, boolean, symbol, Date, DateTime, and Time Params
  coercions.
- Required/optional keys, `filled`, `maybe`, hashes, arrays, primitive array
  members, and arrays of nested hashes.
- Numeric and size predicates in Rust; format, inclusion, exclusion, and Ruby
  equality predicates in Ruby for semantic fidelity.
- Ordered rules that run only when their schema dependencies succeeded.
- Symbol, dot-string, array, and simple hash rule paths.
- `value`, `values`, `key?`, `key.failure`, `key(path).failure`,
  `base.failure`, `schema_error?`, `rule_error?`, and
  `base_rule_error?`.
- `rule.each` with `index:`.
- Global and class macros, macro arguments, injected `option` values, and
  mutable per-call context.
- Result hashes, message sets, metadata, full messages, filtering, and Ruby
  pattern matching.
- Contract inheritance and compatible schema reuse.

The complete exclusions and semantic differences are explicit in
[COMPATIBILITY.md](docs/COMPATIBILITY.md).

## Building from source

Requirements:

- Ruby 3.3 or newer with development headers;
- Rust 1.85 or newer and Cargo;
- a C toolchain;
- libclang where the selected `rb-sys` build uses bindgen.

Then:

```bash
bundle install
bundle exec rake compile
bundle exec rake test
```

The source gem declares `rb_sys ~> 0.9` and builds through the ordinary Ruby
native-extension lifecycle.

## Verification

The prototype was compiled and tested in this archive with:

- CRuby 3.3.7;
- Rust 1.97.0;
- Magnus 0.8.2;
- rb-sys 0.9.128;
- an optimized release profile.

The test suite covers the native plan, coercion modes, nested data, rules,
rule skipping, array rules, macros, options, context, inheritance, external
schemas, loading modes, pattern matching, metadata, and concurrent calls.

Run a local throughput/allocation sanity benchmark with:

```bash
ruby -Ilib benchmark/schema_throughput.rb
N=500000 ruby -Ilib benchmark/schema_throughput.rb
ENGINE=rust ruby -Ilib benchmark/schema_throughput.rb
ENGINE=upstream ruby -Ilib benchmark/schema_throughput.rb
```

By default the benchmark compares this Rust-backed hybrid implementation with
the upstream `dry-validation` gem in a separate Ruby process. The upstream gem
is intentionally not a project dependency; install it for the same Ruby with
`gem install dry-validation` before running `ENGINE=all` or `ENGINE=upstream`.
Do not interpret a single synthetic result as proof that the gem is faster than
upstream. Real comparisons must use representative schemas, payload sizes,
valid/invalid mixes, warmup, multiple Ruby versions, and RSS as well as
throughput.

## Important performance caveat

The native engine currently reads and creates Ruby objects, so it runs under
the GVL. Rust reduces Ruby method dispatch and intermediate DSL execution; it
does not automatically make validation parallel.

A future batch API could copy supported values into Rust-owned memory and
release the GVL, but serialization/copy cost and Ruby object semantics make
that a separate feature—not a free property of using Rust.

## License and relationship to dry-rb

This code is MIT licensed and independent. `dry-validation` and its related
dry-rb projects are MIT licensed as well, which permits reimplementation and
derivative work subject to preserving required notices when source is copied.
See [NOTICE.md](NOTICE.md). The distinct gem name and explicit non-affiliation
are intentional.
