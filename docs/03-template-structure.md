# Template structure

An `.op` file is a document: optional metadata, then a sequence of elements (imports, template defs, prompt content).

The split between top-level elements and inline content is the main thing to get right when reading or writing templates.

---

## Document layout

```text
document
├── front_matter?          (optional, file start only)
└── document_element*
    ├── use_directive
    ├── sub_prompt           (@template block)
    └── prompt_content       (markdown + inline directives)
```

Only prompt content renders by default. Imports and `@template` blocks are processed but don't appear in output unless you reference them.

---

## Delimiters

| Kind | Syntax | Role |
|------|--------|------|
| Directive | `[[@name ...]]` | Control flow, imports, template blocks |
| Expression | `{{ $variable }}` | Insert a value |

Directives start with `@`. Expression variables start with `$`.

Whitespace inside `{{ }}` is optional:

```op
{{ $user }}
{{  $user  }}
```

Same thing.

---

## Top-level `@use`

```op
[[@use "common.op" as $prompts]]
[[@use 42 as $answer]]

# Main content starts here
```

Binds `$prompts` / `$answer` for the rest of the file. No output by itself.

→ [Modules (`@use`)](08-modules.md)

---

## Top-level `@template`

```op
[[@template sidebar]]
## Sidebar

Navigation links…

[[@end]]
```

Defines a named export in this file. Does not render inline. Reference later:

```op
{{ $moduleAlias.sidebar }}
```

→ [Template Blocks (`@template`)](09-template-blocks.md)

---

## Prompt content

Everything that actually becomes prompt text:

```op
# Review Request

Please review the code below.

Hello {{ $user.name }}
```

Can contain markdown blocks, inline text, `{{ }}`, inline `@if` / `@for` / `@inject`, nested blocks.

---

## What renders

| Construct | In output? |
|-----------|------------|
| Markdown text | Yes, verbatim |
| `{{ $variable }}` | Yes, coerced to string |
| `[[@if]]` / `[[@for]]` body | Yes, when taken |
| `[[@inject "file.op"]]` | Yes, rendered module |
| `[[@use ...]]` | No |
| `[[@template ...]]` … `[[@end]]` | No |
| Document front matter | No |
| Template meta blocks | No |

---

## Nesting

Directives and expressions work inside markdown:

```op
[[@for $item in items]]
- {{ $item.name }} [[@inject "suffix.op"]]
[[@end]]
```

Block directives need `[[@end]]`:

```op
[[@if $flag]]
content
[[@end]]
```

---

## Parse errors

Bad syntax → parse failure. No partial render.

LSP shows `Syntax error in template` when the tree has error nodes.

---

## Related

- [Markdown Content](04-markdown-content.md)
- [Front Matter and Metadata](13-front-matter-and-metadata.md)
- [Rendering and Scoping](14-rendering-and-scoping.md)
