# atto-demo

Introductory examples demonstrating AttoLang syntax, actors, and runtime features.

## Naming migration and language authority

This repository is maintained at [atto-lang/atto-demo](https://github.com/atto-lang/atto-demo); use `https://github.com/atto-lang/atto-demo.git` for Git remotes and canonical `.atto` source examples. The normative language contract is [atto-spec](https://github.com/atto-lang/atto-spec), with executable guest evidence tracked by [atto-platform-conformance](https://github.com/atto-lang/atto-platform-conformance). Follow current ownership, borrowing, effects, actor, and syntax rules there; do not infer implemented features from a README or unexecuted CI.

## What this project explores

Small examples for first-time AttoLang users.

## How to use these examples

1. Check the repository contents for `.atto` examples and target-specific project manifests.
2. Use the compiler/backend indicated by each example's actual files and scripts.
3. Run checked-in tests or example commands only where documented and verified.
4. Record compiler revision, expected output, and actual result when reporting an issue.

## Portability and status

These examples are intended to demonstrate AttoLang concepts. Examples may depend on unfinished language features or particular backends; their presence is not evidence that every listed feature executes on all targets. Unsupported features should be marked in the individual example's documentation.

## Links

- [AttoLang repositories](https://github.com/atto-lang)
- [Canonical language specification](https://github.com/atto-lang/atto-spec)
- [Backend conformance](https://github.com/atto-lang/atto-platform-conformance)

## Repository ownership and contribution routing

**Belongs here:** Small first-run AttoLang programs showcasing syntax, compilation and basic actor behavior with minimal dependencies.

**Belongs elsewhere:** Multi-application gallery in atto-demos; unstable exploratory prototypes in atto-proof-of-concepts; full server reference in atto-demo-restful-server.

**Security and portability boundary:** Keep examples executable on a named backend and pinned revision, record expected output and diagnostics, and avoid claiming all targets support each example.

AttoLang is the canonical project name; new source, examples and documentation use `.atto` and the `atto-lang` repository organization. This README defines scope, not feature readiness.

**Acceptance:** name exact source SHA/tree, runtime/toolchain, positive and negative checks and execution receipt before claiming support. Host-only tests and empty CI steps do not prove guest execution.
