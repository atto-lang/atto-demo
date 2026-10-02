# Oreslang Demo

Runnable examples for [Oreslang](https://github.com/ores-truffle-oreslang/oreslang-source.java), the statically typed GraalVM/Truffle guest language.

This repository is intentionally a **demo consumer** of the language implementation. It does not duplicate the compiler/runtime.

## What this demonstrates

- flat file namespaces;
- multiple flat modules in one source file;
- file-level `main`;
- `routine` versus `fnc` versus lambda semantics;
- lexical closures;
- nominal types with explicit structural-call opt-in;
- classes and receiver methods;
- explicit `return`;
- `const`, `val`, and `let`;
- complex numbers, arrays, objects, tuples, and ordinary control flow;
- affine ownership, owned mutation, and mutable borrows;
- escaping lexical closures and explicitly typed recursive lambdas;
- custom iterators and scheduler safepoints;
- finite tuple and structural-record return types;
- returned-value destructuring and reusable `_` discard patterns;
- inheritance across module-qualified classes;
- generic functions, classes, interfaces, explicit specialization, and inference;
- generic inheritance with concrete field/method substitution;
- logical `&&`, `||`, and `^^` with short-circuit semantics;
- integer bitwise `~`, `&`, `|`, `^`, `<<`, `>>`, and `>>>`.

The stable examples stay pinned to the root `SOURCE_REF`. Experimental keyword contracts for `defer`, `recover`, `lex`, `nlex`, `gpu`, `actor`, `async`, and `await` live separately under `examples/keywords/` because those features currently span stacked source branches.

Run the audited keyword matrix with:

```bash
bash scripts/run-keyword-demos.sh
```

Each keyword case pins its own exact source commit and declares whether it must run successfully or fail closed for a specific reason. See `docs/keyword-contracts.md`.

## Quick start

Requirements:

- GraalVM 25.3 / Java 25;
- Maven;
- GitHub CLI (`gh`) only if the Oreslang source repository is not already checked out next to this repo.

Clone the demo and run it:

```bash
gh repo clone ores-truffle-oreslang/oreslang-demo

cd oreslang-demo
bash scripts/run-all.sh
```

The runner compiles the Oreslang implementation before invoking the launcher. A bare Maven `exec:java` is not enough on a fresh source checkout because it does not implicitly run the `compile` lifecycle.

Or run one file:

```bash
bash scripts/run.sh examples/01_modules_namespaces_callables.ores
```

By default, the runner uses `../oreslang-source.java` only when that checkout is already at the exact revision in `SOURCE_REF`. Otherwise it leaves the sibling checkout untouched and uses a pinned checkout in `.cache/oreslang-source.java`. This prevents an unrelated local compiler branch from silently changing demo behavior.

You can override the compiler/runtime checkout without modifying anything:

```bash
ORESLANG_SOURCE_DIR=/path/to/oreslang-source.java \
  bash scripts/run.sh examples/00_hello.ores
```

## Repository layout

```text
examples/
  00_hello.ores
  01_modules_namespaces_callables.ores
  02_structural_types.ores
  03_classes_and_methods.ores
  04_control_flow.ores
  05_ownership_and_borrows.ores
  06_closures_and_recursive_lambdas.ores
  07_iterators_and_scheduler_safepoints.ores
  08_typed_returns_and_destructuring.ores
  09_destructure_discards.ores
  10_inheritance_and_collections.ores
  11_generics_and_inference.ores
  12_generic_inheritance.ores
  13_logical_operators.ores
  14_bitwise_operators.ores
  README.md
  keywords/
    README.md
    manifest.tsv
    01_defer.ores
    ...
    11_invalid_lex_nlex.ores

docs/
  callables.md
  keyword-contracts.md
  runtime-boundaries.md

scripts/
  run.sh
  run-all.sh
  run-keyword-demos.sh

SOURCE_REF
justfile
```

## Callable model

| form | named | first-class | lexical capture | recursion | intended use |
| --- | --- | --- | --- | --- | --- |
| `routine` | yes | no | n/a | prohibited | entrypoints, lifecycle, orchestration |
| `fnc` | yes | callable by name | no implicit closure capture | allowed | reusable computation, recursion |
| lambda | anonymous | yes | yes | allowed when typed appropriately | callbacks, closures, local behavior |

The canonical entrypoint form is:

```ores
pub routine main() => void {
  return;
}
```

See `docs/callables.md` for the exact split.

## Compiler/runtime pin

`SOURCE_REF` pins the compiler/runtime revision used as the stable baseline for these demos. An adjacent checkout is used only when its `HEAD` exactly matches that pin. The local sibling checkout is never rewritten or checked out automatically; the runner-managed cache is pinned instead.

Set `ORESLANG_SOURCE_DIR` when you intentionally want to test a local compiler/runtime branch rather than the pinned demo baseline.

The current pin is the merge revision for the generics and logical/bitwise-operator hardening work. The corresponding PR head was independently verified under GraalVM 25.3 / Java 25 with `mvn verify`: 184 tests passed with zero failures, including all 16 focused generics/operator tests, plus native AOT, native hybrid, and polyglot-isolate validation.

## Current implementation boundary

The source repository currently defines actor-owned mutable heaps, frozen/message-passed cross-actor values, read-only sharing, and stricter capability-gated isolates. The public Oreslang grammar does not yet expose a complete actor declaration/mailbox syntax, so this repo keeps those runtime semantics documented rather than pretending unsupported source code is executable.


## Runner output

`scripts/run-all.sh` resolves the compiler/runtime once, compiles it once, and then executes each demo independently. Successful runs are intentionally compact:

```text
==> Building Oreslang runtime...
BUILD PASS

==> 00_hello.ores
hello from oreslang
PASS

...

15/15 demos passed
```

Known Graal/Truffle `sun.misc.Unsafe` deprecation lines are suppressed only after a demo succeeds; unrelated stderr is still printed. Set `ORESLANG_SHOW_RUNTIME_WARNINGS=1` to show the full runtime warning stream.
