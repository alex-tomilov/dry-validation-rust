# Codex roadmap prompts

Repository-wide architecture, correctness, verification, delivery-gate, and
final-report rules live in `AGENTS.md`. Stage prompts contain only the objective,
stage-specific work, scope control, files, and acceptance criteria.

## Compact stage set

| Stage | Outcome |
|---|---|
| `T01` | Modularize Rust and Ruby without behavior changes |
| `T02` | Harden immutable plans and Ruby/Rust boundaries |
| `T03` | Align the deliberately supported compatibility slice |
| `T04` | Add risk-based robustness evidence |
| `T05` | Measure before optimizing |
| `T06` | Evaluate optional batch and streaming APIs |
| `R01` | Streamline CI and developer workflow |
| `R02` | Keep public documentation canonical |
| `R03` | Prove package and release readiness |
| `R04` | Add evidence-backed adoption paths |
| `G00` | Audit prerelease readiness |
| `G01` | Audit evidence and adoption readiness |

The set consolidates the detailed implementation-plan suggestions rather than
copying its sample code. Those samples must be reconciled with current APIs and
repository invariants; unsafe patterns such as silent predicate success,
exception swallowing, numeric narrowing, `eval`, CI self-commits, and long-lived
publication credentials are explicitly rejected.

## Running a stage

Ask Codex to `Implement T02`, `Run R03`, or `Audit G00`. The root `AGENTS.md`
requires a unique prefix match and prevents adjacent stages from being bundled.
If a stage contains several viable slices, Codex completes only the first
coherent pull request unless explicitly asked for the full sequence.

## Why the set is small

- Module/file moves share one behavior-preserving stage.
- Correctness and FFI safeguards share one invariant-driven stage.
- Predicate, DSL, message, and composition work share one differential stage.
- Property, fuzz, GC, concurrency, and coverage evidence share one risk stage.
- Benchmark harnesses and optimizations share one measurement stage.
- CI tools and developer conveniences share one workflow stage.
- Public docs have canonical homes instead of one document per roadmap bullet.
- Packaging, native artifacts, and release automation share one evidence chain.

Do not add a new stage for a lint rule, badge, documentation page, test-count
target, micro-optimization, or one CI command. Track those as a slice of the
owning stage when evidence shows they are needed.

## Test policy

Tests protect behavior, FFI safety, executable configuration security, and
package artifacts. They should not freeze prose, heading order, exact roadmap
counts, file layout, badges, YARD coverage, or shell-command text. Prefer direct
execution, differential fixtures, package inspection, and parser/schema checks.
