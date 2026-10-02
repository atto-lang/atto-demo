# Runnable examples

Every top-level `.ores` file in this directory is executed by `scripts/run-all.sh`.

| Example | Focus |
| --- | --- |
| `00_hello.ores` | minimal file-level `routine main` |
| `01_modules_namespaces_callables.ores` | namespaces, modules, recursive `fnc`, lexical lambda |
| `02_structural_types.ores` | explicit structural parameters, objects, arrays, tuples, complex numbers |
| `03_classes_and_methods.ores` | classes, receiver methods, `self` |
| `04_control_flow.ores` | `if/elseif/else/fi`, conventional loops |
| `05_ownership_and_borrows.ores` | affine move semantics, `mut` owned parameters, `&mut` borrows |
| `06_closures_and_recursive_lambdas.ores` | escaping mutable closure state, explicitly typed recursive lambda |
| `07_iterators_and_scheduler_safepoints.ores` | `for ... of`, `Symbol.iterator`, scheduler cooperation |
| `08_typed_returns_and_destructuring.ores` | finite tuple types, record types, typed return destructuring |
| `09_destructure_discards.ores` | reusable `_` discard patterns |
| `10_inheritance_and_collections.ores` | inheritance, modules, mutable locals, arrays and objects |

These are executable examples, not syntax sketches. The compiler/runtime revision used by default is pinned in the repository root `SOURCE_REF`.
