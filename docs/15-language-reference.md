# Language reference

Cheat sheet. Explanations: linked chapters.

---

## Extensions

`.op` · `.openprompt` · `.prompt`

Language id: `openprompt`

---

## Delimiters

| Syntax | Role |
|--------|------|
| `[[@directive …]]` | Directive |
| `{{ $variable }}` | Interpolation |
| `[[@end]]` | Close `@if`, `@for`, `@template` |
| `---` … `---` | Front matter / meta |

---

## Directives

| Directive | Syntax | Output? | Chapter |
|-----------|--------|---------|---------|
| use | `[[@use "path" as $alias]]` | No | [08](08-modules.md) |
| use (literal) | `[[@use 42 as $n]]` | No | [08](08-modules.md) |
| inject | `[[@inject "path"]]` | Yes | [10](10-includes.md) |
| template | `[[@template name]]` … `[[@end]]` | No | [09](09-template-blocks.md) |
| if | `[[@if cond]]` … `[[@end]]` | Branch | [06](06-conditionals.md) |
| elseif | `[[@elseif cond]]` | Branch | [06](06-conditionals.md) |
| else | `[[@else]]` | Branch | [06](06-conditionals.md) |
| for | `[[@for $v in expr]]` … `[[@end]]` | Repeated | [07](07-loops.md) |

---

## Interpolation

```op
{{ $root }}
{{ $root.field }}
{{ $root.nested.field }}
{{ $module["templateName"] }}
{{ $module.templateName }}
```

| Case | Result |
|------|--------|
| Resolved | Coerced string |
| Missing | `""` |
| Map alone | `"[object]"` |
| Array alone | Comma-joined |

→ [05-interpolation.md](05-interpolation.md)

---

## Condition operators

| Op | Role |
|----|------|
| `==` `!=` | Equality |
| `<` `>` `<=` `>=` | Numeric |
| `and` `or` | Truthiness |
| `not` | Negation |
| `in` | Array member or substring |
| `matches` | Substring (right contains left) |

Left-to-right, no precedence. Use `(...)`.

→ [11-condition-expressions.md](11-condition-expressions.md)

---

## Truthiness

| Type | True when |
|------|-----------|
| null | never |
| bool | `true` |
| number | ≠ 0 |
| string | non-empty |
| array | non-empty |
| map | has keys |

→ [12-types-and-truthiness.md](12-types-and-truthiness.md)

---

## Markdown

| Construct | Example |
|-----------|---------|
| Heading | `# Title` |
| Blockquote | `> quote` |
| List | `- item` / `* item` / `+ item` |
| Ordered | `1. item` |
| Blank line | (empty) |
| Code fence | ` ``` ` or ` ~~~ ` |

→ [04-markdown-content.md](04-markdown-content.md)

---

## Identifiers

```ebnf
identifier  ::= [A-Za-z_][A-Za-z_0-9]*
variable    ::= "$" identifier
string      ::= '"' … '"' | "'" … "'"
number      ::= [0-9]+ ("." [0-9]+)?
boolean     ::= "true" | "false"
```

---

## Grammar sketch

```ebnf
document      ::= front_matter? element*
element       ::= use | sub_prompt | prompt_content
use           ::= "[[@use" value "as" variable "]]"
inject        ::= "[[@inject" string "]]"
sub_prompt    ::= "[[@template" name "]]" content* "[[@end]]"
conditional   ::= "[[@if" expr "]]" body* elseif* else? "[[@end]]"
loop          ::= "[[@for" variable "in" path "]]" body* "[[@end]]"
interpolation ::= "{{" variable_ref "}}"
```

---

## Common patterns

System prompt + user context:

```op
# System

You are a helpful assistant for {{ $product.name }}.

[[@if $user.premium]]
The user has premium support.
[[@end]]
```

Shared partial:

```op
[[@inject "partials/policy.op"]]
```

Template library:

```op
[[@use "prompts/common.op" as $lib]]

{{ $lib.intro }}
```

Bullet list from data:

```op
[[@for $item in results]]
- **{{ $item.title }}**: {{ $item.summary }}
[[@end]]
```

Role gate (parenthesized):

```op
[[@if ($user.role == "admin") or ($user.role == "moderator")]]
Elevated instructions here.
[[@end]]
```

---

## Glossary

| Term | Meaning |
|------|---------|
| Document | Whole `.op` file |
| Document body | Default renderable content |
| Directive | `[[@…]]` tag |
| Interpolation | `{{ … }}` replaced at render |
| Context | JSON passed to evaluator |
| Module | Loadable `.op` file |
| Module alias | Name from `@use` |
| Sub-prompt | Named `@template` export |
| Front matter | Leading `---` block |
| Meta block | `---` inside `@template` |
| Scope | Visible bindings during eval |

---

## Handbook index

1. [Introduction](01-introduction.md)
2. [Getting Started](02-getting-started.md)
3. [Template Structure](03-template-structure.md)
4. [Markdown Content](04-markdown-content.md)
5. [Interpolation](05-interpolation.md)
6. [Conditionals](06-conditionals.md)
7. [Loops](07-loops.md)
8. [Modules (`@use`)](08-modules.md)
9. [Template Blocks (`@template`)](09-template-blocks.md)
10. [Includes (`@inject`)](10-includes.md)
11. [Condition Expressions](11-condition-expressions.md)
12. [Types and Truthiness](12-types-and-truthiness.md)
13. [Front Matter and Metadata](13-front-matter-and-metadata.md)
14. [Rendering and Scoping](14-rendering-and-scoping.md)
15. Language reference (this page)
