---
name: Safety Review
description: >
  Review a change that touches a meaningful safety surface such as Rust/Ruby
  FFI, unsafe code, concurrency, resource lifetime, untrusted parsing,
  persistence/data loss, authentication/secrets, or panic/exception
  containment. Identify concrete failure risks without expanding into
  unrelated implementation work.
---
# Skill: Safety review

Use this skill after implementation or for an existing diff when the code touches a real safety boundary.

## Review surfaces

### Rust and FFI

Check:

- panic paths reachable from Ruby or user-controlled input;
- `unwrap`, `expect`, indexing, conversion, or assertion paths that can abort unexpectedly;
- `unsafe` blocks and their documented invariants;
- ownership/lifetime of Ruby and native values;
- exception/error conversion across the boundary;
- GVL and reentrancy assumptions;
- shared mutable native state.

### Concurrency and resources

Check:

- synchronization assumptions;
- thread-visible caches/configuration;
- resource cleanup on success and failure;
- leaks, double-free/use-after-free risks, or stale handles;
- cancellation/early-return behavior where applicable.

### Validation input and deserialization

Check:

- malformed or adversarial schemas/rules/values;
- recursive or oversized input;
- invalid encodings/types;
- parser/decoder behavior at unsupported boundaries;
- denial-of-service style allocation or recursion risks when relevant.

### Persistence and security-sensitive behavior

When touched, check:

- destructive writes or data-loss paths;
- authentication/authorization boundaries;
- secret handling and logging;
- temporary files and permissions;
- release/signing credentials.

## Workflow

1. Define the concrete failure or threat model for the changed surface.
2. Inspect only the relevant diff and boundary code.
3. Verify existing regression, malformed-input, fuzz, stress, or integration coverage.
4. Exercise the smallest missing adversarial cases when practical.
5. Confirm failure behavior is explicit and does not silently change public semantics.
6. For compatibility-sensitive failures, verify exception/result behavior against the pinned reference where required.
7. List findings by severity with file/line, consequence, and smallest reasonable fix.

## Rules

- Do not classify ordinary validation failure as a security problem without a real consequence.
- Do not demand speculative hardening unrelated to the diff.
- Do not claim thread, Ractor, panic, or memory safety beyond tested/reasoned scope.
- Do not turn review into unrelated refactoring or feature work.
- If no material safety issue exists, say so and state residual untested risks briefly.

## Delivery

Return material findings by severity. If there are no material findings, report that clearly with residual risk.
