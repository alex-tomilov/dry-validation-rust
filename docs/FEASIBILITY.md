# Feasibility study

## Executive conclusion

Yes: the declarative execution logic behind the common `dry-validation` path
can be implemented in Rust and exposed as another Ruby gem while preserving
most application-facing syntax.

No: a complete Rust-only rewrite cannot transparently preserve every behavior,
because contracts intentionally contain arbitrary Ruby code, Ruby objects,
custom dry-types, message backends, extension hooks, and dependency-injected
services. The sound target is a native schema engine with a Ruby compatibility
shell.

This prototype demonstrates that boundary with a compiled extension and
executable API, not just a design sketch.

## Material inspected

The study used public repositories directly without a GitHub connector, fork,
pull request, or other public mutation.

| Project | Inspected revision | Version in source | Role |
| --- | --- | --- | --- |
| dry-validation | `e7dff1eddfa98a2bab3acd895535c29b1e0b294c` (2026-05-10) | 1.11.1 | Contract orchestration, rules, messages, result |
| dry-schema | `9e17659aa2fe6629f770b2d02703663f2330ea76` (2026-05-10) | 1.16.0 | Input processing, types, predicates, errors |
| dry-logic | `3326aefba07b6faa1535d823a22ef83dca92df85` (2026-05-10) | 1.6.0 | Predicate AST and operations |
| dry-types | `f47a790d6319759237a59247f74e1072ed5098d1` (2026-05-04) | 1.9.1 | Types, coercions, constraints |
| Magnus | `4e46772050e47cd6cd988fa935263cc5c583e388` plus released 0.8.2 | 0.8.2 used | High-level Rust/CRuby binding |
| rb-sys | `94b205cd8425ebdc09d5682f14503b3f3756fa9b` | 0.9.128 used | CRuby API and extension build |

At the time of inspection, the latest published `dry-validation` version was
1.11.1 (2025-01-21), while current main had already raised its Ruby requirement
to 3.3. `dry-schema` 1.16.0 was released on 2026-03-03 and current main also
required Ruby 3.3.

Primary references:

- https://github.com/dry-rb/dry-validation
- https://github.com/dry-rb/dry-schema
- https://hanakai.org/learn/dry/dry-validation/v1.11
- https://github.com/matsadler/magnus
- https://github.com/oxidize-rb/rb-sys

## What upstream actually does

`dry-validation` itself is relatively small. Its essential call sequence is:

1. assert that input is a Hash;
2. create the mutable per-call context;
3. call a `dry-schema` processor;
4. create a result from processed values and schema errors;
5. run declared rules in order;
6. skip a rule when any declared dependency failed schema processing;
7. resolve rule failures through the message backend;
8. freeze and return the result.

The larger surface lives under `dry-schema`. Its processor has four core
stages:

1. key coercion and selection;
2. optional pre-coercion filtering;
3. value coercion through dry-types;
4. application of a dry-logic predicate tree and message compilation.

This dependency map matters. Rewriting only the thin `Contract#call` loop would
probably make the system slower after native-boundary overhead. The schema
processor, type/coercion work, and predicate traversal are the meaningful
native target.

## Chosen boundary

### Compiled into Rust

- schema mode and field topology;
- required/optional presence;
- primitive/member/nested type descriptions;
- nullable and filled semantics;
- key lookup and Params/JSON normalization;
- Params scalar coercion;
- recursive hash and array processing;
- output filtering;
- native numeric and size predicates;
- structural error paths and codes.

The Ruby DSL emits JSON only once, when the contract class is defined. Rust
deserializes it into an immutable typed plan wrapped as a Ruby typed-data
object. Individual calls do not parse the DSL or plan again.

### Kept in Ruby

- class definition and inheritance;
- arbitrary `rule` blocks;
- injected repository/client/service objects;
- global and class macros;
- rule context;
- Ruby Regexp matching;
- collection inclusion and Ruby `eql?` semantics;
- result/message compatibility objects.

These are not accidental leftovers. Ruby is the correct semantic owner for
behavior that can invoke arbitrary Ruby methods.

## Alternatives considered

### 1. Full Rust rewrite with a new Rust-only rule language

This could release the GVL and maximize native execution, but would break the
most valuable compatibility property. Existing rule blocks and injected Ruby
objects would need rewriting. Rejected as the primary migration path.

### 2. Rust rewrite of only `Contract#call`

The loop is small and mostly dispatches Ruby objects. Native crossings would
dominate. Rejected because it targets the wrong hot path.

### 3. Keep upstream dry-schema and move only rules to Rust

Rules are arbitrary Ruby and often perform I/O, so they are the least
mechanically translatable part. Rejected.

### 4. Compile declarative schema, retain Ruby rules

This preserves familiar contracts and moves repeated structural work to Rust.
Chosen and implemented.

## Performance expectations

Rust is not automatically faster at a Ruby boundary.

Likely wins:

- wide or deeply nested payloads;
- large arrays of homogeneous members;
- repeated calls through a reused contract;
- coercion/type-heavy schemas;
- fewer temporary Ruby executor/AST objects per call.

Likely neutral or negative cases:

- one- or two-field schemas;
- contracts dominated by Ruby rule blocks;
- rules dominated by database/network calls;
- workloads where message localization is the main cost;
- one-shot schemas where compilation cannot amortize.

The current engine still manipulates Ruby objects and therefore retains the
GVL. It is thread-safe for concurrent Ruby calls, but it does not execute Ruby
object access in parallel. A future batch API could copy supported input into
Rust-owned values, release the GVL, validate, then materialize results. That
must be benchmarked against copy/serialization cost.

No performance claim should be published until a parity corpus and comparative
benchmarks against upstream are available.

## Feasibility by feature family

| Family | Feasibility | Reason |
| --- | --- | --- |
| Key coercion/filtering | High | Deterministic tree processing |
| Built-in scalar coercion | High | Clear conversion table |
| Nested hashes/arrays | High | Natural typed Rust plan |
| Built-in predicates | High | Deterministic operations |
| Error paths/codes | High | Native structured accumulation |
| Ruby rule blocks | Hybrid only | Arbitrary Ruby |
| Injected dependencies | Ruby | Arbitrary object protocols and I/O |
| Custom dry-types | Medium/low | Constructor may be arbitrary Ruby |
| Custom predicates | Medium | Callback preserves behavior but not native speed |
| YAML messages | Medium | Reimplementable with parity work |
| I18n backend | Medium | Best delegated to Ruby initially |
| Extensions/monads/hints | Medium | Separate compatibility adapters |
| Processor before/after hooks | Ruby callback | Arbitrary transforms |
| JRuby/TruffleRuby | Low for this extension | Magnus/rb-sys targets CRuby |

## Legal and project identity

The inspected dry-rb projects use the MIT license, which permits use,
modification, distribution, sublicensing, and sale subject to retaining the
copyright/license notice in copied or substantial source portions.

This prototype is an independent implementation of a public interface and does
not copy upstream implementation source. It uses:

- a distinct gem name;
- an explicit non-affiliation notice;
- its own MIT license;
- upstream references and notices in `NOTICE.md`.

If future work copies upstream tests or implementation, preserve their license
headers/notices and track provenance per file. Before a public release, also
ask the maintainers whether they have naming or ecosystem-integration
preferences. That is a relationship and trademark courtesy, not a condition
imposed by the MIT license.

## Final determination

The project is technically viable. The prototype proves:

- a real CRuby/Rust extension can own an immutable schema plan;
- the normal contract syntax can be kept exactly in replacement mode;
- arbitrary Ruby rules can operate on natively coerced output;
- nested error paths and rule-skipping semantics can be retained;
- a safe namespace can coexist for migration tests.

Production viability remains unproven until the compatibility corpus,
message/configuration surfaces, packaging matrix, fuzzing, and comparative
benchmarks described in `ARCHITECTURE.md` are completed.
