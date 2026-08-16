---
name: Performance Improvement

description: >
  Investigate and improve one measured performance bottleneck.

  Profile before optimizing,
  preserve observable behavior,
  and support all performance claims with
  reproducible benchmarks.

  Do not optimize without evidence.
---

# Skill: Performance improvement

Use this skill for one measured bottleneck.

## Workflow

1. Define a representative workload and correctness oracle.
2. Record a reproducible baseline in an isolated, controlled run.
3. Profile before choosing an optimization.
4. Implement one optimization hypothesis.
5. Re-run correctness checks before timing.
6. Measure affected and unaffected workloads.
7. Keep the change only when value justifies complexity.
8. Update public claims only when evidence supports them. If the optimization
   changes a public Ruby API, update its inline YARD documentation and run
   `bundle exec yard --fail-on-warning`.
9. If Ruby files, benchmarks, tooling, or CI configuration changed, run
   `bundle exec rubocop` before reporting completion; resolve or explicitly
   report any offenses.

## Required reporting

Include environment, commands, workload, before/after values, variability, regressions, and limitations.

## Rules

- Do not benchmark semantically different implementations as equivalents.
- Do not cherry-pick favourable cases.
- Do not create a generic benchmark platform for one experiment.
- Do not combine several optimization categories in one task.
- A failed hypothesis is a valid result and should not trigger speculative redesign.
