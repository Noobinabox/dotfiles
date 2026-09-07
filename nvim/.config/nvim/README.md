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
- `lua/notebook/`: local edit-only `.ipynb` rendering and save support.
- `lua/org_tasks/`: local Org TODO, checkbox, and statistics-cookie helpers.
- `scripts/test-notebook.lua`: notebook round-trip regression test.
- `scripts/test-org-tasks.lua`: Org TODO and checkbox regression test.
- `.clang-format`: C/C++ formatting standard.
- `.prettierrc.json`: Prettier formatting standard.
- `.eslintrc.json`: JavaScript/TypeScript fix rules used before Prettier.
- `.csharpierrc.json`: CSharpier formatting standard.
- `lazy-lock.json`: plugin lockfile.

## Validation Commands

Run from this directory:

```sh
luac -p init.lua lua/config/*.lua lua/plugins/*.lua lua/notebook/*.lua lua/org_tasks/*.lua scripts/test-notebook.lua scripts/test-org-tasks.lua
nvim --headless "+lua print('startup-ok')" +qa
nvim --headless -S scripts/test-notebook.lua +qa
nvim --headless -S scripts/test-org-tasks.lua +qa
nvim --headless "+lua print(vim.g.colors_name or 'no-colorscheme')" +qa
nvim --headless "+checkhealth nvim-treesitter mason obsidian orgmode" +qa
tmp_org="$(mktemp -d)" && mkdir -p "$tmp_org/roam/daily" && printf '#+TITLE: Smoke\n' > "$tmp_org/roam/daily/smoke.org" && ORG_DIRECTORY="$tmp_org" ORG_ROAM_DIRECTORY="$tmp_org/roam" nvim --headless "$tmp_org/roam/daily/smoke.org" "+RoamUpdate sync" "+lua for _, lhs in ipairs({ '<leader>oa', '<leader>oc', '<leader>ou', '<leader>oU', '<leader>oXt', '<C-Space>', '<leader>oXa', '<leader>oXi', '<leader>oXr', '<leader>oXo', '<leader>ozc', '<leader>ozf', '<leader>oz.', '<leader>ozn', '<leader>ozp', '<leader>ozi', '<leader>ozm', '<leader>ozl', '<leader>ozb', '<leader>ozq', '<leader>ozd.', '<leader>ozdn', '<leader>ozdy', '<leader>ozdt', '<leader>ozdd', '<leader>ozdf', '<leader>ozdb', '<leader>ozdN', '<leader>ozdY', '<leader>ozdT', '<leader>ozdD' }) do local m = vim.fn.maparg(lhs, 'n', false, true); assert(m and m.desc and m.desc ~= '', lhs) end; for _, lhs in ipairs({ '<leader>oXa', '<leader>oXi' }) do local m = vim.fn.maparg(lhs, 'x', false, true); assert(m and m.desc and m.desc ~= '', lhs) end" +qa
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
- The default colorscheme is `tokyonight-night` from `folke/tokyonight.nvim`, with `habamax` as the emergency built-in fallback.

| Key                | Mode                 | Action                                  |
| ------------------ | -------------------- | --------------------------------------- |
| `<leader><leader>` | normal               | Find files from current working directory |
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
| `<leader>wz`       | normal               | Toggle current window zoom              |
| `<C-w>z`           | normal               | Toggle current window zoom              |
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
| `<leader>mdt`  | normal | Insert current date link           |
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

## Org And Org Roam

Org files are supported with `nvim-orgmode/orgmode`, and roam-style notes are
supported with `chipsenkbeil/org-roam.nvim`. The Neovim configuration mirrors
the Doom Emacs Org layout:

- Org directory: `~/org`
- Roam directory: `~/org/roam`
- Roam dailies directory: `~/org/roam/daily`
- Agenda files: `inbox.org`, `projects.org`, `someday.org`, `tickler.org`,
  and roam dailies under `~/org/roam/daily/*.org`

Set `ORG_DIRECTORY` or `ORG_ROAM_DIRECTORY` before launching Neovim to override
those paths for a one-off session.

| Key            | Mode          | Action                         |
| -------------- | ------------- | ------------------------------ |
| `<leader>oa`   | normal        | Org agenda prompt              |
| `<leader>oc`   | normal        | Org capture prompt             |
| `<leader>ou`   | normal (org)  | Update statistics cookie near cursor |
| `<leader>oU`   | normal (org)  | Update all statistics cookies in file |
| `<leader>oXt`  | normal (org)  | Toggle checkbox at cursor      |
| `<C-Space>`    | normal (org)  | Toggle checkbox at cursor      |
| `<leader>oXa`  | normal/visual (org) | Add or remove checkbox markers |
| `<leader>oXi`  | normal/visual (org) | Force checkbox to intermediate state |
| `<leader>oXr`  | normal (org)  | Toggle radio behavior for a checkbox list |
| `<leader>oXo`  | normal (org)  | Toggle `:ORDERED: t` for checkbox order |
| `<C-c><C-c>`   | normal (org)  | Context action for checkbox/cookie/link |
| `<C-c>#`       | normal (org)  | Update statistics cookie near cursor |
| `<leader>ozc`  | normal/visual | Org-roam capture               |
| `<leader>ozf`  | normal/visual | Org-roam find node with Snacks |
| `<leader>oz.`  | normal (org)  | Complete text to roam link     |
| `<leader>ozi`  | normal/visual (org) | Org-roam insert node     |
| `<leader>ozm`  | normal/visual (org) | Org-roam insert node immediate |
| `<leader>ozn`  | normal (org)  | Go to next origin-linked node  |
| `<leader>ozp`  | normal (org)  | Go to previous origin-linked node |
| `<leader>ozl`  | normal (org)  | Toggle Org-roam buffer         |
| `<leader>ozb`  | normal (org)  | Toggle fixed Org-roam buffer   |
| `<leader>ozq`  | normal (org)  | Org-roam backlinks quickfix    |
| `<leader>ozd.` | normal        | Open roam dailies directory    |
| `<leader>ozdn` | normal        | Go to today's roam daily       |
| `<leader>ozdy` | normal        | Go to yesterday's roam daily   |
| `<leader>ozdt` | normal        | Go to tomorrow's roam daily    |
| `<leader>ozdd` | normal        | Go to roam daily by date       |
| `<leader>ozdf` | normal        | Go to next available roam daily |
| `<leader>ozdb` | normal        | Go to previous available roam daily |
| `<leader>ozdN` | normal        | Capture today's roam daily     |
| `<leader>ozdY` | normal        | Capture yesterday's roam daily |
| `<leader>ozdT` | normal        | Capture tomorrow's roam daily  |
| `<leader>ozdD` | normal        | Capture roam daily by date     |

In the `<leader>ozf` Snacks picker, chained tag searches such as
`:docs:genie:` match nodes that have both tags. The picker row stays focused on
the node title, aliases, and tags; file paths are searchable but not shown.
For normal text searches that do not exactly match an existing title or alias,
the picker shows a `Create node:` row; press `<CR>` on that row to create it, or
press `<C-y>` to create from the current search text.

Statistics cookies support checkbox counts such as `[1/3]`, checkbox
percentages such as `[33%]`, TODO child-heading counts, `:COOKIE_DATA:
checkbox`, `:COOKIE_DATA: todo`, and recursive TODO variants through
`:COOKIE_DATA: todo recursive`. Checkbox cookies follow Emacs Org behavior and
count the direct checklist owned by the heading, including when
`:COOKIE_DATA: checkbox recursive` is present. Radio checkbox lists use
`#+ATTR_ORG: :radio t` immediately before the list. Ordered checkbox lists use
`:ORDERED: t` in the nearest heading property drawer.

Use `:RoamUpdate` to refresh the roam database manually if needed. Root-level
Org files included in the roam graph may require a manual update after edits.
Org-roam capture creates the Org ID in file content first; after the first save,
this config renames new non-daily roam files to the `ID-title.org` filename
convention. Daily files keep date-based names because the dailies extension uses
those names for date navigation.
Converted Obsidian callouts use custom Org blocks such as
`#+begin_callout note Title` and `#+end_callout`; Neovim conceals the Org block
markers behind a render-markdown-style quote bar and callout label.
Org buffers start with headings expanded and property drawers folded. They use
`linebreak` and `breakindent` with a small visual offset so soft-wrapped text
follows the current heading or list indentation without an extra continuation
prefix. Org `+` list bullets are displayed with Doom's org-superstar `➤` glyph
and rotate colors by nesting depth while the file text remains normal Org syntax.
Bold, italic, code, and verbatim delimiters are concealed in Org buffers the
same way Org links hide their raw link target syntax.
Saving an Org file updates the file-level `:UPDATED:` property in the top
property drawer, preserving the existing timestamp format when one is present.
Converted checkbox states use global Org TODO keywords, including `IMPORTANT`,
`NEEDS_ATTENTION`, `CURRENTLY_WORKING`, and `ABANDONED`, in the Neovim Org
config, so converted notes do not need per-file `#+TODO:` keyword declarations.

To stage an Obsidian vault conversion without touching live Org files, run
`scripts/convert-vault-to-org.py` from the dotfiles repo. It writes to
`/home/seth/org-converted` and prefixes Org filenames with generated Org IDs.
The converter writes all Org files and the ID ledger first, then performs a
second pass that rewrites Obsidian wikilinks from the ledger mapping.
Frontmatter aliases become `#+ROAM_ALIASES:`, tags become `#+filetags:`, and
`created` / `updated` become Org file properties. Heading `:CUSTOM_ID:` drawers
are only added for headings targeted by Obsidian heading links. Markdown inline
code, bold, italic, HTML underline, and strike-through convert to Org inline markup.
Markdown `[text](url)`, `[text][ref]`, `[ref][]`, and shortcut `[ref]` links
with `[ref]: url` definitions, plus `<scheme:...>` and `<user@example.com>`
autolinks, become Org links. Markdown `-`, `*`, and `+` unordered list markers
normalize to Org `+` bullets. Markdown thematic breaks are dropped. Markdown
tables are width-aligned and separators become Org hlines with column
separators.
It records source-to-ID mappings plus unresolved or ambiguous Obsidian wikilinks
and unresolved explicit or collapsed Markdown reference links in
`conversion-ledger.md`; unresolved shortcut `[ref]` links are not reported to
avoid false positives for ordinary bracketed text. Wikilink alias labels are
preserved as written so display text stays stable during migration. Markdown
image links and Obsidian embeds remain unchanged.

Built-in Org buffer mappings and Org-roam subgroups also appear under
`<leader>o`:

| Prefix       | Actions                         |
| ------------ | ------------------------------- |
| `<leader>ob` | Babel actions such as tangle    |
| `<leader>oi` | Insert heading, dates, schedule |
| `<leader>ol` | Store and insert Org links      |
| `<leader>on` | Add Org notes                   |
| `<leader>ox` | Clock and effort actions        |
| `<leader>oX` | Checkbox and statistics actions |
| `<leader>oza` | Org-roam alias actions         |
| `<leader>ozo` | Org-roam origin actions        |

## Python Notebooks

Opening an `.ipynb` file shows an editable Python percent-cell buffer instead
of raw notebook JSON. Code, Markdown, and raw cells are shown as blocked-off
notebook cells with top and bottom borders, cell-edge row borders, cell
labels, and padded content so the editable text does not collide with the border
chrome. Markdown cells stay stored as Python comments so Python tooling does
not treat prose as code, with notebook-local conceal/highlighting for headings,
inline code, bold, emphasis, links, fenced code blocks, and horizontal rules.
The underlying `# %% [markdown]` marker remains available for round-tripping
back to valid notebook JSON.

Saving the buffer writes valid notebook JSON back to the same file while
preserving existing notebook metadata, cell metadata, code outputs, and
execution counts. Missing or empty notebook files are initialized with a valid
Python notebook structure. Malformed notebooks open as raw JSON so they can be
repaired without silently overwriting their contents.

This is an edit-only workflow. It does not run cells, connect to a Jupyter
kernel, render outputs, or require Jupytext.

| Key          | Mode   | Action                              |
| ------------ | ------ | ----------------------------------- |
| `<leader>jc` | normal | Insert notebook code cell below     |
| `<leader>jC` | normal | Insert notebook code cell above     |
| `<leader>jm` | normal | Insert notebook Markdown cell below |
| `<leader>jM` | normal | Insert notebook Markdown cell above |
| `<leader>jr` | normal | Insert notebook raw cell below      |
| `<leader>jR` | normal | Insert notebook raw cell above      |
| `<leader>jJ` | normal | Open raw notebook JSON scratch view |

Notebook commands:

| Command                      | Action                         |
| ---------------------------- | ------------------------------ |
| `:NotebookCodeCell`          | Insert notebook code cell below |
| `:NotebookCodeCellAbove`     | Insert notebook code cell above |
| `:NotebookMarkdownCell`      | Insert notebook Markdown cell below |
| `:NotebookMarkdownCellAbove` | Insert notebook Markdown cell above |
| `:NotebookRawCell`           | Insert notebook raw cell below |
| `:NotebookRawCellAbove`      | Insert notebook raw cell above |
| `:NotebookRawJson`           | Open raw notebook JSON scratch |

The visible notebook buffer uses `filetype=python`, so Python highlighting,
completion, Pyright, and folding apply to code-oriented editing.

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
- `szw/vim-maximizer`: split zoom toggle.
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
- Local notebook plugin: clean edit-only `.ipynb` buffers backed by notebook JSON.
- `folke/trouble.nvim`: diagnostics, symbols, quickfix/location list UI.
- `folke/todo-comments.nvim`: highlights and lists tagged comments.
- `j-hui/fidget.nvim`: LSP progress and notifications.
- `dukjjang/codex-cli.nvim`: tmux-aware Codex CLI prompting with terminal fallback.
- `nvim-lualine/lualine.nvim`: statusline.
- `nvim-orgmode/orgmode`: Org editing, agenda, capture, TODOs, links, and folds.
- `chipsenkbeil/org-roam.nvim`: Org-roam node navigation, capture, backlinks, and dailies.
- `github/copilot.vim`: GitHub Copilot inline suggestions.

## Language Servers

Configured LSP servers include:

- `clangd`
- `codebook`
- `harper_ls`
- `lua_ls`
- `marksman`
- `omnisharp`
- `pyright`
- `tintin_lsp`
- `ts_ls`

`pyright` provides Python completion, hover, references, diagnostics, and type
information. Its root detection includes common Python project files such as
`requirements.txt`, so single-file Pulumi Python projects attach at the project
root. If imports remain unresolved, check the active Python interpreter or
Pyright path settings separately.

`ts_ls` starts `tsserver` with a 6144 MB Node heap so large TypeScript projects,
including Pulumi infrastructure repos, are less likely to hit the default V8
heap limit while loading references and type information.

`tintin_lsp` is a local Node.js stdio language server for TinTin++ scripts. It
is packaged in `tintin-lsp/`, exposed locally through
`tools/.local/bin/tintin-lsp`, is not managed by Mason, and provides
parser-backed diagnostics, document formatting, symbol rename, command
completions, document-derived variable/function completions, hover
documentation, quick-fix code actions, document symbols, workspace symbols,
folding ranges, document links, definitions, and references for the `tintin`
filetype.
Diagnostics are heuristic and rename is limited to variable/function-style
symbols, so the local server does not replace TinTin++ runtime validation.
Protocol regressions are covered by `npm test --prefix tintin-lsp`, and that
test is included in `scripts/check.sh` through `node scripts/test-tintin-lsp.js`.

## Language Syntax

TinTin++ scripts ending in `.tintin`, `.tt`, or `.tt++` are detected as the
`tintin` filetype and use local Vim syntax highlighting for common commands,
variables, parameters, comments, braces, command separators, strings, numbers,
and escapes.

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
