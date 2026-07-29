# Neovim Configuration

Lua-based Neovim configuration using `lazy.nvim`. The entrypoint is `init.lua`, which loads core config from `lua/config/` and plugin specs from `lua/plugins/`.

## Structure

- `init.lua`: entrypoint.
- `lua/config/lazy.lua`: bootstraps and configures `lazy.nvim`.
- `lua/config/options.lua`: editor options.
- `lua/config/keymaps.lua`: custom keymaps loaded on `VeryLazy`.
- `lua/config/markdown.lua`: Markdown frontmatter timestamp automation.
- `lua/config/spelling.lua`: spellfile and Codebook dictionary integration.
- `lua/plugins/*.lua`: plugin specs grouped by feature area.
- `.clang-format`: C/C++ formatting standard.
- `.prettierrc.json`: Prettier formatting standard.
- `.eslintrc.json`: JavaScript/TypeScript fix rules used before Prettier.
- `.csharpierrc.json`: CSharpier formatting standard.
- `lazy-lock.json`: plugin lockfile.

## Validation Commands

Run from this directory:

```sh
luac -p init.lua lua/config/*.lua lua/plugins/*.lua
nvim --headless "+lua print('startup-ok')" +qa
nvim --headless "+checkhealth nvim-treesitter mason obsidian" +qa
```

Plugin install/update:

```sh
nvim --headless "+Lazy! sync" +qa
```

## Formatter Configuration

`<leader>cf` formats through `conform.nvim`, falling back to LSP formatting when no Conform formatter is configured.

| Filetype     | Formatter                       | Config                               |
| ------------ | ------------------------------- | ------------------------------------ |
| C            | `clang-format`                  | `.clang-format`                      |
| C++          | `clang-format`                  | `.clang-format`                      |
| CMake        | `cmake-format`                  | Mason binary                         |
| C#           | `csharpier`                     | `.csharpierrc.json`                  |
| JavaScript   | ESLint curly fix, then Prettier | `.eslintrc.json`, `.prettierrc.json` |
| JSX          | ESLint curly fix, then Prettier | `.eslintrc.json`, `.prettierrc.json` |
| TypeScript   | ESLint curly fix, then Prettier | `.eslintrc.json`, `.prettierrc.json` |
| TSX          | ESLint curly fix, then Prettier | `.eslintrc.json`, `.prettierrc.json` |
| JSON         | Prettier                        | `.prettierrc.json`                   |
| Markdown/MDX | Prettier                        | `.prettierrc.json`                   |

Shared formatter choices:

- Print width is `120` for Clang, Prettier, and CSharpier.
- Indentation is spaces, width `4`.
- C/C++ `InsertBraces: true` adds braces to braceless control statements when safe.
- JavaScript/TypeScript ESLint uses `curly: all` and inserts a blank line after block-like statements.

## Core Keymaps

Leader is `<Space>`.

## Editor Behavior

- Insert mode uses a thicker blinking vertical cursor.
- Folding is available broadly through `nvim-ufo`; buffers open expanded by default with a compact unpadded line-number and fold-marker column.

| Key                | Mode                 | Action                                  |
| ------------------ | -------------------- | --------------------------------------- |
| `<leader><leader>` | normal               | Find files from project root            |
| `<leader>/`        | normal               | Live grep from project root             |
| `<leader>pv`       | normal               | Open netrw                              |
| `<leader>e`        | normal               | Toggle Snacks explorer                  |
| `<leader>E`        | normal               | Open explorer at current file directory |
| `<leader>?`        | normal               | Show buffer-local keymaps               |
| `<C-s>`            | normal/insert/visual | Save buffer                             |
| `<leader>nh`       | normal               | Clear search highlights                 |
| `<leader>nd`       | normal               | Dismiss Noice notification if available |
| `<leader>+`        | normal               | Increment number                        |
| `<leader>-`        | normal               | Decrement number                        |
| `<leader>w`        | normal               | Window command prefix, proxies `<C-w>`  |
| `<leader>y`        | normal/visual        | Yank to system clipboard                |
| `<leader>Y`        | normal               | Yank line to system clipboard           |
| `<leader>d`        | normal/visual        | Delete without yanking                  |
| `<leader>p`        | visual               | Paste without yanking replaced text     |
| `q:`               | normal               | Quit command-line window                |

Motion/editing tweaks:

| Key               | Mode   | Action                                     |
| ----------------- | ------ | ------------------------------------------ |
| `j` / `k`         | normal | Move by visual line when no count is given |
| `J`               | normal | Join lines and preserve cursor view        |
| `J` / `K`         | visual | Move selected lines down/up                |
| `Y`               | normal | Yank to end of line                        |
| `<C-d>` / `<C-u>` | normal | Half-page scroll and recenter              |
| `n` / `N`         | normal | Next/previous search result and recenter   |
| `<C-c>`           | insert | Exit insert mode                           |

## File, Buffer, And Project Keymaps

| Key                         | Action                               |
| --------------------------- | ------------------------------------ |
| `<leader>fb`                | Buffers                              |
| `<leader>fB`                | All buffers, including hidden/nofile |
| `<leader>fc`                | Find config file                     |
| `<leader>ff`                | Find files from root                 |
| `<leader>fF`                | Find files from cwd                  |
| `<leader>fg`                | Find git files                       |
| `<leader>fr`                | Recent files                         |
| `<leader>fR`                | Recent files filtered to cwd         |
| `<leader>fp`                | Projects                             |
| `<leader>ph`                | Help tags                            |
| `H` / `L`                   | Previous/next buffer                 |
| `<leader>bd`                | Delete buffer                        |
| `<leader>bk`                | Delete buffer                        |
| `<leader>bK`                | Delete all buffers                   |
| `<leader>bo`                | Delete other buffers                 |
| `<leader>bp` / `<leader>bn` | Previous/next buffer                 |
| `<leader>bs`                | Save buffer                          |

## Code, LSP, And Diagnostics

LSP capabilities include folding ranges so `nvim-ufo` can use server-provided folds when available.

| Key          | Mode          | Action                       |
| ------------ | ------------- | ---------------------------- |
| `K`          | normal        | LSP hover                    |
| `gd` / `gD`  | normal        | Go to definition/declaration |
| `gi`         | normal        | Go to implementation         |
| `gr`         | normal        | References                   |
| `<leader>ca` | normal/visual | Code action                  |
| `<leader>cA` | normal        | Source action                |
| `<leader>cc` | normal/visual | Run codelens                 |
| `<leader>cC` | normal        | Refresh codelens             |
| `<leader>cd` | normal        | Line diagnostics             |
| `<leader>cf` | normal        | Format                       |
| `<leader>cl` | normal        | LSP info                     |
| `<leader>cr` | normal        | Rename                       |
| `<leader>ch` | normal        | Clangd switch source/header  |
| `<leader>cI` | normal        | Clangd symbol info           |
| `[d` / `]d`  | normal        | Previous/next diagnostic     |

## Folding

Most file buffers use `nvim-ufo` with Tree-sitter or LSP folds and indentation fallback. Fold markers appear beside line numbers. Piped git diffs, including `git diff | nvim -`, use diff-aware folds for file sections and hunks.

| Key | Action          |
| --- | --------------- |
| `zR` | Open all folds  |
| `zM` | Close all folds |
| `za` | Toggle fold     |
| `zj` | Next fold       |
| `zk` | Previous fold   |

Trouble:

| Key          | Action                                 |
| ------------ | -------------------------------------- |
| `<leader>xx` | Toggle diagnostics                     |
| `<leader>xX` | Toggle buffer diagnostics              |
| `<leader>cs` | Symbols                                |
| `<leader>cS` | LSP references/definitions             |
| `<leader>xL` | Location list                          |
| `<leader>xQ` | Quickfix list                          |
| `<leader>xt` | Todo comments                          |
| `<leader>xT` | TODO/FIX/FIXME comments                |
| `[q` / `]q`  | Previous/next Trouble or quickfix item |

Todo comments:

| Command         | Action                                              |
| --------------- | --------------------------------------------------- |
| `:TodoTrouble`  | Show tagged comments in Trouble                     |
| `:TodoQuickFix` | Populate quickfix with tagged comments              |
| `:TodoLocList`  | Populate the location list with tagged comments     |
| `:TodoTelescope` | Search tagged comments with Telescope, if available |

Highlighted tags include `TODO`, `FIX`, `FIXME`, `HACK`, `WARN`, `NOTE`, `PERF`, and `TEST`.

## Copilot

Copilot inline suggestions are provided by `github/copilot.vim`. Run `:Copilot setup` after installation to authenticate.

| Key          | Mode   | Action                      |
| ------------ | ------ | --------------------------- |
| `<C-l>`      | insert | Accept Copilot suggestion   |
| `<M-]>`      | insert | Next Copilot suggestion     |
| `<M-[>`      | insert | Previous Copilot suggestion |
| `<M-\>`      | insert | Request Copilot suggestion  |
| `<C-]>`      | insert | Dismiss Copilot suggestion  |

`<Tab>` is intentionally not used by Copilot so it does not conflict with completion.
The `github/copilot.vim` panel command is intentionally left unmapped because it can lock up Neovim in this setup.

## Codex

Codex is provided by `dukjjang/codex-cli.nvim` and requires the Codex CLI to be installed and authenticated separately.
When Neovim is running inside tmux, prompts are sent to an existing Codex CLI pane when one is found; otherwise Codex opens in a right-side terminal split.
The Codex overlay keeps its panel opaque without blacking out the editor around it.

| Key          | Mode          | Action                                                   |
| ------------ | ------------- | -------------------------------------------------------- |
| `<leader>aa` | normal/visual | Ask Codex with current-file or selected-line context     |
| `<leader>at` | normal        | Toggle the fallback Codex terminal split                 |

## Markdown And Notes

| Key            | Mode   | Action                             |
| -------------- | ------ | ---------------------------------- |
| `<leader>mdt`  | normal | Insert current date                |
| `<leader>mt`   | visual | Capitalize each word in selection  |
| `<leader>nn`   | normal | New Obsidian note                  |
| `<leader>nn`   | visual | Extract selection to Obsidian note |
| `<leader>no`   | normal | Obsidian options                   |
| `<leader>nrdt` | normal | Open today's Obsidian note         |
| `<leader>nrdy` | normal | Open yesterday's Obsidian note     |
| `<leader>nrf`  | normal | Obsidian quick switch              |
| `<leader>nrr`  | normal | Obsidian backlinks                 |
| `<leader>nrl`  | normal | Obsidian links                     |
| `<leader>nrp`  | normal | Start Obsidian presentation        |
| `<leader>nrt`  | normal | Obsidian tags                      |
| `<CR>`         | normal | Open external Markdown link under cursor; otherwise use Obsidian/normal Enter fallback |

Markdown support includes render-markdown, Obsidian integration, Markdown keymaps, external link opening, and frontmatter timestamp automation. Obsidian checkbox smart actions are disabled, while wiki-link and note navigation smart actions remain available through the `<CR>` fallback.

render-markdown custom checkbox states:

| State | Meaning                  | Rendered style              |
| ----- | ------------------------ | --------------------------- |
| `[!]` | Important item           | Warning icon and bold text  |
| `[>]` | Currently being worked   | Hourglass icon and blue text |
| `[~]` | Deferred or not relevant | Muted icon and strikethrough |
| `[?]` | Question or uncertainty  | Question icon and orange text |

## Navigation

Tmux navigation uses `vim-tmux-navigator`:

| Key     | Action            |
| ------- | ----------------- |
| `<C-h>` | Navigate left     |
| `<C-j>` | Navigate down     |
| `<C-k>` | Navigate up       |
| `<C-l>` | Navigate right    |
| `<C-\>` | Navigate previous |

## Main Plugins

- `folke/lazy.nvim`: plugin manager.
- `folke/tokyonight.nvim`: colorscheme.
- `folke/snacks.nvim`: explorer, picker, recent files, projects, grep, select UI.
- `folke/which-key.nvim`: keymap discovery.
- `nvim-mini/mini.icons`: icons and devicons compatibility.
- `nvim-mini/mini.pairs`: autopairs.
- `nvim-mini/mini.ai`: text objects.
- `nvim-mini/mini.surround`: surround operations.
- `saghen/blink.cmp`: completion.
- `neovim/nvim-lspconfig`: LSP setup.
- `mason-org/mason.nvim`: external tool installer.
- `mason-org/mason-lspconfig.nvim`: LSP server install/enable integration.
- `nvim-treesitter/nvim-treesitter`: highlighting and indentation.
- `kevinhwang91/nvim-ufo`: broad folding support.
- `kevinhwang91/promise-async`: async dependency for `nvim-ufo`.
- `stevearc/conform.nvim`: formatting.
- `folke/trouble.nvim`: diagnostics, symbols, quickfix/location list UI.
- `folke/todo-comments.nvim`: highlights and lists tagged comments.
- `j-hui/fidget.nvim`: LSP progress and notifications.
- `dukjjang/codex-cli.nvim`: tmux-aware Codex CLI prompting with terminal fallback.
- `nvim-lualine/lualine.nvim`: statusline.
- `github/copilot.vim`: GitHub Copilot inline suggestions.

## Language Servers

Configured LSP servers include:

- `clangd`
- `codebook`
- `harper_ls`
- `lua_ls`
- `marksman`
- `omnisharp`
- `ts_ls`

## Options

Notable defaults:

- Line numbers and relative numbers enabled.
- Mouse enabled.
- System clipboard via `unnamedplus`.
- Wrapped lines use `linebreak` and `breakindent`.
- Persistent undo enabled.
- Splits open right and below.
- Folds open by default with a compact unpadded line-number and fold-marker column and broad fold providers.
- Global indentation defaults to 4 spaces with `expandtab`, `softtabstop`, `autoindent`, and `smartindent`.
- Spell checking enabled with custom spellfile.
