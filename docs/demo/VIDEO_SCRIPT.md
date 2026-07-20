# Build Week demo video script

Target edit length: **2:48**. Hard limit: **under 3:00**.

Last timed reading: `<MM:SS on YYYY-MM-DD; replace before submission>`

The timestamp plan leaves 12 seconds below the official limit. Record a real
timed reading before submission and shorten the narration if the measured edit
would reach 2:50. The [official rules](https://openai.devpost.com/rules) and
[FAQ](https://openai.devpost.com/details/faqs), checked July 20, 2026, require a
public YouTube video with a working demo and audio explaining the project,
Codex, and GPT-5.6.

## 0:00–0:15 — Problem and promise

**On screen:** Project title, then the rendered architecture diagram from
`docs/ARCHITECTURE.md`.

**Voiceover:**

Ruby validation keeps domain rules wonderfully expressive, but repeatedly
walking and coercing nested data has a cost. `dry-validation-rust` explores a
hybrid: Rust executes an immutable declarative schema plan, while ordinary Ruby
keeps the public DSL and dynamic business rules.

## 0:15–0:30 — Precompiled execution

**On screen:** Inspect `dry-validation-rust:local`, then start the offline
Docker demo.

**Voiceover:**

I built this verified local image from the submission commit; the public
registry tag is not anonymously accessible. The native extension is already
compiled. The host needs Docker—not Ruby, Rust, Clang, or an OpenAI key—and the
demo runs offline.

## 0:30–1:15 — Cohesive contract demo

**On screen:** Hold on each of the three demo sections and highlight the named
`PASS` lines.

**Voiceover:**

This is one asserted order contract using the safe `Dry::Validation::Rust`
namespace. First, a valid string-key payload is normalized, unknown fields are
filtered, and customer age plus nested quantities are coerced to integers.
Next, one invalid order combines a blank-email structural error, a nested
quantity coercion error, and an underage business-rule failure written in Ruby.
Finally, an age that cannot be coerced produces a schema error, and its
dependent Ruby rule deliberately never runs. These ten PASS lines are executable
assertions; the command exits nonzero if any expectation changes.

## 1:15–1:35 — Benchmark evidence, without an unsupported claim

**On screen:** Show the committed benchmark evidence status, then briefly show
the workload list in `docs/BENCHMARKING.md`.

**Voiceover:**

The harness compares Rust with pinned upstream gems in separate processes across
three workloads and valid, invalid, and mixed inputs. It captures raw samples,
allocations, GC, and Linux peak memory. The clean full package is not ready, so
I am showing no speed claim. This Ruby-object engine remains under the GVL.

## 1:35–2:12 — GPT-5.6, Codex, and human decisions

**On screen:** Contextual shared-chat view, staged roadmap files, a privacy-safe
Codex session view, and the recent commit list.

**Voiceover:**

This feasibility prototype existed before Build Week. During the event, I used
GPT-5.6 through ChatGPT to review architecture and repository maturity, identify
correctness and native-boundary risks, and shape a staged roadmap with tests and
non-goals. Codex implemented accepted stages: verification, regression tests,
packaging, CI, judge demo, Docker, clean-room checks, benchmark tooling, and
documentation. I retained the Ruby-Rust boundary, safe namespace, supported
scope, and evidence claims. These tools accelerated development; the shipped
runtime is deterministic Ruby and Rust with no AI or API dependency.

## 2:12–2:38 — Engineering maturity and evidence

**On screen:** `AGENTS.md`, the delivery-gate skill, `script/verify`, workflow
files, and compatibility/support documentation.

**Voiceover:**

The repository turns those decisions into guardrails. Unsupported behavior
fails loudly; Rust panics cannot cross the Ruby boundary; compatibility and
performance claims require executable evidence. A mandatory delivery review
drives focused fixes. The canonical gate compiles Ruby and Rust, runs both test
suites, checks Clippy and formatting, and audits an isolated source-gem install.
This remains a scoped feasibility prototype, not a drop-in replacement.

## 2:38–2:48 — Impact and close

**On screen:** End card with repository URL and the two-command Docker fallback.

**Voiceover:**

This explores native validation without rewriting Ruby domain rules. The
repository, Docker fallback, and evidence are linked on screen.

## Recording truth gate

- Do not replace the local Docker fallback with GHCR until an anonymous pull
  and immutable digest have passed.
- Do not add a performance figure until the committed clean full-run package
  exists and the narration names its exact workload and environment.
- Do not show a GPT-5.6 model label unless it is visible in authentic evidence.
- Replace the timed-reading field only after an actual spoken rehearsal.
