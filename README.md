# dry-validation-rust

A hybrid Ruby/Rust validation engine that executes a supported declarative schema plan in Rust while preserving dynamic Ruby business rules.

> **Prototype:** `0.1.0.pre1` implements a documented subset of `dry-validation`. It is not a production-ready drop-in replacement.

## Try it

After the Build Week package is public:

```bash
docker run --rm \
  --platform linux/amd64 \
  ghcr.io/alex-tomilov/dry-validation-rust:build-week-2026
```

Before sharing that command with judges, confirm it works after `docker logout ghcr.io`.

Local fallback:

```bash
docker build --pull --platform linux/amd64 \
  -t dry-validation-rust:local .

docker run --rm --network none --platform linux/amd64 \
  dry-validation-rust:local
```

The image runs a deterministic demonstration and needs no OpenAI API key. Once built or pulled, the demo also needs no network connection.

## What the demo proves

The order contract demonstrates:

- string-key normalization and supported coercion;
- nested hashes and arrays of hashes;
- structural errors combined with a Ruby business rule;
- dependent-rule skipping after a coercion failure.

Each displayed `PASS` is an assertion. A mismatch exits nonzero. Use `script/demo --json` for machine-readable output.

## How the hybrid works

| Rust owns | Ruby owns |
|---|---|
| Immutable declarative schema plans | Contract classes and the public DSL |
| Supported normalization and coercion | Arbitrary rule blocks |
| Nested traversal and native predicates | Macros, options, context, and injected objects |
| Filtered output and structural errors | Ruby-specific business semantics |

Arbitrary Ruby blocks cannot be translated transparently into Rust. Keeping them in Ruby preserves ordinary application behavior while moving repeatable structural work into a typed native plan. See [ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Primary API

Use the isolated namespace:

```ruby
require "dry/validation/rust"

class NewUserContract < Dry::Validation::Rust::Contract
  params do
    required(:email).filled(:string, format?: /\A[^@]+@[^@]+\z/)
    required(:age).value(:integer)

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
  "addresses" => [
    {"city" => "Astana", "postcode" => "010000"}
  ]
)

result.to_h
result.success?
result.errors.to_h
```

`Dry::Validation::Rust::Contract` is the supported side-by-side API. The [compatibility matrix](docs/COMPATIBILITY.md) and [support matrix](docs/SUPPORT_MATRIX.md) define the tested subset and platforms.

## Benchmarking

The comparative suite runs this project and pinned upstream gems in separate processes. Quick mode is a smoke check, not publication evidence:

```bash
script/benchmark-suite --mode quick --output tmp/benchmark-quick
```

Headline figures should appear only after a clean full run has produced raw samples, environment metadata, and a generated summary. Results remain workload- and environment-specific. See [BENCHMARKING.md](docs/BENCHMARKING.md).

## OpenAI Build Week 2026

The feasibility prototype existed before the submission period. During Build Week, GPT-5.6 helped review the architecture and shape an engineering roadmap. Codex helped implement and verify accepted work, including the demo, Docker judge path, GHCR workflow, and benchmark tooling.

The human author retained responsibility for architecture, scope, and claim boundaries. The validation runtime remains deterministic Ruby and Rust and does not call an OpenAI model. See [the Build Week narrative and evidence](docs/BUILD_WEEK_2026.md).

## Build and verify

Native builds require CRuby, Bundler, the pinned Rust toolchain, a C toolchain, and the dependencies listed in [SUPPORT_MATRIX.md](docs/SUPPORT_MATRIX.md).

```bash
bundle install
bundle exec rake compile
bundle exec rake test
script/verify
```

Focused checks:

```bash
script/demo
script/demo --json
script/docker-smoke
```

## Current limitations

- Only the documented compatibility subset is implemented.
- Exact upstream-style constants are experimental and must not share a process with upstream `dry-validation` or `dry-schema`.
- Execution still uses Ruby objects under the GVL; this is not a GVL-free parallel engine.
- Small contracts and rule-heavy workloads can see neutral or negative native overhead.
- Linux arm64, musl/Alpine, native Windows, JRuby, TruffleRuby, and Ractors are not supported targets.
- Performance claims require committed full-run evidence for a named workload and environment.

## Documentation

- [Build Week 2026](docs/BUILD_WEEK_2026.md)
- [Docker judge image](docs/DOCKER.md)
- [Video package](docs/VIDEO_DEMO.md)
- [Benchmark methodology](docs/BENCHMARKING.md)
- [Support matrix](docs/SUPPORT_MATRIX.md)
- [Compatibility matrix](docs/COMPATIBILITY.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Verification](docs/VERIFICATION.md)

## License and non-affiliation

The project is MIT licensed and independent of the dry-rb project. See [NOTICE.md](NOTICE.md).
