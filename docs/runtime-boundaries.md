# Actors, heaps, GC, and isolates

Oreslang has two distinct isolation concepts: lightweight actors for concurrency/state ownership, and stricter isolates for security/tenant boundaries.

## Actors

Actors own mutable state semantically and communicate only through mailboxes.

Executable source APIs now include:

- `actor.spawn(handler)` for stateless workers;
- `actor.spawn(handler, initial_state)` for actor-private persistent state;
- `actor.send(ref, message)`;
- `actor.stop(ref)` and `actor.join(ref)`;
- `actor.self`;
- `actor.monitor(target)` / `actor.monitor(target, watcher)`;
- `actor.demonitor(...)`;
- `actor.singleton(name, handler[, initial_state])`.

`ActorRef` is a PID-like immutable/copyable capability handle. Sending is non-consuming because ordinary messages are frozen/copied at the actor boundary. Arbitrary mutable host objects and cyclic mutable message graphs are rejected.

For large payloads, `process.share_readonly(value)` freezes once and creates an explicit read-only shared region. Mutable cross-actor aliases remain forbidden.

### Supervision

Monitors are unidirectional and Erlang-like. When a monitored actor exits, its watcher receives an immutable `DOWN` message. Typed Oreslang code can use the `event = "DOWN"` field; the transport map also carries `type = "DOWN"`, `monitor_id`, `actor_id`, and `reason`.

The runtime intentionally supplies monitoring rather than baking one restart policy into actor scheduling. One-for-one, one-for-all, rest-for-one, backoff, and escalation policies can be built as ordinary supervisor actors.

## Memory reclamation

Oreslang is **ownership/drop first, tracing GC second**.

Rust itself does not use a tracing garbage collector: ownership and lifetimes make most reclamation deterministic. Oreslang follows that idea where the compiler can prove lifetimes, while retaining automatic collection for dynamic object graphs, cycles, hot-loaded generations, and implementation objects that cannot be reclaimed statically.

The current interpreter eagerly releases lexical environments at function, block, loop-iteration, and catch-scope boundaries. Actor termination drops its actor-owned state semantically as a unit.

`process.gc()` is available for explicit collection requests. In the current Java/Truffle reference runtime it is a capability-gated, globally rate-limited **JVM GC hint**, not a promise of a physically actor-local collection pause.

### Physical heap caveat

The Java reference runtime still uses one JVM backing heap. The language contract nevertheless rejects mutable cross-actor aliases and tracks actor-owned state separately.

A true BEAM-like physical heap per actor requires Oreslang-owned allocation arenas/heap objects rather than ordinary Java object allocation. The current API is intentionally designed so that allocator/collector can be replaced later without changing actor source programs.

## Isolates

An isolate is the stronger security boundary intended for tenant/FaaS and mobile-style sandboxing.

The host chooses an `IsolatePolicy`; guest source cannot grant itself authority. Restricted contexts deny host reflection, native access, unrestricted filesystem/IO, child-process creation, guest-created threads, environment access, and unrestricted polyglot access unless the host explicitly grants a capability.

Actor spawn/send/control, read-only sharing, and manual GC are separately capability-gated. Child actors cannot widen the parent isolate's capability ceiling or resource limits.

Actors may run inside an isolate, but actor semantics never weaken isolate policy.

## Execution profiles

The runtime supports the same source model across:

- JIT: JVM/GraalVM with Truffle JIT;
- AOT: Native Image host retaining the guest interpreter;
- HYBRID: Native Image host with guest JIT where executable-code generation is permitted.

Strict capability admission is orthogonal to those execution profiles.
