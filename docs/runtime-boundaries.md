# Actors and isolates: current runtime boundary

Oreslang has two distinct isolation concepts.

## Actors

Actors own their mutable heaps.

Cross-actor communication goes through mailboxes. Values crossing that boundary are frozen, copied, serialized, or otherwise made sendable. Arbitrary mutable host objects are rejected. Deeply immutable values may be shared read-only.

Actor semantics are about concurrency and memory ownership.

## Isolates

An isolate is a stricter security boundary intended for tenant/FaaS and mobile-style sandboxing.

The host chooses an `IsolatePolicy`; guest source cannot grant itself authority. Restricted contexts deny host reflection, native access, unrestricted filesystem/IO, child-process creation, guest-created threads, environment access, and unrestricted polyglot access unless the host explicitly grants a capability.

Actors may run inside an isolate, but actor semantics never weaken isolate policy.

## Why there is no fake actor source example here

The current public grammar contains the callable/class/module/type syntax exercised by this repository, while actor scheduling/mailbox behavior is currently exposed by the runtime implementation rather than a completed source-level `actor` declaration syntax.

A demo repository should prove what the language can execute today. Until source-level actor syntax lands in the grammar and parser, actor/isolate behavior belongs in runtime integration tests and documentation rather than invented `.ores` examples.

## Execution profiles

The runtime supports the same source model across:

- JIT: JVM/GraalVM with Truffle JIT;
- AOT: Native Image host retaining the guest interpreter;
- HYBRID: Native Image host with guest JIT where executable-code generation is permitted.

Strict capability admission is orthogonal to those execution profiles.
