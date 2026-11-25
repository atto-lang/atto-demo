# PR #12 reconciliation — ownership-first GC contracts

Historical head `033aa55aa9c18e10ac079737bcec54599c36e764`; current main `78526efe853e47b649b3a080f585de165dba2ed2`.

This demonstration does **not** make `process.gc()` or `actor.gc()` unconditional runtime guarantees. The current keyword-demo manifest binds `12_gc_contract.ores` and its companion **negative** fixture `13_private_actor_process_gc_denied.ores` to an exact source SHA and checks explicit `PROCESS_GC` denial. Keep that newer pinned positive/negative pair unchanged; do not restore the historical older one-file demo or roll back the checked manifest to `b9f3a71...`.

Preserve the original concept: ordinary owned values are reclaimed by lifetime rules; actor-local GC is scoped to current actor domain, whole-process GC is separate and capability-gated. An `isoactor` or `shared actor` is not entitled to whole-process collection via a guest body. The historical `PrivateCache` / `SharedIndex` examples remain retained in the first-parent Git history, not silently represented as independently certified source-language spellings.

**Gate:** source pin on the manifest must be verified, and both run-mode and fail-mode fixtures must execute on that exact compiler tree. A documentation/branch conflict resolution is not an execution proof.
