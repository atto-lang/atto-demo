# atto-demo

Introductory examples demonstrating AttoLang syntax, actors, and runtime features.

## What this project explores

Small examples for first-time AttoLang users.

## Starter programs

The [browser-subset starter programs](examples/README.md) supply `.atto` examples for integer arithmetic and function/stdio calls, with a machine-readable manifest and host-only structural regression tests. Execution is **not verified in this repository**. See the exact-receipt requirements before treating an expected return as a passing guest result.

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
