# Reserved keywords

Oreslang globally reserves these three keywords:

- `of`
- `is`
- `as`

They are lexer keywords, not ordinary identifiers. They cannot be used as names for
variables, parameters, functions, routines, modules, classes, interfaces, fields,
methods, type aliases, generic parameters, namespaces, import aliases, or members.

Invalid examples:

```ores
val is = 1;

fnc as() => void {
  return;
}

define class of
end
```

The keywords remain available in their language roles. `of` is used by iterator
loops and `as` by import aliases:

```ores
for (val item of values) {
  consume(item);
}
```

`is` is reserved now even though no general `is` operator is exposed yet. This
avoids source-breaking collisions when the language grammar grows.

This is different from contextual words such as `structural`, which are only special
in specific grammar positions.
