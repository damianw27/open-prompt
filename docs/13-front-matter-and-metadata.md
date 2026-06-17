# Front matter and metadata

`---` blocks hold metadata for tooling. They never appear in rendered prompt output.

Two places:

1. Document front matter (file start)
2. Meta blocks inside `[[@template]]`

---

## Document front matter

Optional, first thing in the file:

```op
---
title: Code Review
model: gpt-4
tags: security performance

other: line
---

# Start of prompt content

Review the code below.
```

Only text after the closing `---` renders.

### Entry syntax

One entry per non-empty line:

| Style | Example |
|-------|---------|
| Colon | `title: Code Review` |
| Space | `title Code Review` |

Space form: first token = key, rest = value.

Blank lines OK. LSP treats `#` lines as comments.

### At runtime

Compiler skips front matter. Not in output, not a template variable.

Use for editor labels, docs, tooling. Per-request data goes in context JSON.

---

## Template meta blocks

Same delimiters inside `@template`:

```op
[[@template "sidebar"]]
---
topic validation
label "validation"
---
## Validation rules

Always verify user input.
[[@end]]
```

Skipped at render. Referencing the template outputs the prompt parts only.

---

## LSP / editors

LSP reads front matter and meta for hovers, include discovery, host-language symbols (TS, JS, Java, C++, Lua, Zig).

Link a template to a TS file:

```op
---
context: ./User.ts
---
```

Editor feature only. Runtime ignores `context` for rendering.

Setup: [LSP](../modules/lsp/), [Tree-sitter README](../modules/tree-sitter/README.md).

---

## Front matter vs context

| | Front matter | Context JSON |
|---|--------------|--------------|
| Where | In `.op` file | Passed at render |
| Changes | With template edits | Per request |
| In output | Never | Via `{{ }}` |
| For | Titles, model hints, tooling | User data, API results |

---

## Related

- [Template Structure](03-template-structure.md)
- [Template Blocks](09-template-blocks.md)
- [Rendering and Scoping](14-rendering-and-scoping.md)
