# TinTin++ Language Server

`tintin-lsp` is a dependency-free stdio language server for TinTin++ scripts.
It is currently developed inside this dotfiles repository and used by the local
Neovim config for the `tintin` filetype.

## Features

- TinTin++ command and substitution completions.
- Document-derived variable and function completions such as `$hp` and `@heal`.
- Hover documentation for known commands and substitutions.
- Heuristic parser-backed diagnostics for command names, argument counts,
  braces, strings, block comments, and nested command blocks.
- Quick-fix code actions for misspelled or ambiguous TinTin++ commands.
- Whole-document formatting that splits top-level commands while preserving
  multiline braced argument payloads.
- Rename support for TinTin variable/function-style symbols.
- Document symbols, go-to-definition, and references for variable/function-style
  symbols across open TinTin documents.
- Workspace symbol search across open TinTin documents.
- Folding ranges for multiline braced command arguments.
- Document links for static file arguments in file-oriented commands such as
  `#read`, `#write`, `#cat`, `#scan`, and `#textin`.
- JSON-RPC/LSP protocol validation for malformed envelopes and params.

## Install

From this package directory:

```sh
npm link
```

Or run directly:

```sh
node bin/tintin-lsp
```

The binary also supports:

```sh
tintin-lsp --help
tintin-lsp --version
```

## Neovim

With `nvim-lspconfig`:

```lua
vim.lsp.config("tintin_lsp", {
  cmd = { "tintin-lsp" },
  filetypes = { "tintin" },
})
vim.lsp.enable("tintin_lsp")
```

The dotfiles package also exposes `tools/.local/bin/tintin-lsp` as a wrapper
around this package binary so the local Neovim config can keep using the same
command.

## Test

```sh
npm test
npm run pack:check
```

The protocol suite launches the server over stdio and verifies LSP framing,
completion item shape, diagnostics, formatting, rename, symbols, folding ranges,
document links, code actions, CLI flags, and invalid-request handling.

## Current Limits

Diagnostics are heuristic and do not replace TinTin++ runtime validation. The
parser covers common command-body shapes but is not yet a formal complete
grammar for every TinTin++ language construct.
