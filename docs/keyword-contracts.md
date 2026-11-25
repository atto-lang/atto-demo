# Keyword execution contracts

This document records the audited contracts used by the experimental keyword demos.

| Keyword | Contract | Key incompatibilities |
| --- | --- | --- |
| `defer` | Callable-scoped LIFO cleanup. The operand is evaluated immediately and must produce an arity-0 callable that runs when the callable unwinds. | A plain void call is not magically deferred; non-zero-arity cleanup values are rejected. |
| `recover` | Callable-scoped arity-1 failure handler. It runs only when a failure escapes the callable, after deferred cleanup. Normal return never triggers it. | Cancellation/security failures remain non-recoverable. Handler fallback must match the callable result type. |
| `lex` | Explicit spelling for normal lexical capture. Capture analysis retains only referenced activation-local bindings; capture-free lambdas use the no-environment path. | Cannot reopen an enclosing `nlex` barrier. |
| `nlex` | One-way activation-local capture barrier. Module/import/top-level/builtin names remain available; locals declared inside remain normal locals. | Cannot be combined with `lex`. |
| `gpu` | Mandatory GPU execution placement, not an optimization hint. The current ABI is conservative and scalar/void-returning. | Cannot combine with `async`; host captures and CPU calls are rejected; no backend means failure, never CPU fallback. |
| `actor` | Concurrency/isolation boundary. Plain actor is private/confined; `shared actor` is the explicit shared-memory-capable domain. Calling `actor fnc ... => T` has type `ActorHandle<T>`. | Cannot combine with `async`; actor bodies never execute synchronously on the caller stack. |
| `async` | Declares a suspendable task whose source return annotation is the fulfilled type `T`; callers see `Future<T>`. | `main` is synchronous; actor+async is invalid; declaring `=> Future<T>` would double-wrap and is rejected. |
| `await` | Unwraps `Future<T>` only inside an async callable or actor mailbox turn. | `ActorHandle<T>` itself is not awaitable; use `await handle.result()`. Ordinary borrows cannot remain live across suspension. |

## Capture keyword policy

Only `lex` and `nlex` are keywords. `lexical` remains an ordinary identifier to avoid unnecessary keyword pollution.

`nlex` is transitive: an inner `lex` cannot punch through an inherited non-lexical barrier.

## Actor versus async

These are separate concurrency contracts:

```text
async fnc foo() => T
call result: Future<T>

actor fnc foo() => T
call result: ActorHandle<T>
completion:  Future<T> via handle.result()
```

This separation prevents an actor handle from being mistaken for a future and keeps actor identity/status/control available independently of completion.

## Fail-closed execution

The reference interpreter intentionally refuses semantic fallbacks that would weaken a keyword:

- `gpu` never falls back to CPU evaluation;
- `async` never runs synchronously just because continuation lowering is unavailable;
- `actor` never executes the actor body on the caller stack.

The negative demos verify those failures explicitly.
