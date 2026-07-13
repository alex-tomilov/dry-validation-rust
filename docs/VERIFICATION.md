# Verification record

Date: 2026-07-12

## Toolchain

- CRuby 3.3.7
- Rust 1.97.0 for verification (the crate declares Rust 1.85)
- Magnus 0.8.2
- rb-sys 0.9.128
- Linux x86-64
- Cargo release profile with thin LTO

## Native build

The extension was built through `rb_sys/mkmf` and Cargo as an optimized
`cdylib`. The resulting local test binary was an x86-64 ELF shared object and
linked only to the ordinary platform runtime libraries; libclang was a build
dependency, not a runtime dependency.

## Rust tests

```text
running 4 tests
test tests::field_count_includes_nested_and_member_fields ... ok
test tests::plan_deserializes_into_typed_fields ... ok
test tests::type_messages_are_stable ... ok
test tests::predicate_messages_preserve_arguments ... ok

test result: ok. 4 passed; 0 failed
```

## Ruby integration tests

```text
28 runs, 51 assertions, 0 failures, 0 errors, 0 skips
```

Coverage areas:

- Params/JSON/plain-schema modes;
- scalar, Date/Time/BigDecimal, nested hash, and array-member coercion;
- required/optional/filled/maybe semantics;
- native and Ruby-owned predicates;
- indexed error paths;
- rule dependency skipping, nested and multi-key rules;
- `rule.each`;
- base/key errors and explicit metadata;
- options, context, global macros, and class macros;
- schema/rule inheritance and reusable schemas;
- exact and side-by-side entrypoints in isolated child processes;
- result pattern matching;
- concurrent calls from eight Ruby threads.

## Benchmark sanity run

Command:

```bash
N=100000 ruby -Ilib benchmark/schema_throughput.rb
```

The upstream comparison requires `dry-validation` to be installed separately
for the same Ruby; it is not part of this gem's dependency set.

One observed run:

```text
dry-validation-rust
  iterations: 100000
  throughput: 83002.7 validations/s
  allocated objects: 7100012

dry-validation
  iterations: 100000
  throughput: 19974.1 validations/s
  allocated objects: 9800009

comparison
  throughput ratio: 4.16x
  allocation ratio: 0.72x
```

This is only a smoke benchmark for regressions. A single synthetic comparison
must not be used as a public performance claim.

## Packaging checks

- Every Ruby source file passed `ruby -c`.
- The gemspec loaded and passed `Gem::Specification#validate`.
- `Cargo.lock` is included.
- The distributable archive excludes local toolchains, upstream checkouts,
  Cargo targets, generated Makefiles, logs, and platform-specific binaries.
