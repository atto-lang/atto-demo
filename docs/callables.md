# Callables: `routine`, `fnc`, and lambda

Oreslang deliberately gives these forms different jobs.

## `routine`

A routine is a named, non-recursive procedural callable.

Use it for:

- `main`;
- application lifecycle steps;
- orchestration;
- setup/teardown procedures;
- operations that should not participate in recursive call cycles.

```ores
pub routine main() : void {
  runApp();
  return;
}
```

The static checker rejects direct or indirect call cycles that contain a routine. Routines are not tail-call-optimization targets.

## `fnc`

A `fnc` is the named reusable function form.

It may recurse:

```ores
fnc factorial(int n) : int {
  if n <= 1; do
    return 1;
  else
    return n * factorial(n - 1);
  fi
}
```

Tail-position calls from a `fnc` are optimization-eligible, although the language does not promise that every recursive function is constant-stack yet.

Functions are private by default; `pub fnc` exports one.

## Lambda

A lambda is an anonymous first-class lexical closure.

```ores
type IntFn = typeof fnc(int value) -> int;

fnc makeAdder(int base) : IntFn {
  return |value| -> {
    return base + value;
  };
}
```

The lambda captures `base` from the environment where the lambda is created. Calls resolve free variables lexically, not dynamically.

Closure capture follows ownership rules: immutable Copy values can be copied; mutable or non-Copy captures move into the closure environment; an escaping closure cannot retain a raw borrowed stack reference.

## Why the distinction is useful

The split makes source intent statically visible:

- `routine`: orchestration that must remain outside recursive cycles;
- `fnc`: named reusable computation, including recursion;
- lambda: first-class behavior plus lexical state.

This also creates useful compiler freedom. A routine never needs recursive-call machinery. A lambda's capture set is explicit to the compiler. A `fnc` remains a named code object rather than automatically becoming a closure.

## About `nlex`

There is currently no `nlex` keyword.

The proposed meaning is sensible only if benchmarks show a material optimization: prohibit capture of outer **local stack bindings** so the compiler can prove that no closure environment is required. Imports, modules, top-level declarations, and runtime globals would remain resolvable as non-captured symbols.

That feature should not land as syntax until the compiler demonstrates a real benefit over ordinary capture analysis. If capture analysis can already prove the same thing for free, `nlex` would add language complexity without a performance payoff.
