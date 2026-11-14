# AttoLang starter examples

The [manifest](manifest.json) lists two small `.atto` guest-program candidates targeting the documented browser compiler subset:

| File | Goal | Expected return | Execution in this repository |
| --- | --- | --- | --- |
| [scalar-42.atto](scalar-42.atto) | Integer arithmetic | 42 | **Not executed here** |
| [functions-and-stdio.atto](functions-and-stdio.atto) | Functions, basic stdio, return value | 42 | **Not executed here** |

The `expected_return` field is a test **expectation**, not a passing guest receipt. These examples derive from canonical published site source. To claim executable support, record the compiler source SHA, vendored Wasm SHA-256, generated guest SHA-256, host/runtime, actual return value and stdout, and a reproducible exact-head CI run. A Node catalog test only checks source and manifest structure.

Run host-only checks with `node --test tests/*.test.mjs`. Try the actual compiler at [AttoLang Playground](https://atto-lang.github.io/play/) but do not equate browser preview output with native multi-backend parity.
