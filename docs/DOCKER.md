# Docker judge image

The Docker image provides a short, deterministic evaluation path with the
native extension already compiled. Judges need Docker, but do not need Ruby,
Rust, Clang, development headers, Bundler, an OpenAI API key, or network access
while the container runs.

## Build locally

From the repository root:

```bash
docker build --pull -t dry-validation-rust:local .
```

This is a source build: Docker downloads the pinned Ruby 3.3.7 and Rust 1.85.0
builder images, installs build-only packages, compiles the extension, and runs
the asserted demo. The final Debian-based image copies the Ruby runtime, Ruby
standard library, compiled extension, and an isolated upstream benchmark gem
set; it does not copy Cargo, rustc, Clang, Ruby headers, Bundler, project gem
dependencies, or build caches from the builder.

## Run the image

The default command is `demo`:

```bash
docker run --rm dry-validation-rust:local
docker run --rm dry-validation-rust:local demo
docker run --rm dry-validation-rust:local demo --json
docker run --rm dry-validation-rust:local doctor
docker run --rm dry-validation-rust:local test
docker run --rm dry-validation-rust:local benchmark
docker run --rm dry-validation-rust:local benchmark --iterations 100000 --warmup 10000
docker run --rm dry-validation-rust:local benchmark --engine compare --iterations 100000 --warmup 10000
docker run --rm dry-validation-rust:local benchmark-suite --mode quick --output /tmp/benchmark-quick
docker run --rm dry-validation-rust:local help
```

`test` is the packaged runtime smoke suite, not the complete contributor test
suite. It verifies that the copied native extension is loaded from the image
and then runs all 10 deterministic demo assertions. The full Ruby and Rust
test suites remain available through the source-build workflow documented in
[VERIFICATION.md](VERIFICATION.md).

`benchmark` runs the existing synthetic schema-throughput benchmark. It
defaults to 1,000 measured Rust-engine calls after 100 warmup calls. Use
`--iterations` and `--warmup` to control those counts, `--engine rust`,
`--engine upstream`, or `--engine compare` to select engines, and
`--format json` or `--format text` to select output. The image includes pinned
`dry-validation` 1.11.1 and `dry-schema` 1.16.0 gems only for the isolated
upstream benchmark subprocess; the normal demo and Rust measurement do not
load them.

`benchmark-suite` runs the newer multi-workload evidence harness documented in
[BENCHMARKING.md](BENCHMARKING.md). Quick mode is for smoke reproduction only.
The container includes GNU `time`, so isolated quick workers record peak RSS in
KiB. Generate full evidence from a clean source checkout where the recorded
Rust and Cargo toolchains are also available.

For example, capture five independent comparison samples without container
network access:

```bash
for run in 1 2 3 4 5; do
  docker run --rm --network none dry-validation-rust:local \
    benchmark --engine compare --iterations 100000 --warmup 10000 \
    > "benchmark-${run}.json"
done
```

Report the exact image digest, hardware, Ruby and gem versions, iteration and
warmup counts, all samples, and a median plus range or dispersion. This is one
valid-input schema with Rust measured before upstream in separate Ruby
processes. It does not cover invalid inputs, compilation time, RSS, concurrency,
or multiple schema shapes, so its ratio is not a universal performance claim.

## Observed development benchmark snapshot

On 2026-07-19, five sequential comparison runs were captured from the local
Linux amd64 image with networking disabled. This was a dirty-worktree image,
so the result is a reproducibility snapshot for development and must be rerun
from a clean commit before it is used as final submission or release evidence.

- Image ID: `sha256:ed02688ecdc81c653bee81f7e2c4d5bdc765bf40a253efc1cae478fa5d088dd4`
- Image revision: `fc254cfa8d685cc8aa3a8e24cd621249790e6fef-dirty`
- Host CPU: AMD Ryzen 7 5800H, 8 cores and 16 threads
- Host kernel: Linux 7.0.0-27-generic, x86-64
- Docker client/server: 28.0.1
- Ruby: 3.3.7
- Engines: `dry-validation-rust` 0.1.0.pre1 and `dry-validation` 1.11.1
  with `dry-schema` 1.16.0
- Per sample: 10,000 warmup calls followed by 100,000 measured calls per
  engine
- Execution order: Rust-backed engine first, then upstream in a separate Ruby
  process

| Sample | Rust-backed validations/s | Upstream validations/s | Paired throughput ratio |
| -----: | ------------------------: | ---------------------: | ----------------------: |
|      1 |                  95,740.9 |               22,024.5 |                   4.35x |
|      2 |                 101,746.4 |               20,579.6 |                   4.94x |
|      3 |                  93,190.0 |               21,720.2 |                   4.29x |
|      4 |                 101,474.1 |               20,977.7 |                   4.84x |
|      5 |                  90,252.1 |               21,036.1 |                   4.29x |

The median Rust-backed throughput was 95,740.9 validations/s, with a
90,252.1-101,746.4 range. Median upstream throughput was 21,036.1
validations/s, with a 20,579.6-22,024.5 range. The median of the five paired
throughput ratios was 4.35x, and the paired-ratio range was 4.29x-4.94x.
Values are rounded for readability; ratios were calculated from the unrounded
JSON results.

Every sample reported 7,100,012 measured allocations for the Rust-backed
engine and 9,800,009 for upstream, an allocation ratio of 0.724x. These counts
include the benchmark loop and result construction. They do not measure RSS or
GC time.

## Runtime independence

All runtime commands operate without external services or network access:

```bash
docker run --rm --network none dry-validation-rust:local demo
docker run --rm --network none dry-validation-rust:local doctor
docker run --rm --network none dry-validation-rust:local test
```

The image runs as the unprivileged `dvr` user with numeric UID and GID 10001.
The normal `demo` and `test` commands use the safe `Dry::Validation::Rust`
namespace and do not load upstream `dry-validation`. Only `benchmark --engine
upstream` or `benchmark --engine compare` activates the isolated upstream gem
set, in a separate Ruby process.

## Automated smoke verification

The repository smoke script builds the image, runs the default and JSON demos,
validates the JSON report, runs `doctor` and `test`, and checks that an unknown
command fails. Runtime checks use `--network none`.

```bash
script/docker-smoke
script/docker-smoke --tag dry-validation-rust:review
DVR_DOCKER_PLATFORM=linux/amd64 script/docker-smoke
script/docker-smoke --skip-build --tag dry-validation-rust:local
script/docker-smoke --cleanup
```

The image is left available for inspection unless `--cleanup` or
`DVR_DOCKER_CLEANUP=1` is supplied. The smoke script sets the OCI revision to
the exact commit SHA for a clean checkout and appends `-dirty` when local
tracked or untracked changes are present, so locally measured evidence is not
misattributed to an unchanged commit.

## Prepared GHCR publication

The repository now contains `.github/workflows/container.yml`, which can build
and test pull-request images without publishing and can publish a Linux amd64
image after a manual dispatch or an explicit `build-week-*` or semantic-version
tag. Preparing the workflow does not prove that a public package exists.

Intended competition convenience tag, currently **unavailable until a
successful workflow run and anonymous pull prove otherwise**:

```text
ghcr.io/alex-tomilov/dry-validation-rust:build-week-2026
```

That competition tag can move when the maintainer intentionally republishes
it. The workflow also creates a full commit-SHA tag. For immutable evaluation,
use the registry digest emitted by the successful workflow. This template is
not runnable until `<PUBLISHED_DIGEST>` is replaced with a verified value:

```text
ghcr.io/alex-tomilov/dry-validation-rust@sha256:<PUBLISHED_DIGEST>
```

After publication, the workflow uses a separate clean job to pull that digest
and run the default demo, JSON validation, `doctor`, `test`, the offline demo,
and the packaged benchmark comparison. It records the exact tags, digest,
platform, and workflow URL in the GitHub Actions job summary.

### Repository-owner publishing checklist

Review the workflow revision first and confirm that only `linux/amd64` is
claimed. Then:

1. Confirm the existing GHCR package visibility is public. On the first
   publication, inspect the newly created package immediately and make it
   public before advertising it; the workflow cannot change visibility.
2. Manually run the `Container` workflow with `build-week-2026`, or push an
   explicitly authorized `build-week-*`/semantic-version tag.
3. From a logged-out or otherwise anonymous environment, pull the commit-SHA
   tag and then the digest reported by the workflow.
4. Run the default demo, JSON demo, `doctor`, and `test`, including a
   `--network none` invocation.
5. Capture the successful workflow URL, date, full image digest, commit tag,
   and anonymous-pull result.
6. Replace `<PUBLISHED_DIGEST>` and this unavailable marker only after those
   checks pass, then add the verified judge command to the README in Stage 06.

Owner-run verification after the package is public:

```bash
docker logout ghcr.io || true
docker pull ghcr.io/alex-tomilov/dry-validation-rust:sha-<FULL_COMMIT_SHA>
docker run --rm ghcr.io/alex-tomilov/dry-validation-rust:sha-<FULL_COMMIT_SHA>
docker run --rm --network none \
  ghcr.io/alex-tomilov/dry-validation-rust:sha-<FULL_COMMIT_SHA> test
docker inspect --format='{{index .RepoDigests 0}}' \
  ghcr.io/alex-tomilov/dry-validation-rust:sha-<FULL_COMMIT_SHA>
```

## Platform support and limitations

- The judge image is verified only for Linux x86-64 with glibc.
- Linux arm64, musl/Alpine, macOS containers, and Windows containers are not
  claimed as supported image platforms.
- On Apple Silicon, use Docker's amd64 emulation when a native build selects an
  unverified platform:

  ```bash
  docker build --platform linux/amd64 -t dry-validation-rust:local .
  docker run --rm --platform linux/amd64 dry-validation-rust:local
  ```

- The image is an evaluation artifact for the `0.1.0.pre1` feasibility
  prototype, not a production-hardened service or a drop-in compatibility
  claim.
- The runtime image intentionally omits compilers, source tests, Ruby package
  tooling, installed project dependencies, and the complete contributor
  toolchain. The isolated pinned upstream gem set exists only to make benchmark
  comparisons reproducible. Build and test the project from a source checkout.
- The current native engine works with Ruby objects under the GVL; the image
  does not change that concurrency limitation.
