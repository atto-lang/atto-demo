# Runnable examples

Every top-level `.ores` file in this directory is executed by `scripts/run-all.sh`.

| Example | Focus |
| --- | --- |
| `00_hello.ores` | minimal file-level `routine main` |
| `01_modules_namespaces_callables.ores` | namespaces, modules, recursive `fnc`, lexical lambda |
| `02_structural_types.ores` | explicit structural parameters, objects, arrays, tuples, complex numbers |
| `03_classes_and_methods.ores` | classes, receiver methods, `self` |
| `04_control_flow.ores` | `if/then/elif/else/fi`, conventional loops |
| `05_ownership_and_borrows.ores` | affine move semantics, `mut` owned parameters, `&mut` borrows |
| `06_closures_and_recursive_lambdas.ores` | escaping mutable closure state, explicitly typed recursive lambda |
| `07_iterators_and_scheduler_safepoints.ores` | `for ... of`, `Symbol.iterator`, scheduler cooperation |
| `08_typed_returns_and_destructuring.ores` | finite tuple types, record types, typed return destructuring |
| `09_destructure_discards.ores` | reusable `_` discard patterns |
| `10_inheritance_and_collections.ores` | inheritance, modules, mutable locals, arrays and objects |
| `11_generics_and_inference.ores` | generic functions/classes, explicit and inferred type arguments, nested generics |
| `12_generic_inheritance.ores` | generic interfaces, inherited generic fields/methods, concrete substitution |
| `13_logical_operators.ores` | `&&`, `||`, `^^`, precedence and short-circuit behavior |
| `14_bitwise_operators.ores` | `~`, `&`, `|`, `^`, `<<`, `>>`, `>>>` |

These are executable examples, not syntax sketches. The compiler/runtime revision used by default is pinned in the repository root `SOURCE_REF`.

## Experimental keyword contracts

The `keywords/` subdirectory is intentionally excluded from the normal top-level glob used by `run-all.sh`. Those examples are pinned to feature-specific source commits and are run through:

```bash
bash scripts/run-keyword-demos.sh
```

See `keywords/README.md` and `../docs/keyword-contracts.md`.


## Feature-specific language matrix

Newer language contracts that span stacked compiler branches live under
`features/`. They are pinned per example and run with:

```bash
bash scripts/run-feature-demos.sh
```

That matrix covers async/await, actors, sibling imports, callable-local
interfaces, defer/recover, Option/Result extraction, ownership intrinsics,
trait/class/struct/interface boundaries, static members, destructuring, and
`mut/is/as/with`. See `features/README.md` for the exact semantic boundaries.
