# ADR 002: Retain JSON for schema-plan transport

## Status

Accepted on 2026-08-13.

## Context

The Ruby schema DSL compiles an immutable plan once, then Rust owns the plan
for every validation call. JSON is easy to inspect but has a larger wire
representation than MessagePack. A direct Magnus walker removes the encoded
wire representation but makes plan construction depend on Ruby object APIs.

The alternatives were evaluated in a local prototype that was discarded after
measurement. The production implementation remains JSON-only; no transport
setting, additional constructor, or MessagePack dependency is shipped.

The benchmark measures schema definition and native plan construction, not
validation calls. It ran three times on CRuby 3.3.7 / x86_64 Linux. Two runs
used 1,000 measured schema compilations and 100 warmups; one used 3,000 and 300. Each transport
cell reports **schemas compiled per second**: the median first, followed by the minimum–maximum
across the three normalized-rate runs.
`Fields` is the number of top-level schema fields, not input payload fields.

| Fields |       JSON (schemas/s) | MessagePack (schemas/s) | Direct walking (schemas/s) |
| ------ | ---------------------: | ----------------------: | -------------------------: |
| 5      | 20,699 (19,041–21,154) |  21,117 (19,685–22,606) |     19,124 (18,703–21,081) |
| 50     |    2,149 (1,958–2,229) |     1,790 (1,541–1,895) |        1,965 (1,818–2,085) |
| 200    |          390 (380–392) |           353 (349–369) |              341 (311–358) |

| Comparison metric                                      |     JSON |                        MessagePack |               Direct walking |
| ------------------------------------------------------ | -------: | ---------------------------------: | ---------------------------: |
| Encoded plan size — 5 fields (bytes)                   |      839 |                                572 |                            0 |
| Encoded plan size — 50 fields (bytes)                  |    7,809 |                              5,294 |                            0 |
| Encoded plan size — 200 fields (bytes)                 |   31,159 |                             21,144 |                            0 |
| Ruby allocations — 200 fields (objects/schema, median) |    6,629 |                              6,630 |                        8,633 |
| Definition-time outcome                                | Baseline | No reliable throughput improvement | Slower for 50 and 200 fields |

MessagePack reduced encoded plan size by about 32%. Direct walking removes the
encoded input, but its higher Ruby allocation count and slower representative
results do not justify its added FFI coupling.

## Decision

Keep JSON as the production transport.

The JSON path has the clearest debuggability boundary, preserves a Rust-owned
plan without retaining Ruby values, and is fastest in the representative
medium and large cases. The modest MessagePack size reduction matters only at
definition time and does not justify an additional Ruby gem and Rust decoding
path. Direct walking has materially tighter Magnus coupling, more boundary
code, and worse measured allocation behavior.

## Consequences

- Production behavior and the public schema API remain unchanged.
- The alternatives are recorded as evidence only, not as supported
  configuration or compatibility promises.
- A future reconsideration needs multi-host results and a demonstrated
  definition-time bottleneck; validation-call throughput is out of scope.

## Alternatives considered

- **MessagePack:** smaller plans, but not a consistent throughput win.
- **Direct Magnus walking:** no serialized bytes, but more FFI coupling and
  Ruby allocation than JSON.

## Rollback plan

The prototype code and dependencies are intentionally absent from the
production branch. Reverting this ADR and `docs/PROGRESS.md` records is
sufficient to remove the evaluation evidence. A future re-evaluation should
use a fresh isolated spike branch, then publish its raw results and decision
in a follow-up ADR update.
