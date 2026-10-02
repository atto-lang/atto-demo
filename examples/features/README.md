# Revision-pinned feature examples

These examples cover language work that currently spans multiple Oreslang source branches. They do **not** move the stable root `SOURCE_REF`. Each row in `manifest.tsv` pins the exact compiler/runtime revision that owns the demonstrated contract.

Run the suite with:

```bash
bash scripts/run-feature-demos.sh
```

A contract can be:

- `run`: the example must execute and print the expected marker;
- `fail`: the example must fail for the expected safety diagnostic;
- `compile-dir`: every `.ores` unit in a directory is compiled together with `IncrementalCompiler`, which is how sibling source imports are resolved without granting guest code ambient filesystem access.

| Example | Focus |
| --- | --- |
| `imports/app.ores` + `imports/lib.ores` | sibling-file imports: module, class, function, and namespaced wildcard |
| `01_local_and_inline_interfaces.ores` | compact callable-local interface syntax, a callable-local struct implementing it, and a nested block-local interface |
| `02_type_model_args.ores` | interface parameters vs concrete class/struct parameters; trait state/behavior composed with `with`; `is` conformance; `as` declaration bodies |
| `03_trait_is_not_runtime_value.ores` | expected rejection: a trait is a composition unit, not an ordinary runtime parameter value on this revision |
| `04_class_members_and_static_members.ores` | instance members, constructor initialization, class static data, instance/static access |
| `05_pointerless_ownership.ores` | ordinary read borrows, `mut` exclusive parameters, `borrow(x)`, `copy(x)`, and `take` ownership transfer |
| `06_share_is_explicit_capability.ores` | expected rejection: `share(x)` cannot manufacture ambient shared mutable state |
| `07_option_matching.ores` | `Option<T>`, `Some`, `None`, panicking `unwrap()`, and non-panicking `unwrap_safe()` returning `Result<T, OptionUnwrapError>` |
| `08_union_return_destructuring.ores` | union-typed finite-return shapes, homogeneous arrays, and destructuring returned results |
| `09_actor_declarations.ores` | private/shared actor functions, `shared actor` declarations, actor-owned mutable state, `ActorHandle<T>` and result futures |
| `10_async_await_usage.ores` | `Future<T>` typing, multiple `await` points, and explicit `await handle.result()` for actor completion |
| `11_defer_recover_together.ores` | LIFO `defer`, panic recovery, defer-before-recover, and recovery skipped on normal return |
| `12_mut_is_as_with.ores` | focused syntax example for `mut` parameters plus `is`, `as`, and `with` in the four-way type model |

## Option unwrap policy

The pinned Option/Result hardening revision implements both extraction forms:

```ores
val Option<int> present = Some(42);
val int value = present.unwrap();

val Option<int> missing = None;
val Result<int, OptionUnwrapError> safe = missing.unwrap_safe();
```

`unwrap()` returns the payload and raises a language panic on `None`. `unwrap_safe()` never panics for absence; it preserves failure as a `Result` value. The feature demo executes both paths.

## Inline/local interface policy

“Inline interface” here means the compact interface declaration placed directly inside a callable body:

```ores
fnc work() => void {
  interface LocalApi {
    fnc ping() => int;
  }
  return;
}
```

Callable-local types are lexically scoped and direct callable-body declarations are type-hoisted where the compiler contract permits it. This suite does not invent an anonymous interface-literal type syntax that the parser does not implement.

## Four-way type model at parameter boundaries

The examples make the intended roles explicit:

- **class**: concrete reference/identity representation; may be accepted directly as a nominal parameter;
- **struct**: concrete value representation; may be accepted directly as a nominal parameter;
- **interface**: storage-free behavior contract; classes/structs can satisfy it with `is` and then pass through an interface parameter;
- **trait**: reusable state/behavior composition via `with`; on the pinned four-way integration revision it is not itself an ordinary runtime value type, and the negative contract verifies that boundary.

## Ownership boundary

On the pointerless ownership revision:

- `Box value` temporarily read-borrows a non-Copy argument;
- `mut Box value` takes an exclusive temporary mutable borrow;
- `take Box value` transfers ownership;
- `borrow(x)` makes the read-borrow explicit;
- `copy(x)` succeeds only when Copy is proven;
- `share(x)` does not bypass ownership. Ordinary values are rejected until an explicit shared-capability type is involved.

## Actor and async runtime boundary

The actor/async examples intentionally execute only their synchronous `main` markers. Their declarations and type contracts are checked, but the pinned interpreter refuses to fake asynchronous or actor execution synchronously while continuation/dispatcher lowering is incomplete. That fail-closed runtime policy is separately covered by the keyword contracts.
