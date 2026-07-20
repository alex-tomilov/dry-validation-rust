# Clean-room verification

This record separates runnable evidence from configured or unsupported paths.
The reusable entrypoint is [`script/clean-room-verify`](../script/clean-room-verify),
which delegates to the existing Docker smoke, Ruby test, demo, and source-gem
audit paths rather than maintaining a second implementation of those checks.

## Observed matrix

The local Stage 07 runs used committed HEAD `f26804df9fee543df33e531ad43b181c771c71ee`
plus the uncommitted clean-room script, tests, workflow, and documentation. The
script therefore labeled the local image revision `-dirty`. A scheduled/manual
workflow reruns the same no-cache path from a clean committed checkout.

| Scenario | Date | Commit | Environment | Command | Result | Evidence location | Limitations |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Public prebuilt image | 2026-07-20 | `f26804d` | Linux x86-64; Docker 28.0.1; empty temporary Docker config | `docker pull --platform linux/amd64 ghcr.io/alex-tomilov/dry-validation-rust:build-week-2026` | **UNAVAILABLE** — anonymous registry request returned `denied` | [Docker publication status](DOCKER.md#prepared-ghcr-publication) | No public pull, RepoDigest, or runtime success is claimed. Publication and anonymous verification remain external blockers. |
| Local Docker build | 2026-07-20 | `f26804d-dirty` | Ubuntu 26.04; Linux 7.0.0-28; x86-64; Docker 28.0.1 | `script/clean-room-verify --docker-only --output tmp/clean-room/stage07-docker-verified` | **PASSED** — cache-disabled Linux amd64 build; default/JSON demo, `doctor`, `test`, benchmark smoke, unknown-command failure, and offline runtime checks passed | Generated redacted `summary.md`, `environment.txt`, and logs under the ignored output directory; reproducible via the script and [clean-room workflow](../.github/workflows/clean-room.yml) | Local ephemeral image `sha256:c738898bb83af92760fecd0f736e35a27b701ee024bde1f5f26acc73bc957e2f`; rerun after the Stage 07 commit for an exact clean-commit image label. |
| Native Linux source build | 2026-07-20 | `f26804d` plus Stage 07 working tree | Linux 7.0.0-28 x86-64; CRuby 3.3.7; Bundler 2.5.22; Rust/Cargo 1.90.0 | `script/clean-room-verify --native-only --output tmp/clean-room/stage07-native-verified` | **PASSED** — isolated bundle install, compile, 121 tests/1,438 assertions, and 10-check demo | Generated redacted logs under the ignored output directory; canonical details in [VERIFICATION.md](VERIFICATION.md) | Proves this Linux/Ruby/toolchain combination only. Dependency installation requires RubyGems network access. |
| Native macOS source build | Not run in Stage 07 | `f26804d` | `macos-latest` is present in the Ruby 3.3-3.5 CI matrix | `bundle exec rake compile`, `bundle exec rake test`, `bundle exec rake package:audit` | **UNVERIFIED HERE** | [CI workflow](../.github/workflows/ci.yml) | Linux evidence is not treated as macOS evidence. Consult an actual successful Actions run before changing this status. |
| Source gem isolated install | 2026-07-20 | `f26804d` plus Stage 07 working tree | Linux x86-64; CRuby 3.3.7; isolated Bundler path and temporary `GEM_HOME` | `script/clean-room-verify --package-only --output tmp/clean-room/stage07-package-verified` | **PASSED** — manifest audit, source-gem build, isolated install, safe require, and minimal valid/invalid contract calls | Generated redacted logs; implementation in [`Rakefile`](../Rakefile) and CI in [package workflow](../.github/workflows/package.yml) | Builds a source gem on the current machine; it is not a precompiled platform gem or a publication test. |
| Native Windows | Not run | N/A | N/A | N/A | **UNSUPPORTED / UNVERIFIED** | [Support matrix](SUPPORT_MATRIX.md) | No native Windows claim for `0.1.x`. |
| JRuby / TruffleRuby | Not run | N/A | N/A | N/A | **UNSUPPORTED** | [Support matrix](SUPPORT_MATRIX.md) | The native backend targets CRuby through Magnus/rb-sys. |

## What the Docker path proves

The local Docker check uses an empty temporary `DOCKER_CONFIG`, pulls public
base images without repository credentials, and always supplies `--no-cache`,
`--pull`, and `--platform linux/amd64`. After the build it reuses
[`script/docker-smoke`](../script/docker-smoke) to run:

- the default human-readable demo;
- the asserted JSON demo;
- `doctor` and its native-extension diagnostics;
- the packaged precompiled runtime test;
- the short pinned upstream benchmark smoke;
- unknown-command failure; and
- all runtime containers with `--network none`.

The temporary local tag is removed when the orchestrator exits. Ordinary
developer builds remain cache-friendly; cache disabling is specific to this
clean-room path and its scheduled/manual CI workflow.

## Running the verifier

Choose one mode, or use `--all`:

```bash
script/clean-room-verify --docker-only
script/clean-room-verify --native-only
script/clean-room-verify --package-only
script/clean-room-verify --all
```

To test a published image anonymously, supply a tag or digest:

```bash
script/clean-room-verify --docker-only \
  --image ghcr.io/alex-tomilov/dry-validation-rust@sha256:<VERIFIED_DIGEST>
```

The image pull must produce a `RepoDigest`; otherwise the requested public
image check fails. The intended competition image is not shown as a runnable
command until anonymous access has been verified.

Custom output must remain below the repository's ignored `tmp/` directory:

```bash
script/clean-room-verify --package-only \
  --output tmp/clean-room/package-review
```

Each run writes:

```text
environment.txt       selected versions and repository state only
summary.tsv           machine-readable PASS / SKIP / FAIL rows
summary.md            human-readable result table
logs/*.log            redacted command output
native-bundle/        isolated dependencies for native/package modes
```

Existing output is never overwritten. Paths under the repository root and
user home plus common token/secret patterns are redacted before logs are
stored. The script does not dump the process environment, elevate privileges,
install system packages, or write registry credentials. A failed requested
command makes the script exit nonzero; an unavailable prerequisite is recorded
as `SKIPPED`, never as `PASSED`.

## Automated evidence

`.github/workflows/clean-room.yml` adds only the missing coverage: a weekly or
manual Linux amd64 Docker build without cache followed by the offline smoke
suite. It does not duplicate the Ruby/macOS matrix or source-gem jobs. The
workflow uploads only the selected metadata, summaries, and redacted logs for
14 days and has read-only repository permissions.

The existing container publication workflow separately pulls a published
image by digest and tests it. That authenticated post-publication job is useful
release evidence, but it does not replace the anonymous pull required before a
public judge command is advertised.
