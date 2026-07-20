# OpenAI Build Week 2026

`dry-validation-rust` is entered in the Developer Tools track as a
pre-existing project that was meaningfully extended during the submission
period. This page explains what already existed, what changed, and how GPT-5.6,
Codex, and the human author each contributed.

The [evidence ledger](BUILD_WEEK_2026_EVIDENCE.md) is the dated, commit-level
record behind this narrative. The [official rules](https://openai.devpost.com/rules)
and [official FAQ](https://openai.devpost.com/details/faqs) remain authoritative
for competition requirements.

## Pre-existing foundation

Before the submission period began on July 13, 2026, the repository already
contained a working feasibility prototype. It included the Ruby contract DSL
and dynamic rule layer, a Rust native extension with an immutable schema plan,
safe and exact loading entrypoints, supported coercion and nested validation,
results and messages, tests, a simple benchmark, source-gem packaging, and
initial architecture, compatibility, feasibility, and verification documents.

Those capabilities are prior work. The baseline is commit
[`6e986c1`](https://github.com/alex-tomilov/dry-validation-rust/commit/6e986c164ddd7e9fab5854c81fa300c5df898476),
committed at `2026-07-13T14:34:14Z`, before the official
`2026-07-13T16:00:00Z` boundary.

## Meaningful Build Week additions

The repository evidence records these post-boundary improvements:

- a canonical verification command, fixture-backed behavior baseline,
  machine-readable benchmark smoke, and stronger source-package checks;
- explicit product scope, support and compatibility matrices, packaging
  metadata, CI/security workflows, dependency policy, and community/project
  governance;
- an asserted deterministic judge demo with human-readable and JSON output;
- a multi-stage Docker image that contains the precompiled native extension,
  runs unprivileged, and supports offline demo and smoke execution;
- a restricted GHCR workflow that builds, publishes only from authorized
  triggers, and verifies a published image by digest (the public competition
  image has not yet been anonymously verified);
- fixes for macOS native-extension loading and Ruby 3.5's separately packaged
  `benchmark` library; and
- a separate-process, multi-workload comparative benchmark harness with
  validity checks, raw samples, environment metadata, allocation/GC metrics,
  Linux peak RSS, and mechanically derived summaries.

The evidence ledger links each addition to its commit and repository artifact.
No pre-boundary runtime capability is counted as Build Week work.

## How GPT-5.6 contributed

GPT-5.6 was used through ChatGPT as an architecture and repository-maturity
review partner. It:

- analyzed the feasibility prototype and the Ruby/Rust responsibility boundary;
- identified correctness, compatibility, native-boundary, benchmark,
  packaging, CI, security, and documentation risks;
- helped create a staged implementation roadmap with tests, non-goals, and
  acceptance criteria; and
- helped review trade-offs and interpret implementation and verification
  results.

The contextual
[shared ChatGPT conversation](https://chatgpt.com/share/6a5c38e4-c380-83ed-a4cb-ac221d42d905)
is supplementary evidence. Git history and Codex session records provide the
implementation evidence; the shared page is not treated as a substitute for
those records.

## How Codex contributed

Codex inspected the repository and its instructions, implemented accepted
roadmap and Build Week stages, generated and refined regression tests, ran
focused and canonical verification, diagnosed native-build and cross-version
CI failures, and prepared the demo, Docker image, container workflow,
benchmark tooling, and public documentation.

The commit-to-session mappings currently available are recorded in the
[evidence ledger](BUILD_WEEK_2026_EVIDENCE.md). The primary Build Week thread's
final `/feedback` Session ID is still required below.

## Human decisions

The human author retained and approved the decisions that define the project:

- Rust owns the immutable declarative schema plan and supported structural
  execution; Ruby owns the DSL, arbitrary business rules, macros, options,
  context, and ordinary Ruby method semantics.
- `Dry::Validation::Rust` remains the safe primary namespace. Exact
  compatibility mode remains experimental, opt-in, and isolated from upstream
  gems.
- Unsupported behavior fails loudly instead of silently approximating an
  upstream feature.
- Compatibility claims remain tied to pinned executable evidence, and
  performance claims remain tied to named workloads and reproducible raw data.
- The current Ruby-object engine remains under the GVL and is not described as
  parallel or GVL-free.
- The project remains a feasibility prototype rather than a production-ready
  drop-in replacement.
- GPT-5.6 remains outside the shipped runtime; no OpenAI API dependency was
  added.

## Runtime independence

The validation runtime is deterministic Ruby and Rust and does not require an
OpenAI API key.

The asserted demo and container runtime can run with networking disabled. AI
tools contributed to the development process, not to validation calls.

## Judge paths and current evidence

- [README quick start](../README.md#try-it-with-docker): one-command local
  Docker build and offline demo.
- [Docker image guide](DOCKER.md): image contents, runtime commands, platform
  limits, and GHCR publication status.
- [Benchmark methodology](BENCHMARKING.md): quick checks, full evidence mode,
  measurements, and interpretation limits.
- [Benchmark evidence status](../benchmark/results/build-week-2026/README.md):
  the clean-commit full package has not yet been generated.
- [Verification record](VERIFICATION.md): local toolchain, checks, tests, and CI
  definitions.

## Session and video evidence

- Primary Codex `/feedback` Session ID:
  `<PRIMARY_CODEX_FEEDBACK_SESSION_ID>`
- Public YouTube demo: `<PUBLIC_YOUTUBE_DEMO_URL>`

> **Submission blockers:** replace both placeholders with the real primary
> Codex Session ID and public YouTube URL before submitting. No session ID or
> video URL has been inferred from local files.
