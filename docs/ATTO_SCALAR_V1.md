# Canonical AttoLang scalar-v1 smoke lane

Six immutable `.atto` source fixtures (3 positive, 3 negative) copied byte-for-byte from `ores-truffle-oreslang/oreslang-source.java` at compiler commit `6d8eb70048eafc9a84c5aebe9c1bb06104f16e76`. Each source's Git blob SHA-1 is checked against the upstream reviewed contract manifest blob `43c4d295a237e483f70722bd90ec10d273b73854`.

The positive candidates cover `40 + 2`, arithmetic precedence (`14`), and a `fnc` call (`42`). The negatives reject `%`, `^`, and a reassign to a readonly local. The values and diagnostic categories are **oracles**, not observed execution.

```sh
bash ci/check-atto-scalar-v1.sh
bash ci/check-semantic-coverage.sh
```

These scripts verify source identity and inventory only; they **do not** compile or execute guests. Do not claim AOT correctness. The Java upstream test `AttoScalarV1GuestTest` verifies parser/linked-source admission for positives, and selected negative compiler rejection, but not numeric runtime results. Future real tests must target **these demo-local files** at the pinned compiler head, record exact compiler/demo SHA and tree, toolchain, actual binary hash, stdout/stderr, exit, negative diagnostic family, runner ID/attempt, nonzero executed steps, and reviewer.

This branch is stacked on coverage-index PR #38; the legacy `.ores` baseline and pinned `SOURCE_REF` are unchanged. Track larger ownership/classes/generics/closures/tuple conformance in issues #39/#40. Never export private compiler source to a different org without approved policy and exact-tree/blob identity.
