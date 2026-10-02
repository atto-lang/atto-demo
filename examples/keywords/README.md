# Keyword contract demos

These examples intentionally track experimental source branches rather than the stable root `SOURCE_REF`.
Run them with:

```bash
bash scripts/run-keyword-demos.sh
```

The manifest pins an exact compiler/runtime commit for every demo.

| Demo | Contract |
| --- | --- |
| `01_defer.ores` | callable-scoped, LIFO cleanup runs before an explicit return reaches the caller |
| `02_recover.ores` | defer-before-recover, fallback value, no recover execution on a successful return |
| `03_lex_nlex.ores` | `lex` explicitly captures; `nlex` is a one-way activation-local capture barrier |
| `04_gpu_contract.ores` | statically valid GPU placement with conservative scalar ABI |
| `05_gpu_no_cpu_fallback.ores` | expected failure: GPU code never silently executes on CPU |
| `06_actor_contract.ores` | actor calls type as `ActorHandle<T>`; plain actor is private, `shared actor` is explicit |
| `07_actor_no_caller_stack.ores` | expected failure: actor body never executes synchronously on caller stack |
| `08_async_await_contract.ores` | async call type is `Future<T>`; `await` unwraps only in async/actor context |
| `09_async_no_sync_fallback.ores` | expected failure: async body never silently runs synchronously |
| `10_invalid_async_actor.ores` | expected compile failure: async and actor are mutually exclusive |
| `11_invalid_lex_nlex.ores` | expected compile failure: lex and nlex cannot be combined |
| `12_gc_contract.ores` | ownership-first GC surface: actor-local `actor.gc()` plus capability-gated `process.gc()` |

These are contract tests as much as demos: an expected failure is a PASS only when it fails for the specified reason.
