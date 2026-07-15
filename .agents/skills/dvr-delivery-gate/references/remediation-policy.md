# Focused remediation policy

- Fix only blocker and high-severity findings discovered by the delivery review.
- Preserve the accepted design and original task scope.
- Add a regression test for each correction.
- Do not silence warnings or remove tests.
- Do not convert an implementation bug into an intentional compatibility difference without evidence.
- Do not weaken canonicalization to hide an upstream mismatch.
- Do not add unrelated refactoring.
- Run the failed/focused check first, then the nearest suite, then canonical full verification.
- Perform one follow-up skeptical review.
- Report remaining medium/low findings as follow-up issues.
