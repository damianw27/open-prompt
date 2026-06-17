# Loops

Repeat a content block for each element in an array. Handy for tool lists, search hits, examples, chat turns.

---

## Syntax

```op
[[@for $variable in iterable]]
  body content
[[@end]]
```

| Part | Meaning |
|------|---------|
| `$variable` | Loop name (`$` required) |
| `iterable` | Path to an array |
| body | Any prompt content |

Must close with `[[@end]]`.

---

## Simple loop

Template:

```op
[[@for $item in items]]
- {{ $item.name }}
[[@end]]
```

Context:

```json
{
  "items": [
    { "name": "one" },
    { "name": "two" }
  ]
}
```

Output:

```text
- one
- two
```

---

## Dotted path

```op
[[@for $row in data.rows]]
{{ $row.id }}: {{ $row.label }}
[[@end]]
```

Context:

```json
{
  "data": {
    "rows": [
      { "id": 1, "label": "alpha" },
      { "id": 2, "label": "beta" }
    ]
  }
}
```

Output:

```text
1: alpha
2: beta
```

---

## Scope

Each iteration:

- Copies parent scope
- Binds loop variable to current element

`$item` (or your name) is the current row. Outer vars still visible. Loop var shadows same name outside for the body duration.

---

## Wrong type → skip

Iterable missing or not an array: body skipped, no error.

Template:

```op
Before
[[@for $item in missing]]
- {{ $item }}
[[@end]]
After
```

Context: `{}`

Output:

```text
Before
After
```

---

## With conditionals

```op
[[@for $tool in tools]]
[[@if $tool.enabled]]
- {{ $tool.name }}: {{ $tool.description }}
[[@end]]
[[@end]]
```

---

## List items

```op
[[@for $item in items]]
- {{ $item.name }}
[[@end]]
```

Usual pattern for Markdown bullets from data.

---

## Related

- [Interpolation](05-interpolation.md)
- [Conditionals](06-conditionals.md)
- [Types and Truthiness](12-types-and-truthiness.md)
- [Rendering and Scoping](14-rendering-and-scoping.md)
