# Skeptical maintainer review checklist

Review the complete branch for:

1. semantic changes outside the requested stage;
2. mutable state shared between schemas, contracts, parents, children, or imports;
3. swallowed or reclassified Ruby exceptions;
4. Rust panic, `unwrap`, `expect`, `.ok()`, and default-fallback paths;
5. invalid native-plan states that remain representable;
6. differences from pinned upstream behavior;
7. missing negative, malformed-input, inheritance, and boundary tests;
8. Ruby object lifetime, rooting, marking, and `GC.compact` risks;
9. concurrency, context isolation, and thread-safety risks;
10. misleading documentation, support, compatibility, or performance claims;
11. source/native package and clean-install regressions;
12. CI permission or supply-chain regressions;
13. accidental tag, release, publication, credential, or remote-setting actions.

For each finding report:

- severity;
- exact file and line/range;
- user or maintainer impact;
- reproduction or test idea;
- smallest correction;
- merge-blocking status.

Also list important reviewed areas with no finding.
