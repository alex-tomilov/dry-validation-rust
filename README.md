# dry-validation-rust

A performance-oriented hybrid Ruby/Rust validation engine that executes an
immutable declarative schema plan in Rust while preserving dynamic Ruby
business rules.

> **Status: feasibility prototype (`0.1.0.pre1`).** This project is not a
> production-ready drop-in replacement for `dry-validation`. Its supported
> subset, platform targets, and known differences are documented explicitly.

## Try it with Docker

> **Public image status (checked July 20, 2026):** the intended Build Week
> competition tag is not anonymously accessible, so this README does not
> advertise it as a working judge command. The verified fallback below builds
> the image from this checkout and runs the demo.

From the repository root, build and run the deterministic demo in one command:

```bash
docker build --pull --platform linux/amd64 -t dry-validation-rust:local . && \
  docker run --rm --network none --platform linux/amd64 dry-validation-rust:local
```

Only Docker with Linux amd64 container support is required on the host; Docker
Desktop can use emulation on Apple Silicon. The build downloads its pinned
builder images and dependencies, compiles the project, and produces a Linux
amd64 image with the native extension already installed. The demo itself runs
without network access and does not need Ruby, Rust, Bundler, or an OpenAI API
key on the host. See [the Docker guide](docs/DOCKER.md) for platform notes, JSON
output, runtime checks, benchmarks, and public-image status.

## Expected demo behavior

The asserted order-validation demo exercises string-key normalization, scalar
coercion, nested arrays and hashes, structural errors, a dynamic Ruby business
rule, and dependency-based rule skipping. A successful run includes:

```text
dry-validation-rust — deterministic demo

[1/3] Valid nested input
PASS  result succeeded
...
[2/3] Structural and Ruby rule errors
...
[3/3] Failed coercion skips dependent rule
...
Demo complete: 10 checks passed
```

Every `PASS` is backed by an assertion; the command exits nonzero if a check
fails. The same report is available as JSON with `demo --json` inside the
image or `script/demo --json` in a compiled source checkout.

## Why hybrid?

Ruby and Rust own different parts of validation:

| Rust owns | Ruby owns |
| --- | --- |
| Immutable declarative schema plan | Public contract DSL and class definition |
| Key normalization and supported coercions | Arbitrary rule blocks and method dispatch |
| Nested traversal and native predicates | Macros, options, context, and injected objects |
| Filtered output and structural errors | Ruby-specific predicates and business semantics |

Arbitrary Ruby blocks cannot be translated transparently into Rust. Keeping
them in Ruby preserves normal application behavior while moving repeatable
structural work into a typed native plan. The complete boundary is described
in [ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Primary safe API

Use the side-by-side namespace:

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
  "addresses" => [{"city" => "Astana", "postcode" => "010000"}]
)

result.to_h
result.success?
result.errors.to_h
```

`Dry::Validation::Rust::Contract` is the primary supported API. It does not
claim upstream constants and is the safest way to compare or migrate a
contract incrementally.

## Supported highlights

- Params, JSON, and non-coercing schema modes.
- Required and optional fields, `filled`, `maybe`, nested hashes, primitive
  arrays, and arrays of hashes.
- Common scalar coercions plus native numeric and size predicates.
- Ordered Ruby rules, nested paths, `rule.each`, macros, options, and mutable
  per-call context.
- Structured results, nested error paths, metadata, filtering, and pattern
  matching.
- Contract inheritance and compatible external schema reuse.
- Explicit errors for unsupported types, predicates, configuration, and DSL
  features instead of silent success.

These are highlights, not a compatibility promise. The
[support matrix](docs/SUPPORT_MATRIX.md) is authoritative for versions and
platforms; the [compatibility matrix](docs/COMPATIBILITY.md) lists the tested
feature subset and exclusions against pinned `dry-validation` 1.11.1 and
`dry-schema` 1.16.0.

## Benchmark evidence

The repository includes a separate-process benchmark suite covering shallow,
nested, and array-of-hashes workloads with valid, invalid, and mixed inputs.
It captures raw samples, environment metadata, throughput, allocations, GC
metrics, and Linux peak RSS while checking normalized outcome equivalence
between this project and pinned upstream gems.

The clean-commit full evidence package has not yet been generated, so no
headline performance figure is presented here. See the
[benchmark methodology](docs/BENCHMARKING.md) and the
[evidence-package status](benchmark/results/build-week-2026/README.md).
Quick-mode and earlier development snapshots are diagnostic evidence only.
Any eventual result applies to its named workload and environment; it is not a
universal performance claim.

## OpenAI Build Week 2026

This repository and its working feasibility prototype existed before the
submission period began on July 13, 2026. Build Week work is separated from
that baseline in the dated [evidence ledger](docs/BUILD_WEEK_2026_EVIDENCE.md).
Post-boundary additions include canonical verification, a deterministic judge
demo, a precompiled Docker image recipe, a restricted GHCR workflow, and a
reproducible comparative benchmark harness.

GPT-5.6 was used as an architecture and repository-review partner: it analyzed
the prototype and its maturity, identified correctness, compatibility,
native-boundary, benchmark, packaging, CI, security, and documentation risks,
and helped shape a staged roadmap. Codex helped inspect the repository,
implement accepted stages, refine tests, run verification, diagnose failures,
and prepare Docker, CI, benchmark, and judge-facing documentation. The human
author retained the architecture, feature scope, claim boundaries, and final
acceptance decisions.

The validation runtime is deterministic Ruby and Rust and does not require an
OpenAI API key. It does not call GPT-5.6 at runtime. The full
[Build Week narrative](docs/BUILD_WEEK_2026.md) separates the pre-existing
foundation, submission-period additions, GPT-5.6/Codex contributions, and
human decisions.

> **Submission blocker:** the primary Codex `/feedback` Session ID has not
> been supplied for this checkout. Replace
> `<PRIMARY_CODEX_FEEDBACK_SESSION_ID>` in the Build Week narrative before
> submission.

## Building from source

| Path | Requirements | Current status |
| --- | --- | --- |
| Prebuilt Docker judge path | Docker with Linux amd64 container support | Local image verified; public competition tag not yet anonymously accessible |
| Native Linux source build | CRuby 3.3-3.5, Rust 1.85+, Cargo, C toolchain, and libclang when bindgen is selected | Source-build target; Linux x86-64 verified |
| Native macOS source build | CRuby 3.3-3.5, Rust 1.85+, Cargo, Xcode command-line tools, and libclang when bindgen is selected | Source-build CI target; consult the current verification record |
| Native Windows | No supported path | Unverified and unsupported for `0.1.x` |
| JRuby or TruffleRuby | Not applicable to this CRuby extension | Unsupported |

For a native source build:

```bash
bundle install
bundle exec rake compile
bundle exec rake test
```

The gem declares `rb_sys ~> 0.9` and follows the ordinary Ruby native-extension
build lifecycle. Exact targets and caveats remain in
[SUPPORT_MATRIX.md](docs/SUPPORT_MATRIX.md).

## Verification and contributing

Run the canonical verification gate:

```bash
script/verify
```

It compiles and tests the Ruby/Rust extension, checks Rust formatting and
Clippy, audits source-gem contents, installs the built gem into a clean
temporary gem home, and runs an installed-contract smoke test. Useful focused
commands are:

```bash
script/demo
script/demo --json
script/benchmark-suite --mode quick --output tmp/benchmark-quick
bundle exec rake package:audit
```

See [VERIFICATION.md](docs/VERIFICATION.md) for the recorded toolchain, test
counts, CI jobs, and command details. Contribution and support routes are in
[CONTRIBUTING.md](CONTRIBUTING.md), [SUPPORT.md](SUPPORT.md),
[SECURITY.md](SECURITY.md), [GOVERNANCE.md](GOVERNANCE.md), and the
[Code of Conduct](CODE_OF_CONDUCT.md).

## Current limitations and performance caveats

- Only the documented compatibility subset is implemented; this is not full
  `dry-validation` compatibility.
- YAML/I18n message backends, processor hooks, dry-types constructors,
  predicate composition, schema merge/AST APIs, and extensions such as monads
  are not implemented.
- The native engine reads and creates Ruby objects, so normal execution remains
  under the GVL. Thread-safe plan reuse does not mean GVL-free parallelism.
- Small contracts or rule-heavy workloads may see neutral or negative native
  overhead. Compilation time is outside the current repeated-call benchmarks.
- Linux arm64, musl/Alpine, native Windows, JRuby, TruffleRuby, and Ractors are
  not supported targets for this prototype.
- A public prebuilt image, committed full benchmark package, and public demo
  video are not yet available.

## Exact compatibility shim

The experimental exact shim provides upstream-like require paths and constants:

```ruby
require "dry/validation"

class AgeContract < Dry::Validation::Contract
  params do
    required(:age).value(:integer)
  end
end
```

> **Collision warning:** do not activate upstream `dry-validation` or
> `dry-schema` in the same process as this gem's exact mode. Both
> implementations own the same require paths and constants. Exact mode is
> opt-in, experimental, and tested in a process isolated from upstream gems.

The safe namespace above is the recommended path. See
[COMPATIBILITY.md](docs/COMPATIBILITY.md) for loading behavior and migration
guidance.

## Documentation

- [Build Week 2026 narrative](docs/BUILD_WEEK_2026.md)
- [Build Week evidence ledger](docs/BUILD_WEEK_2026_EVIDENCE.md)
- [Docker judge image](docs/DOCKER.md)
- [Clean-room verification](docs/CLEAN_ROOM_VERIFICATION.md)
- [Benchmark methodology](docs/BENCHMARKING.md)
- [Support matrix](docs/SUPPORT_MATRIX.md)
- [Compatibility matrix](docs/COMPATIBILITY.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Verification record](docs/VERIFICATION.md)
- [Feasibility study](docs/FEASIBILITY.md)
- [Project management](docs/PROJECT_MANAGEMENT.md)

## License and non-affiliation

This project is MIT licensed and independent of the dry-rb project. The
distinct gem name and explicit non-affiliation are intentional. Upstream
projects are also MIT licensed; provenance and notice details are recorded in
[NOTICE.md](NOTICE.md).
