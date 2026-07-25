# Milestone D — Prove or disprove the performance case

## Role of this task

Measure where the hybrid engine provides meaningful value. This milestone is a decision exercise, not a marketing exercise and not permission to optimize everything.

## Primary outcome

A reproducible benchmark report identifies favourable, neutral, and unfavourable workloads and supports a decision about which architecture paths deserve further investment.

## Explicitly excluded

- new compatibility features;
- benchmark-only semantic shortcuts;
- cherry-picked README claims;
- a generic benchmarking platform;
- raw result dumps committed indefinitely;
- GVL release experiments before profiling justifies them.

## Step 1 — Freeze comparison inputs

Pin:

- upstream gem version;
- Ruby version(s) used for the primary comparison;
- Rust toolchain or lockfile state;
- benchmark payload definitions;
- contract definitions;
- process environment variables that materially affect results.

Every benchmark contract must already pass differential compatibility checks.

## Step 2 — Define the compact workload matrix

Implement a small suite containing at least:

1. flat Params payload;
2. nested hashes;
3. array of nested hashes;
4. mostly valid payloads;
5. mostly invalid payloads;
6. schema-heavy contract;
7. rule-heavy contract;
8. mixed contract;
9. repeated calls after plan compilation;
10. small and medium batches.

Use realistic payload sizes. Do not create dozens of artificial microcases unless profiling a specific bottleneck.

## Step 3 — Measurement discipline

For each engine and workload:

- run in a separate process;
- warm up consistently;
- use multiple measured iterations;
- report central tendency and variability;
- record validations/second and latency;
- record Ruby allocations where reliable;
- record peak RSS with a reproducible method;
- separate compilation/setup time from repeated-call time;
- avoid running noisy tasks concurrently.

Keep benchmark scripts in the repository. Keep raw local output outside unless a concise machine-readable baseline is intentionally required.

## Step 4 — Correctness gate before timing

Before timing a workload:

- execute both engines with the same inputs;
- assert compatible values, classes, success state, and errors;
- abort the benchmark case on mismatch;
- never time a semantically different shortcut as a valid comparison.

## Step 5 — Baseline report

Produce one concise report in an existing benchmark document or README benchmark section. It must include:

- environment;
- commands;
- workload descriptions;
- summarized results;
- favourable cases;
- neutral cases;
- regressions;
- limitations;
- exact scope of any public claim.

Do not create several reports for the same run.

## Step 6 — Profile before optimizing

Select only the highest-value observed bottleneck. Gather evidence about time or allocations spent in:

- schema plan compilation;
- Ruby/Rust FFI conversion;
- traversal/coercion;
- error creation;
- Ruby rule callbacks;
- normalized Ruby object construction.

Do not infer the bottleneck solely from intuition.

## Step 7 — One optimization experiment

Implement at most one independently useful optimization per task.

Candidate categories only after evidence:

- reduce Ruby object churn;
- cache safe identifiers;
- reduce intermediate error allocations;
- avoid redundant plan conversion;
- improve repeated-call plan reuse.

For the selected optimization:

- preserve differential compatibility;
- add a focused regression test if behavior could change;
- compare before/after on affected and unaffected workloads;
- revert or avoid the change if gains are not meaningful or complexity is disproportionate.

## Step 8 — Batch/GVL experiment, only when justified

A GVL-releasing experiment is allowed only if profiling shows Ruby-object interaction is not required during the unlocked section.

Requirements:

- convert input to Rust-owned data while holding the GVL;
- release the GVL only for pure Rust computation;
- reacquire it before creating or calling Ruby objects;
- prove panic containment and cancellation/exception behavior;
- keep the experiment private or explicitly experimental;
- do not stabilize a public API in the same task.

## Decision gate

Use the roadmap heuristics as a decision aid:

- approximately 2× throughput in representative schema-dominant workloads; or
- approximately 30% fewer Ruby allocations plus material throughput gain;
- no severe small-payload latency regression;
- no semantic mismatch.

These are not promises. Report the actual evidence even when the gate fails.

## Acceptance criteria

- Benchmark commands are reproducible.
- Every timed contract passes differential checks first.
- Separate process execution is used.
- Results include favourable, neutral, and unfavourable workloads.
- Compilation/setup and repeated execution are distinguished.
- Public documentation claims are no broader than measured evidence.
- At most one optimization category is implemented per task.
- A failed performance hypothesis is documented honestly rather than hidden.

## Required verification

Run:

- full differential corpus for benchmark contracts;
- benchmark suite multiple times in a controlled environment;
- full test/lint suite after optimization;
- before/after allocation and throughput checks for affected workloads.

## Exit gate

Milestone D is complete when the project has an evidence-backed answer to: “Where does Rust materially help this gem?” The answer may legitimately be narrower than originally hoped.
