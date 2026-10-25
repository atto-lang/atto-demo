# Feature-specific language examples

These examples exercise newer Oreslang language surfaces that currently live on different source branches. They are executable contract examples, not syntax sketches.

Run the complete matrix with:

```bash
bash scripts/run-feature-demos.sh
```

Each row in `manifest.tsv` pins the exact `oreslang-source.java` revision that implements the example.

| Example | Focus |
| --- | --- |
| `01_async_await.ores` | `async fnc`, `Future<T>`, and `await` typing |
| `02_actor_handles.ores` | private/shared `actor fnc`, `ActorHandle<T>`, explicit result future |
| `03_local_inline_interfaces.ores` | callable-local and nested interfaces, local structs, `is` |
| `04_type_roles_is_as_with.ores` | interface parameters, concrete class/struct parameters, trait composition, `is/as/with` |
| `05_defer_recover.ores` | callable-scoped LIFO `defer`, `recover`, and re-panic |
| `06_option_unwrap.ores` | `Option<T>`, `unwrap()`, non-panicking `unwrap_safe()`, `Result<T,E>` |
| `07_ownership_intrinsics.ores` | `borrow/copy/share/take` ownership operations |
| `08_class_static_members.ores` | instance members, constructors, class static members |
| `09_destructure_mut.ores` | returned arrays/structs, destructuring, `val mut` and object patterns |
| `imports/main.ores` + `imports/math.ores` | sibling source-unit import resolution |

## Type-role rule of thumb

- **interface**: storage-free capability contract; accept it when callers may pass different conforming representations.
- **trait**: reusable state/behavior composition; compose it into a concrete class or struct with `with` rather than instantiating it alone.
- **struct**: nominal value representation; accept the concrete struct when its representation/category matters.
- **class**: nominal identity/reference representation; accept the concrete class when class identity/category matters.

`03_local_inline_interfaces.ores` uses the current supported "inline" form: a **named interface declared directly inside a callable body**. Anonymous `interface { ... }` type literals directly in a parameter/return slot are not part of the current grammar.

The sibling-import case uses the compiler's multi-source `IncrementalCompiler` graph rather than the single-file CLI launcher. That proves `./math.ores` resolves as a supplied sibling source unit without implying that the single-file launcher already provides a cross-unit runtime linker.
