# Milestone C — Dependable ordinary contract rules

## Role of this task

Make ordinary Ruby rule execution predictable after structural validation. Preserve Ruby semantics rather than attempting to translate arbitrary rule blocks into Rust.

## Primary outcome

Common contract rules execute in upstream-compatible order, skip only when their dependencies require it, attach failures to compatible paths, and never leak state across calls.

## Scope

### Included

- single-key rules;
- multi-key rules;
- nested paths;
- dependency-based skipping;
- `value`, `values`, and `key?` behavior already supported;
- key and base failures;
- schema/rule/base error query helpers;
- `rule.each`;
- contract methods called from rules;
- inheritance;
- options;
- per-call context;
- contract-local macros already supported.

### Explicitly excluded

- compiling Ruby rule blocks into Rust;
- parallel rule execution;
- GVL-free ordinary validation;
- translating arbitrary Ruby methods;
- new macro extension architecture;
- full upstream extension ecosystem.

## Execution strategy

Process one rule semantic class at a time:

1. declaration order and simple failures;
2. dependency resolution and skipping;
3. nested/indexed paths and `rule.each`;
4. error query helpers;
5. exceptions and contract methods;
6. options, context, macros, and inheritance;
7. repeated/concurrent call isolation;
8. boundary-crossing performance.

## Step 1 — Build the rule corpus

Add at least 50 focused rule differential cases across successful and failing structural inputs.

Capture where useful:

- rule execution trace;
- accessed keys;
- produced errors;
- final normalized values;
- propagated exception class/message category.

Avoid snapshots of irrelevant internal objects.

## Step 2 — Declaration order

Verify:

- rules run in declaration order where upstream guarantees it;
- multiple failures preserve compatible ordering when claimed;
- base and key failures coexist correctly;
- repeated invocation does not reorder compiled rules.

Do not sort errors or rules merely to make snapshots stable if upstream preserves meaningful order.

## Step 3 — Dependency resolution and skipping

Build explicit cases proving:

- a failed required dependency suppresses its dependent rule;
- a valid dependency allows execution;
- an unrelated schema failure does not suppress the rule;
- multi-key rules respond correctly when only some dependencies fail;
- nested dependency prefixes are handled correctly;
- missing optional values follow upstream semantics.

Implement the smallest dependency model needed for the supported rule forms. Reject unsupported dependency expressions.

## Step 4 — Paths and `rule.each`

Cover:

- nested key failures;
- base failures;
- array index paths;
- `rule.each` over valid members;
- member-level structural failures;
- empty arrays;
- invalid array container;
- adding failures to current item versus explicit paths.

Do not generalize into arbitrary path-expression AST support.

## Step 5 — Error query helpers

Verify the currently supported forms of:

- `schema_error?`;
- `rule_error?`;
- `base_rule_error?`;
- any equivalent existing helper.

Test true and false cases, nested paths, and ordering interactions. Unsupported invocation signatures must raise explicitly.

## Step 6 — Exceptions and Ruby method calls

Prove that:

- an exception raised by user rule code propagates unchanged;
- an exception is not converted into a validation failure;
- contract helper methods can be called normally;
- Ruby visibility and dispatch remain ordinary Ruby behavior;
- Rust panics never cross the boundary.

Do not rescue broad exceptions in the engine merely to normalize behavior.

## Step 7 — Options, context, macros, and inheritance

Cover existing supported behavior for:

- required and optional options;
- per-call context;
- context mutation within one call;
- no context leakage across calls;
- inherited schema and rules;
- contract-local macros;
- macro arguments and failures within the supported form.

Reject unsupported macro registration/global behavior rather than building a registry prematurely.

## Step 8 — State isolation

Stress:

- repeated calls on the same contract instance;
- multiple contract instances;
- nested values and errors;
- context and options;
- threads under the GVL;
- exceptions followed by successful calls.

The goal is absence of leakage, not a claim of GVL-free parallelism.

## Step 9 — Boundary-cost check

When rule execution code changes, run a compact comparison of:

- schema-heavy contract;
- rule-heavy contract;
- mixed contract.

Record whether added Ruby/Rust crossings materially reduce performance. Do not optimize before evidence identifies a boundary problem.

## Acceptance criteria

- At least 50 focused rule differential cases exist.
- Supported rules match upstream execution, skipping, and errors.
- Failed dependencies suppress rules; unrelated failures do not.
- User exceptions propagate unchanged.
- Nested and indexed failure paths are compatible.
- Options, context, macros, and inheritance do not leak state.
- Repeated and threaded calls under the GVL remain isolated.
- Unsupported rule and macro forms fail explicitly.

## Required verification

Run:

- focused rule fixtures;
- full rule differential corpus;
- full Ruby suite;
- Rust tests/lints if native execution changed;
- thread/state stress cases;
- representative mixed benchmarks when boundary behavior changed.

## Stop conditions

Stop and report when:

- support requires compiling arbitrary Ruby code;
- a macro form requires a general extension registry;
- parallelism would require Ruby access without the GVL;
- compatibility depends on undocumented upstream internals that cannot be characterized;
- the task grows beyond one semantic class.

## Exit gate

Milestone C is complete only when ordinary supported contracts behave predictably enough for a realistic application experiment, not merely isolated examples.
