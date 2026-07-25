# Milestone B — Dependable common schema path

## Role of this task

Make the common schema-dominant path compatible and dependable. Work through the schema corpus in small compatibility classes rather than implementing the entire milestone in one diff.

## Primary outcome

Supported `params`, `json`, and plain `schema` contracts produce compatible normalized values and structural errors for realistic nested request payloads.

## Scope

### Included

- required and optional keys;
- `value`, `filled`, and `maybe`;
- nested hashes;
- arrays of primitives and hashes;
- already supported scalar coercions;
- already supported numeric and size predicates;
- undeclared-key filtering in currently supported modes;
- deterministic structural errors;
- schema reuse/inheritance already present.

### Explicitly excluded

- full `dry-types` support;
- arbitrary predicate AST composition;
- schema processor hooks;
- schema merge/AST APIs;
- message backend parity;
- unexpected-key validation unless selected later as a migration slice;
- new public extension systems.

## Execution strategy

Do not implement Milestone B in one task. Process one compatibility class at a time in this recommended order:

1. presence and nil/empty semantics;
2. keys and mode semantics;
3. scalar coercion boundaries;
4. nested hashes;
5. arrays and indexed paths;
6. predicates and metadata;
7. reuse, inheritance, frozen inputs, and duplicate declarations;
8. malformed-input panic resistance.

Each class should be independently reviewable.

## Step 1 — Expand schema fixtures

Grow the differential corpus from Milestone A to at least 75 total schema-focused cases.

Every fixture must identify:

- schema mode;
- input;
- expected normalized output and Ruby classes;
- expected error paths and metadata;
- whether behavior is supported or must raise explicitly.

Do not add many near-duplicate cases without a semantic boundary being tested.

## Step 2 — Presence, nil, and empty values

Capture and implement behavior for:

- missing required key;
- missing optional key;
- present `nil` under `value`, `filled`, and `maybe`;
- empty strings in Params mode;
- empty arrays/hashes where relevant;
- coercion before or after emptiness checks as upstream defines it.

Acceptance for this slice:

- no supported mismatch remains for these cases;
- unsupported combinations raise explicitly;
- error paths and output hashes match upstream.

## Step 3 — Key and schema mode behavior

Cover:

- string input keys;
- symbol input keys;
- mixed nested keys;
- Params mode key coercion;
- JSON/plain schema behavior;
- undeclared-key filtering;
- duplicate declarations;
- unsupported modes/configuration.

Do not implement unexpected-key rejection unless it is explicitly selected as a Milestone E feature.

## Step 4 — Scalar coercion boundaries

For each currently supported scalar type, cover valid values, invalid values, boundary values, and output Ruby classes.

Pay special attention to:

- integers, signs, whitespace, and overflow;
- floats and non-finite values if applicable;
- booleans and accepted textual forms;
- dates/times/datetimes;
- decimals;
- strings and symbols;
- already supported URI/UUID-like types, if present.

Do not widen accepted syntax merely because Rust parsing makes it easy.

When Rust numeric ranges differ from Ruby's, either implement compatible handling or reject the out-of-range form explicitly. Never silently wrap, clamp, or default.

## Step 5 — Nested hashes

Add cases for:

- multiple nesting levels;
- missing nested parent;
- present invalid parent type;
- nested optional keys;
- nested coercion failures;
- errors at parent and child paths;
- undeclared nested keys;
- frozen input structures.

Ensure input objects are not mutated unless upstream does so.

## Step 6 — Arrays and indexed paths

Add cases for:

- arrays of primitives;
- arrays of hashes;
- empty arrays;
- invalid array container type;
- invalid individual members;
- multiple member failures;
- nested arrays only if already claimed supported;
- error paths containing stable indices.

Avoid converting the whole array into an error when upstream reports member-level failures.

## Step 7 — Built-in predicates

For each currently supported predicate:

- test passing, failing, and wrong-type values;
- compare error path, text/code/metadata at the level claimed supported;
- ensure predicate execution does not panic on malformed values;
- reject unknown predicates explicitly.

Do not add predicates merely to increase a support count. New predicates belong in Milestone E unless required to close an existing claim mismatch.

## Step 8 — Reuse and declaration behavior

Verify:

- schema/contract inheritance already supported;
- repeated contract calls;
- immutable compiled plan behavior;
- duplicate schema declarations;
- frozen input hashes/arrays;
- no state leakage between calls.

Do not create a general cache subsystem unless profiling and existing architecture require it.

## Step 9 — Property/fuzz safety

Add a small, bounded property or fuzz layer for supported schema shapes and malformed Ruby values.

Goals:

- no Rust panic;
- no UB symptoms;
- no uncontrolled recursion;
- no silent success for unknown plan nodes;
- deterministic explicit errors for unsupported plans.

Keep fuzz infrastructure minimal. Do not turn it into a separate framework or CI matrix unless it proves useful and maintainable.

## Acceptance criteria

- At least 75 focused schema cases exist in the differential corpus.
- All declared supported cases match values, Ruby classes, success state, and error paths.
- Deep nested hash and array cases are covered.
- Numeric and temporal coercion boundaries are explicit.
- No known supported mismatch remains undocumented.
- Unknown types, predicates, modes, hooks, and AST forms raise deterministically.
- Property/fuzz checks expose no Rust panic for supported input surfaces.
- Representative schema benchmarks do not materially regress from Milestone A without an explained correctness reason.

## Required verification

Run:

- focused differential cases for the edited compatibility class;
- full differential schema corpus;
- Ruby suite;
- Rust tests, fmt, and clippy;
- existing representative schema benchmarks when execution code changed.

## Stop conditions

Stop and report instead of expanding scope when:

- a coercion requires general `dry-types` algebra;
- error parity requires implementing a complete message backend;
- a mode requires processor hooks or AST execution;
- compatibility cannot be achieved without unsafe Ruby access outside the GVL;
- the slice exceeds the change-size limits.

## Exit gate

Milestone B is complete only when the documented common schema subset has no known silent mismatch and realistic nested payloads can be migrated experimentally.
