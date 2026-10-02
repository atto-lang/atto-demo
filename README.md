# Oreslang Demo

Runnable examples for [Oreslang](https://github.com/ores-truffle-oreslang/oreslang-source.java), the statically typed GraalVM/Truffle guest language.

This repository is intentionally a **demo consumer** of the language implementation. It does not duplicate the compiler/runtime.

## What this demonstrates

- flat file namespaces;
- multiple flat modules in one source file;
- file-level `main`;
- `routine` versus `fnc` versus lambda semantics;
- lexical closures;
- `nlex` non-capturing callables and inherited capture barriers;
- actor spawning and PID-like `ActorRef` handles;
- actor-private persistent state;
- Erlang-style monitor/`DOWN` supervision signals;
- named singleton actors without shared mutable memory;
- explicit `process.gc()` alongside ownership/drop-first lifetime management;
- nominal types with explicit structural-call opt-in;
- classes and receiver methods;
- explicit `return`;
- `const`, `val`, and `let`;
- complex numbers, arrays, objects, tuples, and ordinary control flow.

The actor runtime surface is now executable from Oreslang through `actor.spawn`, `actor.send`, `actor.stop`, `actor.join`, `actor.monitor`, `actor.singleton`, `actor.self`, `process.share_readonly`, and `process.gc()`. Actor declaration sugar is still intentionally absent; these APIs are the canonical executable substrate.

The `05_nlex_callables.ores` example demonstrates the implemented `nlex`
capture barrier. A normal lambda captures outer activation-local bindings;
an `nlex` lambda cannot. Module/import/global names remain resolvable, local
shadowing remains normal, and lambdas created inside an `nlex fnc` or
`nlex routine` inherit the barrier. The runtime uses this guarantee to skip
lexical environment snapshotting for those lambdas.

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

Run the focused `nlex` regression check:

```bash
bash scripts/test-nlex.sh
```

It asserts the exact runtime output `120:102:13:15`.

Run the actor/GC regression check:

```bash
bash scripts/test-actors.sh
```

It asserts the deterministic output `01:singleton:DOWN:failed`: two stateful counter messages, one named singleton actor message, then an Erlang-style `DOWN` failure notification.

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
  05_nlex_callables.ores
  06_actors_gc.ores

docs/
  callables.md
  runtime-boundaries.md

scripts/
  run.sh
  run-all.sh

SOURCE_REF
justfile
```

## Callable model

| form | named | first-class | lexical capture | recursion | intended use |
| --- | --- | --- | --- | --- | --- |
| `routine` | yes | no | n/a | prohibited | entrypoints, lifecycle, orchestration |
| `fnc` | yes | callable by name | no implicit closure capture | allowed | reusable computation, recursion |
| lambda | anonymous | yes | yes | allowed when typed appropriately | callbacks, closures, local behavior |
| `nlex` lambda | anonymous | yes | no outer activation-local capture | no local captured self-binding | stateless callbacks / closure-elision fast path |

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

Actors have semantically private mutable state and communicate through frozen/copied mailbox messages. Large values may cross actors only through explicit read-only sharing. `ActorRef` values are copyable PID-like handles, monitors provide supervisor-visible `DOWN` messages, and singleton state remains owned by one named actor.

The current Java/Truffle reference runtime still uses the JVM heap as its physical backing heap. Ownership/move/drop analysis and eager scope release minimize garbage, while the host collector handles residual dynamic graphs. `process.gc()` is therefore currently a capability-gated, globally rate-limited JVM GC hint; it is deliberately shaped so a future actor-local heap collector can implement the same source API.

