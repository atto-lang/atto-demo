# Canonical AttoLang scalar-v1 smoke lane

Six immutable `.atto` source fixtures (3 positive, 3 negative) copied byte-for-byte from `ores-truffle-oreslang/oreslang-source.java` at compiler commit `6d8eb70048eafc9a84c5aebe9c1bb06104f16e76`. Each source's Git blob SHA-1 is checked against the upstream reviewed contract manifest blob `43c4d295a237e483f70722bd90ec10d273b73854`.

The positive candidates cover `40 + 2`, arithmetic precedence (`14`), and a `fnc` call (`42`). The negatives reject `%`, `^`, and a reassign to a readonly local. The values and diagnostic categories are **oracles**, not observed execution. The reviewed six-row manifest is additionally bound to Git blob `aef423001dcdb296b4102f8197fab273f14bd0cf` to reject oracle tampering. A local hermetic shell reproduction of the exact PR gate (blob `d98e666c8fb44fd90f262b9b6c6b51cc5ae1eb62`) passed six positive integrity checks and ten source mutation/rejection scenarios. This is host-only evidence, not a native guest result.

```sh
bash ci/check-atto-scalar-v1.sh
bash ci/test-atto-scalar-v1.sh
bash ci/check-semantic-coverage.sh
```

These scripts verify source identity and inventory only; they **do not** compile or execute guests. Do not claim AOT correctness. The Java upstream test `AttoScalarV1GuestTest` verifies parser/linked-source admission for positives, and selected negative compiler rejection, but not numeric runtime results. Future real tests must target **these demo-local files** at the pinned compiler head, record exact compiler/demo SHA and tree, toolchain, actual binary hash, stdout/stderr, exit, negative diagnostic family, runner ID/attempt, nonzero executed steps, and reviewer.

This branch is stacked on coverage-index PR #38; the legacy `.ores` baseline and pinned `SOURCE_REF` are unchanged. Track larger ownership/classes/generics/closures/tuple conformance in issues #39/#40. Never export private compiler source to a different org without approved policy and exact-tree/blob identity.

## Real compiler and guest execution (requires an authorized local checkout)

```sh
# In an environment with Java/GraalVM, Maven, Git, and an existing clean compiler checkout:
ATTO_JAVA_SOURCE_DIR=/absolute/path/to/oreslang-source.java \
  ATTO_EXPECTED_DEMO_HEAD=$(git rev-parse HEAD) \
  bash ci/run-atto-scalar-java.sh
```

This runner does **not** clone or download the private compiler. It requires its checkout to be at the exact SHA in `conformance/atto-scalar-v1/SOURCE_REF`, verifies source cleanliness before and after builds and each case, checks the source-only gates, compiles the actual Java runtime using Maven, constructs the runtime dependency classpath, and runs the real `dev.oreslang.launcher.OresMain` in a distinct `java` process.

The `--check` pass is separate from executing valid programs; valid programs must actually exit with their manifest's value (`42`, `14`, `42`). Invalid programs must produce compiler failure exit `1` with a relevant operator/mutability diagnostic; process exit `2` or a generic source-not-found error cannot count. No fake Maven, mocked Java executable, or Bash-only result can satisfy this lane. Collect its exact output and JDK/Maven identifiers in the CI receipt, then verify the job had an assigned runner and **nonzero steps**. The source-only workflow does not invoke this runner because it has no authorized private compiler checkout.

**Current evidence remains NOT_EXECUTED for this real guest runner.** The CLI may expose previously untested `fnc main` execution or rejection-diagnostic differences; resolve any findings against the pinned compiler before relaxing the oracle. No AOT or other-backend claim follows from this JVM test.
