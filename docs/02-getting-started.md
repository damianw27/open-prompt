# Getting started

Minimal template, context JSON, and what you should see on output.

---

## File extensions

| Extension | Notes |
|-----------|-------|
| `.op` | Default |
| `.openprompt` | Alias |
| `.prompt` | Alias |

Editors use language id `openprompt` for all three.

---

## Hello, world

Template:

```op
# Greeting

Hello {{ $user.name }}!
```

Context:

```json
{
  "user": { "name": "Ada" }
}
```

Output:

```text
# Greeting

Hello Ada!
```

Anything outside `{{ ... }}` and `[[@...]]` copies through unchanged, blank lines included.

---

## Fuller example

Front matter, import, interpolation, conditional, loop.

Template (`review.op`):

```op
---
title: Review
---
[[@use "common.op" as $prompts]]

# Hello

Hello {{ $user.name }}

{{ $prompts.example }}

[[@if $user.age >= 18]]
Adult
[[@elseif $user.age == 17]]
Almost adult
[[@else]]
Minor
[[@end]]

[[@for $item in items]]
- {{ $item.name }}
[[@end]]
```

Module (`common.op`):

```op
[[@template example]]

## Example Section

Use this pattern when demonstrating a feature.

[[@end]]
```

Context:

```json
{
  "user": { "name": "Ada", "age": 18 },
  "items": [
    { "name": "one" },
    { "name": "two" }
  ]
}
```

Output includes:

```text
Hello Ada
## Example Section
Adult
- one
- two
```

What happened:

- Front matter (`title: Review`) never renders. Metadata only.
- `@use` loads `common.op` but doesn't print it.
- `$prompts.example` renders the `example` sub-prompt from that module.
- `@if` picks `Adult` because age is 18.
- `@for` prints one list line per item.

Same shape as [`basic.json`](../modules/binding/tests/vectors/basic.json).

---

## Context shape

Top-level JSON keys become root variables:

| Context key | In templates |
|-------------|--------------|
| `"user"` | `$user`, `$user.name`, … |
| `"items"` | `$items`, `@for` iterable |

Root names: `[A-Za-z_][A-Za-z_0-9]*`.

Value types: [Types and Truthiness](12-types-and-truthiness.md).

---

## From application code

Language vs. how you call the renderer:

```text
createEngine({ searchPaths?, modules? })
loadString(source) / loadFile(path)
setContext(map)
render() → string
```

TypeScript one-liner:

```typescript
import { render } from "@openprompt/binding";

const output = render(
  'Hello {{ $user.name }}',
  { user: { name: "Ada" } },
);
```

File-based `@use` / `@inject`: `createEngine` with `searchPaths` or pre-registered modules. Details: [binding README](../modules/binding/README.md).

---

## Where to go

| Goal | Chapter |
|------|---------|
| Document layout | [Template Structure](03-template-structure.md) |
| Prompt formatting | [Markdown Content](04-markdown-content.md) |
| Dynamic values | [Interpolation](05-interpolation.md) |
| Other files | [Modules (`@use`)](08-modules.md) |

Also: [Introduction](01-introduction.md), [Rendering and Scoping](14-rendering-and-scoping.md), [examples](../modules/tree-sitter/examples/).
