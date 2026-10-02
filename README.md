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
- complex numbers, arrays, objects, tuples, and ordinary control flow.

The runtime also already has actor isolation and deny-by-default isolate capability machinery. Those are documented here, but this demo does **not** invent actor source syntax that is not yet in the grammar.

Likewise, `nlex` is intentionally not demonstrated: it is not currently a language keyword. It should only be added if compiler/runtime measurements show a real non-tradeoff win from closure-environment elision.

## Quick start

Requirements:

- GraalVM 25.3 / Java 25;
- Maven;
- GitHub CLI (`gh`) only if the Oreslang source repository is not already checked out next to this repo.

Clone both repositories next to each other:

```bash
gh repo clone ores-truffle-oreslang/oreslang-source.java
gh repo clone ores-truffle-oreslang/oreslang-demo

cd oreslang-demo
bash scripts/run-all.sh
```

Or run one file:

```bash
bash scripts/run.sh examples/01_modules_namespaces_callables.ores
```

If `../oreslang-source.java` is absent, the runner clones the source repository into `.cache/oreslang-source.java` and checks out the revision in `SOURCE_REF`.

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

The canonical entrypoint form is:

```ores
pub routine main() => void {
  return;
}
```

See `docs/callables.md` for the exact split.

## Compiler/runtime pin

`SOURCE_REF` pins the compiler/runtime revision used as the stable baseline for these demos. The local sibling checkout is never automatically rewritten or checked out to that revision; only the runner-managed cache is pinned.

## Current implementation boundary

The source repository currently defines actor-owned mutable heaps, frozen/message-passed cross-actor values, read-only sharing, and stricter capability-gated isolates. The public Oreslang grammar does not yet expose a complete actor declaration/mailbox syntax, so this repo keeps those runtime semantics documented rather than pretending unsupported source code is executable.

