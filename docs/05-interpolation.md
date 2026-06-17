# Interpolation

Insert runtime values with double braces:

```op
Hello {{ $user.name }}!
```

At render time the expression becomes the string form of the resolved value.

---

## Syntax

```ebnf
interpolation ::= "{{" ws? variable_reference ws? "}}"
variable_reference ::= "$" identifier path_segment* prompt_selection?
path_segment ::= "." identifier
prompt_selection ::= "[" string "]"
identifier ::= [A-Za-z_][A-Za-z_0-9]*
```

Examples:

```op
{{ $user }}
{{ $user.name }}
{{ $user.profile.displayName }}
{{ $prompts["example"] }}
{{ $prompts.example }}
```

---

## Name resolution

Order:

1. Loop locals from enclosing `[[@for]]`
2. `@use` literal bindings (numbers, booleans, strings)
3. Context roots from render-time JSON

Missing path → empty string. No error, no placeholder.

Template:

```op
Hello {{ $user.name }} / {{ $missing.value }}
```

Context: `{ "user": { "name": "Ada" } }`

Output:

```text
Hello Ada / 
```

---

## Dot paths

```op
{{ $user.profile.name }}
```

Each segment is a map key lookup. Intermediate value not a map → empty result.

---

## Prompt selection

When `$prompts` is a module alias, render a named sub-prompt:

Bracket form:

```op
{{ $prompts["example"] }}
```

Dot shorthand (one segment, module alias):

```op
{{ $prompts.example }}
```

That renders template `example` from the module, not a map field. Shorthand reads better for frequent template refs.

→ [Modules (`@use`)](08-modules.md), [Template Blocks](09-template-blocks.md)

---

## Value → string

| Kind | Output |
|------|--------|
| null / missing | `""` |
| bool | `"true"` / `"false"` |
| number | Decimal text (`"18"`, `"3.14"`) |
| string | As-is |
| array | Elements joined with commas, no spaces |
| map | `"[object]"` |

Example:

Template: `Flags: {{ $enabled }}, items: {{ $items }}`

Context: `{ "enabled": true, "items": [{ "name": "a" }, { "name": "b" }] }`

Output: `Flags: true, items: [object],[object]`

> Maps stringify as `[object]`. Put formatted text in context if you need structure in output.

---

## Inside markdown

```op
# Report for {{ $user.name }}

- Role: {{ $user.role }}
- Active: {{ $user.active }}
```

→ [Markdown Content](04-markdown-content.md)

---

## Related

- [Types and Truthiness](12-types-and-truthiness.md)
- [Modules (`@use`)](08-modules.md)
- [Rendering and Scoping](14-rendering-and-scoping.md)
