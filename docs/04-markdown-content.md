# Markdown content

Templates are meant to read like Markdown. Most of what you write is plain text and familiar line patterns that copy straight to output.

OpenPrompt is not a Markdown processor. It recognizes line shapes for parsing and preserves the source text.

---

## Why it works this way

Prompts are usually Markdown-ish anyway: headings for sections, bullets for constraints, fences for code. OpenPrompt lets you write that and drop directives where you need them.

Input:

```op
# Code Review

Review the following changes carefully.

- Check for bugs
- Check for readability
```

Output: same text, same blank lines and list markers.

---

## Block constructs

### Headings

ATX style at line start (`#` through `######`):

```op
# Main
## Section
### Subsection
```

### Blockquotes

Lines starting with `>`:

```op
> Important constraint: do not invent APIs.
```

### Blank lines

Preserved. They stay in output.

### Unordered lists

`-`, `*`, or `+` then space/tab:

```op
- first item
* second item
+ third item
```

With interpolation / directives:

```op
[[@for $item in items]]
- {{ $item.name }}
[[@end]]
```

Context: `{ "items": [{ "name": "alpha" }, { "name": "beta" }] }`

Output:

```text
- alpha
- beta
```

### Ordered lists

Digit, period, whitespace:

```op
1. first step
2. second step
```

### Fenced code

Backticks:

````op
```
function hello() {
  return "world";
}
```
````

Tildes:

```op
~~~
config line
another line
~~~
```

Fence contents are literal. Don't expect expressions inside fences to evaluate.

---

## Inline content

Unrecognized block starters become inline text:

```op
Plain text with ! punctuation and numbers like 42.
```

Inline can hold `{{ $variable }}`, `[[@inject "partial.op"]]`, normal characters, newlines.

---

## Blocks + directives together

```op
# Results

[[@if $errors]]
## Errors found

[[@for $err in errors]]
- {{ $err.message }}
[[@end]]
[[@else]]
No errors detected.
[[@end]]
```

Each branch can use any valid prompt content.

---

## Not supported

OpenPrompt won't:

- Turn Markdown into HTML
- Resolve links or images
- Reflow soft-wrapped lines
- Handle full CommonMark (nested lists, thematic breaks, etc.)

Need real Markdown processing? Run it after render, or put pre-rendered HTML/Markdown in context.

---

## Related

- [Template Structure](03-template-structure.md)
- [Interpolation](05-interpolation.md)
- [Loops](07-loops.md)
