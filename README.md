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
- callable-scoped LIFO `defer`;
- explicit callable-producing defer forms such as `defer file.Close()`;
- self-invoking defer producers;
- `break` and `continue` in classic and for-of loops;
- `try/finally` interaction with loop control and deferred cleanup.

The runtime also already has actor isolation and deny-by-default isolate capability machinery. Those are documented here, but this demo does **not** invent actor source syntax that is not yet in the grammar.

Likewise, `nlex` is intentionally not demonstrated: it is not currently a language keyword. It should only be added if compiler/runtime measurements show a real non-tradeoff win from closure-environment elision.

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
  05_defer_lifo.ores
  06_defer_producers.ores
  07_break_continue.ores
  08_loop_cleanup.ores

docs/
  callables.md
  runtime-boundaries.md

scripts/
  run.sh
  run-all.sh

SOURCE_REF
justfile
```

## New cleanup and loop-control examples

### `05_defer_lifo.ores`

Shows direct zero-arity deferred lambdas and their function-scoped LIFO order.

Expected output:

```text
body
second defer
first defer
```

### `06_defer_producers.ores`

Shows the intentionally non-Go-like rule for call expressions used with `defer`:

```ores
defer file.Close();
```

`file.Close()` executes immediately and must return a zero-arity function. That returned
function is what runs at callable exit. The example also demonstrates a self-invoking
lambda producer.

### `07_break_continue.ores`

Demonstrates `continue` and `break` in both classic `for (;;)` and `for (... of ...)`
loops. In a classic loop, `continue` still evaluates the update expression while `break`
does not.

Expected totals are `13` and `40`.

### `08_loop_cleanup.ores`

Combines `continue`, `break`, `try/finally`, and callable-scoped `defer`. The
`finally` block runs before loop control resumes, while deferred actions remain registered
until `main` exits and then run LIFO.

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

## Current implementation boundary

The source repository currently defines actor-owned mutable heaps, frozen/message-passed cross-actor values, read-only sharing, and stricter capability-gated isolates. The public Oreslang grammar does not yet expose a complete actor declaration/mailbox syntax, so this repo keeps those runtime semantics documented rather than pretending unsupported source code is executable.

