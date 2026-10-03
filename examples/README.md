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
| `11_generics_and_inference.ores` | generic functions/classes, explicit and inferred type arguments, nested generics |
| `12_generic_inheritance.ores` | generic interfaces, inherited generic fields/methods, concrete substitution |
| `13_logical_operators.ores` | `&&`, `||`, `^^`, precedence and short-circuit behavior |
| `14_bitwise_operators.ores` | `~`, `&`, `|`, `^`, `<<`, `>>`, `>>>` |
| `16_option_result_unwrap.ores` | current `Option`/`Result` extraction and inspection |
| `17_interfaces_classes_static_and_structural.ores` | current interface/class/static-member boundaries |
| `18_mut_and_destructuring.ores` | `mut` parameters, mutable locals, returned-value destructuring |

These are executable examples, not syntax sketches. The compiler/runtime revision used by default is pinned in the repository root `SOURCE_REF`.

## Experimental keyword contracts

The `keywords/` subdirectory is excluded from the normal top-level glob used by `run-all.sh`. The active entries are listed in `keywords/manifest.tsv`.

The current-source additions cover isolated `isoactor` versus shared-by-default `actor`, actor-local/process GC, async/await with direct actor-callable results, canonical class `as` bodies, and sibling source imports. Historical syntax that is not present in current source main is intentionally not registered as an active contract.
