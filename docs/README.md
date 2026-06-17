# OpenPrompt Language Handbook

Reference for the OpenPrompt templating language: syntax, what the runtime actually does, and examples.

OpenPrompt templates are `.op` files. You mix Markdown-ish text with directives and `{{ expressions }}`, pass JSON context at render time, and get back a plain string for the model.

> Early stage. Started internal. Language, runtime, tooling may change. Pin a commit in prod.

---

## How to read this

New here? Read in order. Each chapter assumes the previous ones.

Know the basics? Jump to what you need, or [Language Reference](15-language-reference.md) for a cheat sheet.

---

## Contents

### Orientation

1. [Introduction](01-introduction.md)
2. [Getting Started](02-getting-started.md)
3. [Template Structure](03-template-structure.md)

### Writing templates

4. [Markdown Content](04-markdown-content.md)
5. [Interpolation](05-interpolation.md)
6. [Conditionals](06-conditionals.md)
7. [Loops](07-loops.md)

### Composition

8. [Modules (`@use`)](08-modules.md)
9. [Template Blocks (`@template`)](09-template-blocks.md)
10. [Includes (`@inject`)](10-includes.md)

### Expressions and data

11. [Condition Expressions](11-condition-expressions.md)
12. [Types and Truthiness](12-types-and-truthiness.md)

### Metadata and runtime

13. [Front Matter and Metadata](13-front-matter-and-metadata.md)
14. [Rendering and Scoping](14-rendering-and-scoping.md)

### Reference

15. [Language Reference](15-language-reference.md)

---

## Elsewhere

| Resource | What |
|----------|------|
| [Project README](../README.md) | Overview, quick start, architecture |
| [Runtime bindings](../modules/binding/README.md) | Build + API |
| [Tree-sitter grammar](../modules/tree-sitter/README.md) | Parser, Neovim |
| [Examples](../modules/tree-sitter/examples/) | Sample `.op` files |

---

## Conventions

- Template source: `op` code blocks
- Context: `json` blocks
- Rendered output: `text` blocks labeled `Output:`
- Warnings flag surprising behavior or things that might change
