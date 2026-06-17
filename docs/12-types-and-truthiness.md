# Types and truthiness

Context is JSON-shaped. Runtime maps it to a small type set for interpolation, conditions, loops.

---

## Value kinds

| Kind | JSON | In templates |
|------|------|--------------|
| null | `null`, missing key | Falsy; renders `""` |
| bool | `true`, `false` | Conditions; `"true"` / `"false"` in text |
| number | `42`, `3.14` | Compare; decimal string in text |
| string | `"hello"` | As-is |
| array | `[1, 2]`, `[{…}]` | `@for`; comma-joined in text |
| map | `{ "a": 1 }` | Dot lookup; `"[object]"` if interpolated whole |

Bindings deserialize JSON (or equivalent) into these.

---

## Truthiness

| Kind | True when |
|------|-----------|
| null | never |
| bool | `true` |
| number | not `0` |
| string | non-empty |
| array | length > 0 |
| map | at least one key |

```op
[[@if $user.active]]    → depends on value
[[@if true]]            → true
[[@if ""]]              → false
[[@if 0]]               → false
[[@if 1]]               → true
[[@if null]]            → false
```

---

## Property lookup

Dot paths walk maps only:

```op
{{ $user.profile.name }}
```

Missing key or non-map mid-path → null.

Arrays aren't indexed with dots. Use `@for`.

---

## Arrays

Only `@for` iterables:

```op
[[@for $item in items]]
```

`items` as string, number, map, or null → loop skipped.

Interpolation: `{ "tags": ["a", "b", "c"] }` + `Tags: {{ $tags }}` → `Tags: a,b,c`

Objects in arrays → `[object]` each.

---

## Maps

`{{ $user }}` on `{ "user": { "name": "Ada" } }` → `[object]`

Use fields: `{{ $user.name }}`

---

## String literals

Quotes in conditions and paths:

```op
[[@if $user.role == "admin"]]
[[@use 'common.op' as $prompts]]
```

Grammar allows `\n`, `\t`, etc. in tokens.

> Runtime today: strips quotes only. No escape processing. Literal `\` + `n` stays two chars unless you type a real newline in the file.

Don't rely on `\n` escapes until that's documented as supported.

---

## Literals via `@use`

```op
[[@use true as $flag]]
[[@use 14 as $value]]
```

Typed values in scope, not from context JSON.

---

## Related

- [Interpolation](05-interpolation.md)
- [Condition Expressions](11-condition-expressions.md)
- [Loops](07-loops.md)
- [Language Reference](15-language-reference.md)
