# tree-sitter-openprompt

Tree-sitter grammar from the old ANTLR `OpenPromptLexer.g4` / `OpenPromptParser.g4`.

## ANTLR → Tree-sitter

| ANTLR | Tree-sitter |
|-------|-------------|
| Lexer modes | Parser context in `grammar.js` |
| `pushMode` / `popMode` | Nested rules (`interpolation`, `conditional_block`, `fenced_code`, …) |
| `_tokenStartCharPositionInLine == 0` | External scanner: column == 0 |
| `_tokenStartLine == 1` | `front_matter_start` only at document start |
| Skipped whitespace in modes | Private rules: `_cond_ws`, `_dir_ws`, `_var_ws` |
| Meta variables | `---` blocks inside templates |
| Markdown fallback tokens | Scanner emits markdown tokens without eating OpenPrompt tags |

## Build

```bash
pnpm install
pnpx tree-sitter generate
pnpx tree-sitter test
```

## LSP

Generated parser is the syntax front-end for the language server. CST → your AST from there.

Pipeline:

```text
template text
  -> Tree-sitter CST
  -> OpenPrompt AST
  -> semantic model
  -> diagnostics / completion / hover / compiler
```

## Neovim

Language id: `openprompt`. Parser and queries must match.

Register a local parser with nvim-treesitter (point at this repo's `queries/`):

```lua
local grammar_path = vim.fn.resolve("/path/to/open-prompt/modules/tree-sitter")

require("nvim-treesitter.parsers").openprompt = {
  install_info = {
    path = grammar_path, -- grammar root, not repo root
    generate = true,
    queries = "queries",
    files = { "src/parser.c", "src/scanner.c", "src/tree_sitter/parser.h" },
  },
  filetype = "openprompt",
}

vim.treesitter.language.register("openprompt", { "op", "openprompt", "prompt" })

vim.filetype.add({
  extension = {
    op = "openprompt",
    openprompt = "openprompt",
    prompt = "openprompt",
  },
})
```

Install / refresh:

```vim
:TSInstall! openprompt
```

Check highlighting:

```vim
:checkhealth nvim-treesitter
:TSBufToggle highlight
:Inspect
```

Parse tree OK but no colors? Queries missing from `~/.local/share/nvim/site/queries/openprompt/`. Usually `install_info.path` points at repo root instead of `modules/tree-sitter`.
