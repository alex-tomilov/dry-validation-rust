# Milestone G — Stable supported subset

## Role of this task

Prepare a narrow, honest 1.0 contract. This is not a feature-completion milestone and not a claim of complete `dry-validation` parity.

## Primary outcome

The gem has a stable documented namespace, compatibility target, verified platforms, reproducible evidence, and no known silent mismatches inside its supported subset.

## Explicitly excluded

- implementing every deferred feature before 1.0;
- claiming drop-in parity;
- expanding the platform matrix during release preparation;
- building elaborate governance systems;
- publishing/tagging/releasing without explicit user instruction.

## Step 1 — Freeze the actual supported surface

Derive the stable surface from executable evidence, not aspirations.

Inventory:

- public namespace/classes/methods actually used by examples and tests;
- supported DSL forms;
- supported result/error APIs;
- supported Ruby/platform matrix;
- exact upstream compatibility target;
- explicit unsupported forms.

Do not freeze internal helpers or undocumented accidental APIs.

## Step 2 — Resolve silent mismatches

Search:

- differential failures;
- skipped/expected-failure fixtures;
- open compatibility issues;
- migration experiment notes;
- error normalization differences;
- platform-specific failures.

For each issue:

- fix it within the supported subset;
- narrow support and fail explicitly; or
- block 1.0 if the mismatch is critical and silent.

A known silent semantic mismatch cannot be deferred behind optimistic wording.

## Step 3 — Decide exact compatibility mode

Choose one outcome based on evidence:

1. keep exact mode experimental and opt-in;
2. move exact mode to a separate compatibility package;
3. remove exact mode from the stable product.

Evaluate:

- constant/load-path conflicts;
- coexistence with upstream;
- maintenance burden;
- user migration value;
- risk of users assuming full parity.

Do not make exact mode the default simply because it is technically possible.

## Step 4 — Realistic migration proof

Complete at least one realistic application or representative sample migration.

Document concisely:

- original contract patterns;
- supported unchanged syntax;
- required changes;
- unsupported blockers;
- compatibility results;
- performance results;
- rollback/coexistence strategy.

Use an existing documentation location or one focused migration guide only if genuinely necessary. Do not create a collection of case-study documents.

## Step 5 — Reproducible benchmark proof

Re-run the representative Milestone D suite on the release candidate.

Requirements:

- all benchmark contracts pass differential checks;
- environment and commands are recorded;
- regressions from previous baselines are explained;
- README claims are narrow and quantified;
- rule-heavy or unfavourable cases are not hidden.

## Step 6 — Public policy minimum

Document only policies needed by actual users:

- versioning expectations;
- deprecation approach after 1.0;
- supported Ruby/platform matrix;
- security reporting route;
- compatibility target and support boundary.

Do not build a pre-1.0 deprecation framework retroactively. Do not require exhaustive `@since` annotations or API snapshot tests unless they protect a deliberately selected stable API and remain small.

## Step 7 — Release-candidate verification

From a clean checkout or CI artifact:

- run canonical verification;
- build the gem;
- install in a clean consumer;
- run differential corpus;
- run representative benchmarks;
- verify advertised platforms;
- inspect package contents;
- verify licenses/notices;
- verify native load failure messages.

Do not publish, tag, or create a release as part of this instruction.

## Step 8 — 1.0 go/no-go review

Answer explicitly:

1. Is every supported behavior backed by executable evidence?
2. Are there any known silent mismatches?
3. Can users distinguish unsupported syntax immediately?
4. Are advertised platforms verified?
5. Is installation reproducible?
6. Are performance claims representative and reproducible?
7. Is the stable namespace intentionally selected?
8. Is exact mode's status unambiguous?
9. Has at least one realistic migration been attempted?
10. Are critical correctness/security issues resolved?

Any “no” must either block 1.0 or narrow the supported claim before release.

## Acceptance criteria

- No unresolved critical correctness issue exists.
- No known silent mismatch exists inside the supported subset.
- Unsupported forms fail explicitly.
- Primary namespace and compatibility target are stable and documented.
- Every advertised platform is verified.
- A realistic migration has been documented.
- Benchmark evidence is reproducible and honestly scoped.
- Package/install smoke tests pass from the built gem.
- Exact compatibility mode has a deliberate documented status.
- Documentation contains no unsupported ambitious promises.

## Delivery response

Provide a concise release-readiness report containing:

- go/no-go decision;
- blockers, if any;
- final supported subset;
- exact-mode decision;
- verification evidence;
- claims that were narrowed or removed;
- actions intentionally deferred after 1.0.

Do not generate a large certification dossier.

## Exit gate

Milestone G is complete only when the code, executable evidence, packaging, and wording describe the same narrow product. A stable release is a supported subset, not the completion of the entire future backlog.
