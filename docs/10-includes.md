# Includes (`@inject`)

Render another module inline where the directive sits. Headers, footers, policy blocks, boilerplate.

---

## Syntax

```op
[[@inject "path.op"]]
```

Quoted path (single or double):

```op
[[@inject "partials/header.op"]]
[[@inject 'partials/footer.op']]
```

No alias. Expands immediately.

---

## Behavior

On `@inject`:

1. Load target (same rules as `@use`)
2. Render that module's document body
3. Insert at this position

Injected module's `@use` runs. Its `@template` blocks only appear if the body references them.

---

## Example

`partials/disclaimer.op`:

```op
> This assistant does not provide legal advice.
```

Main:

```op
# Support Chat

[[@inject "partials/disclaimer.op"]]

How can I help you today?
```

Output:

```text
# Support Chat

> This assistant does not provide legal advice.

How can I help you today?
```

---

## Inside list items

```op
- prefix [[@inject "partials/item.op"]]
```

Partial lands on the same line after `prefix `.

---

## `@inject` vs `@use`

| | `@use` | `@inject` |
|---|--------|-----------|
| Alias | Yes | No |
| Output | None alone | Full module body |
| Sub-prompts | `$alias.name` | Only if partial body references them |
| Typical | Template libraries | Headers, footers |

Named pieces → `@use`. Whole section in place → `@inject`.

---

## Resolution

Same as `@use`: relative to template dir, basename, search paths, registered modules.

→ [Modules](08-modules.md)

---

## Errors

| Situation | Result |
|-----------|--------|
| File missing | `unable to read module: …` |
| Cycle | `cyclic include: …` |
| LSP ambiguous path | Warning |
| LSP missing | `Include file not found` |

---

## Related

- [Modules (`@use`)](08-modules.md)
- [Template Structure](03-template-structure.md)
- [Rendering and Scoping](14-rendering-and-scoping.md)
