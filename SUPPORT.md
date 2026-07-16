# Support

`dry-validation-rust` is an alpha, single-maintainer project. Support is
best-effort and no response-time or resolution SLA is offered.

Before opening an issue, check the
[support matrix](docs/SUPPORT_MATRIX.md),
[compatibility matrix](docs/COMPATIBILITY.md), and existing issues.

## Bugs

Use the bug report form for behavior that appears incorrect within the
documented supported surface. Include a minimal contract and input, exact
versions, loading mode, build type, platform, expected and actual output, and a
full backtrace where applicable.

Native crashes, installation failures, and unexpected Ruby exceptions are
bugs even when they occur around unsupported input. Unsupported DSL behavior
should fail loudly rather than silently succeed.

## Compatibility mismatches

Use the compatibility mismatch form when the Rust implementation and pinned
upstream `dry-validation`/`dry-schema` releases produce different values,
errors, metadata, exceptions, or loading behavior for a documented compatible
feature. Run the two implementations in separate processes and include both
outputs and exact upstream versions.

Not every upstream feature is in scope. Check `docs/COMPATIBILITY.md` before
filing.

## Feature requests

Use the feature request form to describe the user problem, desired behavior,
alternatives, and compatibility implications. New DSL surface requires
explicit design and tests; it will not be added as a side effect of another
change.

## Usage questions

Use GitHub Discussions when that repository feature is available. If it is not
available, consult the README, examples, compatibility matrix, and existing
issues. Open an issue only when the question identifies a likely documentation
gap, bug, or focused feature request.

General application debugging, contract design consulting, and upstream
`dry-validation` support are outside this project's support scope.

## Performance reports

Use the performance report form. Reports must include a runnable reproducer,
warmup, iterations, hardware/software details, allocations or RSS where
relevant, and raw results from multiple runs. A single benchmark number without
semantic equivalence evidence is not actionable.

## Security reports

Do not use public issues or discussions for suspected vulnerabilities. Follow
[SECURITY.md](SECURITY.md) and use GitHub private vulnerability reporting.

## Triage expectations

The maintainer targets initial triage of complete bug and compatibility reports
within two weeks when capacity permits. Feature requests, performance
investigations, and usage questions may take longer or receive no immediate
response. Incomplete or out-of-scope reports may be closed with a request for
the missing information.
