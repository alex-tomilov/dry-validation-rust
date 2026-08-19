# Rust supply-chain audit guide

`cargo vet --locked` is a required check in the security workflow. Its
repository-managed records are in `supply-chain/`; `imports.lock` pins the
Mozilla audit set so CI does not fetch or silently change its trust inputs.

## Attack surface

The native extension processes untrusted validation plans and values. Review
changes around these areas especially carefully:

- `serde_json` parsing, including deeply nested or unexpectedly shaped JSON;
- bindgen and its build-time `libclang` dependency;
- the Magnus and rb-sys Ruby bridge, including all `unsafe` code and Ruby
  object lifetime or exception boundaries.

## Dependency audit policy

Lockfile and `supply-chain/` changes are reviewed together. A new third-party
crate must have a `safe-to-run` or `safe-to-deploy` audit path from a reviewed
local audit or a pinned trusted import before it can merge. Do not add an
exemption for a new dependency as a substitute for that review.

Existing exemptions are the audited baseline recorded when cargo-vet was
introduced. Reduce them when a suitable trusted audit becomes available.

## CVE response

Treat a new advisory as a security issue: identify affected supported builds,
assess exploitability at the attack surfaces above, then update, remove, or
replace the dependency. If immediate remediation is impossible, record a
dated exception with mitigation and an owner in
`docs/DEPENDENCY_SECURITY.md`; remove it once resolved.
