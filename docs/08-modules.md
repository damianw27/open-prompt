# Modules (`@use`)

`@use` imports another `.op` file or binds a literal to an alias. How you share sub-prompts without copy-paste.

---

## Syntax

```ebnf
use_directive ::= "[[@use" ws use_value ws "as" ws variable ws "]]"
use_value ::= string_path | number | boolean
variable ::= "$" identifier
```

Examples:

```op
[[@use "common.op" as $prompts]]
[[@use 'partials/tools.op' as $tools]]
[[@use 42 as $answer]]
[[@use true as $enabled]]
[[@use false as $disabled]]
```

No output. Binds `$alias` for the document.

---

## File import

String path → load module, bind alias:

```op
[[@use "common.op" as $prompts]]

{{ $prompts.example }}
```

Module's `@template` exports reachable via alias. → [Template Blocks](09-template-blocks.md)

`common.op`:

```op
[[@template example]]

## Example Section

Shared example content.

[[@end]]
```

Output includes:

```text
## Example Section
Shared example content.
```

---

## Literal bindings

Number or boolean → bind directly, no file:

```op
[[@use 14 as $value]]
[[@use true as $flag]]

The answer is {{ $value }}.
Enabled: {{ $flag }}
```

Output:

```text
The answer is 14.
Enabled: true
```

Constants in the template instead of context.

---

## Path resolution

Runtime tries, in order:

1. Path as given (forward slashes)
2. Relative to current template's directory
3. Basename only
4. Each search path (engine config / stdio VFS)

`OPENPROMPT_SEARCH_PATHS`: colon-separated dirs on native.

TypeScript:

```typescript
const engine = createEngine({ searchPaths: ["./prompts"] });
engine.loadFile("./prompts/main.op");
```

Memory / browser: register explicitly:

```typescript
engine.registerModule("common.op", '[[@template example]]…[[@end]]');
```

---

## Referencing templates

```op
{{ $prompts["example"] }}
{{ $prompts.example }}
```

Same result. Dot form reads cleaner when unambiguous.

---

## `@use` vs `@inject`

| Directive | Effect |
|-----------|--------|
| `@use` | Bind alias; render pieces via `$alias.name` |
| `@inject` | Paste whole module body inline |

Libraries of named chunks → `@use`. Whole section at one spot → `@inject`. → [Includes](10-includes.md)

---

## Cycles

A loads B loads A → `cyclic include: <path>`. Avoid loops.

---

## Missing file

Render fails: `unable to read module: <path>`

LSP: `Use file not found`

---

## Related

- [Template Blocks](09-template-blocks.md)
- [Includes](10-includes.md)
- [Interpolation](05-interpolation.md)
- [Rendering and Scoping](14-rendering-and-scoping.md)
