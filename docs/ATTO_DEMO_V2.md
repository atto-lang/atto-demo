# AttoLang demo V2: executable conformance plan

**Status:** design and source-only inventory, **not** a claim of guest execution or AOT/backend parity.

## Why the new catalog exists

The repository currently contains historical runnable `.ores` examples, source-revision-specific feature/keyword examples, negative cases, and one quarantined experimental fixture. Each must be classified before a demo can be used as evidence. `conformance/coverage.tsv` records **all tracked** `.atto` and `.ores` fixture paths and their intended test mode. The catalog deliberately uses `not-attested` for every row: evidence is tied to a specific executed job, compiler tree, backend, and oracle, not to a static spreadsheet cell.

The source-only verifier rejects omitted files, duplicate fixture IDs, `.atto`/`.ores` stem collisions, symlinked sources, bad paths, incorrect track/mode associations, and mismatch with the feature/keyword source-pinned manifests. Run:

```sh
bash ci/test-semantic-coverage.sh
bash ci/check-semantic-coverage.sh
```

Those scripts do **not** invoke a compiler or establish correctness of any language fixture.

## Phased execution roadmap

| Priority | Deliverable | Hard gate |
| --- | --- | --- |
| P0 | Restore runner admission and validate existing main and open PRs | Exact PR head SHA/tree, nonzero executed steps, logs and independent review |
| P0 | Reconcile runner source identity hardening (PR #32) with native execution work (PR #21 / issue #22) | Clean compiler checkout at exact `SOURCE_REF`; no source-override or dirty-worktree bypass |
| P0 | Add a canonical `.atto` lane alongside legacy fixtures, do not auto-convert existing `.ores` | Compiler-accepted syntax, positive and negative tests, real guest output/diagnostic oracles |
| P1 | Add ownership fixtures: moved use, aliased mutable borrow, post-lifetime borrow, shared reader/writer exclusion, stale actor generation | Fail closed at compile time or deterministic runtime boundary, as appropriate |
| P1 | Add classes/generics/closures/tuple fixtures: receiver resolution across files, specialized instantiation, constrained traits, tuple arity, capture lifetime and non-Sendable closures | Both successful execution and exact negative diagnostics |
| P1 | Exercise actors, supervisors, cancellation, backpressure, and per-actor heap/stack isolation | No process-wide failure on actor fault; independent observed survivors; bounded resources |
| P1 | Record Java/GraalVM, LLVM, .NET NativeAOT, Wasm and Forge independently | One verified exact-tree compiler/backend build and guest run per result; no host-only parity claim |
| P2 | Build user-facing CLI, API, actor service, and browser demos on top of the same library of fixtures | Reproducible instructions and artifacts, deterministic observable behavior |

## Syntax migration hazards

Do not perform blind rewrites: pinned legacy cases include `==`, `&&`, `||`, `^^`, `<T>`, `&mut`, old constructor and class forms. Planned AttoLang contracts use `eq`/`neq` (or `!eq`), explicit `rt borrow/share/take/copy`, `Tuple[T, U]` as a type and `~tuple(a, b)` as a value, top-level `define`, and fully AOT-capable semantics. These are **migration targets**; this PR does not claim the currently pinned compiler accepts them.

Default `run-all.sh` must remain reproducible against its historical pinned compiler until exact-head replacement tests prove the new lane works. Keep experimental/unmerged grammar out of that stable gate.

## Evidence contract for any future 'verified' label

Record the demo head/tree, compiler source head/tree and executable digest, exact backend/target, command and expected oracle, stdout/stderr/exit code, run URL/attempt and executed steps, plus an independent reviewer. Zero-step (`steps=[]`), skipped, or host-only fake-Maven jobs mean `NOT_EXECUTED` for guest semantics. Never export private compiler source across organizations without explicit approved destination/policy and exact tree/blob identity.

## Current observed CI caveat

Recent Demo runner contracts jobs on main and the November 8 PR head failed with zero steps (runner admission); this index cannot repair Actions runner assignment or certify native execution. See issue #22 and governance incident #31.
