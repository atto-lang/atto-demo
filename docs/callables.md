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
pub routine main() => void {
  runApp();
  return;
}
```

The static checker rejects direct or indirect call cycles that contain a routine. Routines are not tail-call-optimization targets.

## `fnc`

A `fnc` is the named reusable function form.

It may recurse:

```ores
fnc factorial(int n) => int {
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

fnc makeAdder(int base) => IntFn {
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

## `nlex`

`nlex` is implemented as an opt-in capture barrier.

It prohibits capture of outer activation-local bindings while preserving access
to symbols whose lifetime is independent of a particular function invocation:

- module members;
- imports;
- file-level/top-level functions and classes;
- built-ins such as `stdio`, `process`, and `print`.

Locals and parameters declared inside the `nlex` callable remain ordinary
lexical bindings, including normal shadowing:

```ores
val int bias = 100;

val IntFn stateless = nlex |value| -> {
  val int bias = 1;
  return math.offset(value) + bias;
};
```

The outer `bias` is not captured; the inner `bias` is local to the lambda.

The barrier is inherited. A lambda created anywhere inside an `nlex fnc`,
`nlex routine`, or another `nlex` lambda is also non-capturing with respect
to enclosing activation-local state.

This has an actual runtime fast path: ordinary lambdas snapshot/retain their
lexical environment; `nlex` lambdas skip that environment snapshot entirely.
