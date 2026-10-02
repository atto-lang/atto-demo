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

## Experimental keyword contracts

The `keywords/` subdirectory is intentionally excluded from the normal top-level glob used by `run-all.sh`. Those examples are pinned to feature-specific source commits and are run through:

```bash
bash scripts/run-keyword-demos.sh
```

See `keywords/README.md` and `../docs/keyword-contracts.md`.


## Revision-pinned feature contracts

The `features/` subdirectory covers newer language contracts that span source branches: sibling imports, callable-local interfaces, the class/struct/interface/trait split, static members, pointerless ownership, Option matching, advanced return destructuring, actor declarations, async/await, and defer/recover.

Run them with:

```bash
bash scripts/run-feature-demos.sh
```

Each case pins the exact source revision it requires. Expected safety rejections are part of the suite, and sibling imports are compiled as a multi-file code-unit set. See `features/README.md`.
