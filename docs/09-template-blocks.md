# Template blocks (`@template`)

Named sub-prompts inside one file. Export multiple sections without splitting into tiny files.

---

## Syntax

```op
[[@template name]]
  prompt content
[[@end]]
```

Name as identifier or quoted string:

```op
[[@template sidebar]]
…
[[@end]]

[[@template "main"]]
…
[[@end]]
```

Close with `[[@end]]`.

---

## Definitions don't render inline

Body is export only. Output unless referenced:

`library.op`:

```op
[[@template greeting]]
Hello from the library.
[[@end]]

# Document body

This line renders. The greeting template above does not.
```

Output:

```text
# Document body

This line renders. The greeting template above does not.
```

To use it:

```op
[[@use "library.op" as $lib]]

{{ $lib.greeting }}
```

---

## Body content

Same as document body: markdown, `{{ }}`, `@if`, `@for`, `@inject`.

```op
[[@template detailed]]
## Details

[[@for $point in points]]
- {{ $point }}
[[@end]]
[[@end]]
```

Sub-prompt render uses context + scope at the call site.

---

## Meta blocks

`---` metadata inside a template:

```op
[[@template "sidebar"]]
---
topic validation
label "validation"
---
## Validation rules

Check inputs before responding.
[[@end]]
```

Same `key value` / `key: value` as front matter. Not in rendered output.

Before or after other content:

```op
[[@template t1]]
Before meta
---
metaKey metaValue
---
After meta
[[@end]]
```

Referenced output: `Before meta` and `After meta` only.

→ [Front Matter and Metadata](13-front-matter-and-metadata.md)

---

## Names and exports

Names are decoded strings or raw identifiers. Unique per file.

Every `@template` in a file is exported. No separate export list.

---

## Cross-file reference

```op
[[@use "common.op" as $prompts]]

# Main

{{ $prompts.example }}
```

From [`common.op`](../modules/tree-sitter/examples/common.op):

```op
[[@template example]]

## Example Section

- this section is only for test
- this item is only for test

[[@end]]
```

---

## Related

- [Modules (`@use`)](08-modules.md)
- [Interpolation](05-interpolation.md)
- [Front Matter and Metadata](13-front-matter-and-metadata.md)
