# PR #9: semantic integration of negative feature contracts

Historical head `8c62cba7f323028eb7c4e79ae6f2914546825de4`. Current main `6fefbc0cdedab10d664d0e5051f1a8b7678e38f9`.

Current main holds newer affirmative demos, exact compiler pins, a pinned sibling-import graph and an independently guarded GC demo with permission-denial. Do not restore outdated Option.unwrap_safe or bypass the current compiler syntax by replacing the entire manifest.

Port two unique **expected-failure** semantic contracts: traits cannot be used as ordinary runtime parameter values, and sharing requires explicit capability authority. Reuse their original exact source pins. Extend the existing run-feature-demos runner with `fail` mode; negative admission requires a nonzero exit **and** the pinned diagnostic phrase, while existing positive run/import-graph cases still require successful exit and expected output. The runner is not a proof of compiler invocation until the pinned compiler and full fixture execution are observed.

Release requirements: run positive and negative fixtures with each exact compiler tree, inspect denial diagnostics, and validate no source pin has drifted. The full historical example inventory remains in the first-parent Git ancestry, not silently treated as implemented by newer main.
