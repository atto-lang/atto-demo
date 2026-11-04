# Demo / upstream source compatibility — 2026-10-29

**Repository:** `ores-truffle-oreslang/oreslang-demo`. This is a source-tip audit, not an executed guest test result.

## Default-branch inventory

Stable Java/Graal examples exist; SOURCE_REF pins 60e698dea4aeb64b394157b9c173d1ddc69b7e9f. Experimental feature branches must not replace this pin without execution evidence.

## Upstream source rules

- Java reference source `main` inspected at commit `9f4f4a3b75dd4b124e8509b65a88a98213c11ab5`: no Python scripts, tests, build tools or CI (including existing code); port tooling to Rust rather than deleting coverage.
- Honor deny-by-default host capabilities, bounded actor queues and cancellation, sealed actor state, sendable/serializable boundaries, and deterministic termination. Distinguish proposed syntax/semantics in unmerged PRs from compiler-supported behavior.
- Use `snake_case` methods and the documented `rt borrow/take/copy/share` ownership surface only when accepted by the pinned compiler. Do not silently rewrite demos for draft features.
- Pin Java/GraalVM, LLVM, WASM, .NET and Forge separately. Java-only guest execution cannot prove five-backend parity.
- Private CI transfer requires explicit authorization, exact Git tree/blob SHA evidence and no cross-org secrets/tokens. A job with zero recorded steps is `NOT_EXECUTED`, not a pass.

## First executable acceptance milestone

Complete exact-SHA compiler check/run and oracle matrix for stable, keyword, and feature examples; compare new grammar and borrow/Option/Result semantics before repinning.

**Related work:** PR #21 already addresses compiler pin/manifest hardening; this PR adds a distinct organizational tooling/evidence gate.

## Promotion gates

1. Record exact demo commit/tree, genuine compiler build/source commit and executable SHA-256 per tested backend.
2. Run real source checking, bounded guest execution, exact byte/exit or protocol oracles, malformed-input/permission/close/cancel negative tests.
3. Require logged runner ID, nonempty steps, exact-head source identity and independent review before claiming a passed parity or release gate.
4. Structural-only CI remains labeled `STRUCTURAL_ONLY` and `NOT_EXECUTED`. Do not treat checks that only run shell/host mock tests as Oreslang execution.
