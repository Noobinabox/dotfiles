# Repository Guidelines

## Project Structure & Module Organization

This repository is the source of truth for personal dotfiles managed with GNU
Stow. Each top-level config directory is a stow package whose contents mirror
the target path under `$HOME`.

- `shell/`: zsh, bash, aliases, profile files, and Powerlevel10k config.
- `nvim/`, `doom/`, `tmux/`: editor and terminal application configs.
- `tools/`: shared CLI/tool configs such as Yazi, Glow, GitHub CLI, Codex,
  htop, and bpytop.
- `git/` and `npm/`: Git and npm config.
- `systemd/`: user-level auto-sync service and timer.
- `scripts/`: install, validation, sync, and secret-management helpers.
- `secrets/`: tracked GPG-encrypted secret files only.

## Build, Test, and Development Commands

- `scripts/check.sh`: simulate stow for every package and scan tracked files
  for plaintext secrets.
- `scripts/convert-vault-to-org.py`: convert `/home/seth/vault` Markdown notes
  into an Org-roam-style output tree at `/home/seth/org-converted`. Use
  `--force` only to replace that generated output tree. The converter stages
  output only; it does not change live Org files. It writes all converted files
  and the ID ledger first, then performs a second pass that resolves Obsidian
  wikilinks into Org links from the ledger mapping. Converted Org filenames are
  prefixed with their generated Org IDs. Frontmatter aliases become
  `#+ROAM_ALIASES:`, tags become
  `#+filetags:`, and `created` / `updated` become Org file properties.
  Converted checkbox states rely on the global Neovim Org TODO keyword setup;
  the converter should not emit per-file `#+TODO:` keyword declarations.
  Heading `:CUSTOM_ID:` drawers are only added for headings targeted by
  Obsidian heading links.
  Markdown inline code, bold, italic, HTML underline, and strike-through are
  converted to Org inline markup. Markdown `[text](url)`, `[text][ref]`,
  `[ref][]`, and shortcut `[ref]` links with `[ref]: url` definitions, plus
  `<scheme:...>` and `<user@example.com>` autolinks, are converted to Org
  links. Markdown `-`, `*`, and `+` unordered list markers normalize to Org `+`
  bullets. Markdown thematic breaks are dropped. Markdown
  tables are width-aligned and separators become Org hlines with column
  separators. Unresolved or
  ambiguous Obsidian wikilinks and unresolved explicit or collapsed Markdown
  reference links are reported in `conversion-ledger.md`; unresolved shortcut
  `[ref]` links are not reported to avoid false positives for ordinary
  bracketed text. Wikilink alias labels are preserved as written so display
  text stays stable during migration. Markdown image links and Obsidian embeds
  remain unchanged.
- `scripts/test-convert-vault-to-org.sh`: focused regression test for the vault
  conversion contract.
- `scripts/install.sh`: back up unmanaged files, then stow all packages into `$HOME`.
- `scripts/install.sh shell`: stow one package during focused changes.
- `./setup.sh --check`: report missing external tools without installing them.
- `./setup.sh --stow`: bootstrap dependencies, then run the stow installer.

Run `scripts/check.sh` before committing any dotfile or script change.

## Coding Style & Naming Conventions

Shell scripts use Bash with `set -euo pipefail`, lowercase function names,
descriptive variables, and quoted expansions. Keep reusable display helpers in
`scripts/lib/`. Prefer package names that match the managed tool, such as
`shell`, `tmux`, or `tools`. Preserve stow path mirroring: for example,
`tools/.config/yazi` maps to `~/.config/yazi`.

Use `shellcheck` and `shfmt` for shell changes when available.

## Testing Guidelines

There is no separate test suite. Validation is operational: run
`scripts/check.sh` for every change, and run targeted commands for affected
tools, such as `zsh -lic 'source ~/.zshrc'`,
`tmux source-file ~/.config/tmux/tmux.conf`, or
`YAZI_CONFIG_HOME="$PWD/tools/.config/yazi" ya pkg install`.

## Commit & Pull Request Guidelines

Recent history uses automated messages like
`Auto-sync dotfiles 2026-08-10 10:05:15 CDT`. For manual commits, use short
imperative summaries, for example `Update tmux status config`.

Pull requests should include the changed package, why the config changed,
validation performed, and any recovery or migration notes. Include screenshots
only for visible UI changes.

## Security & Configuration Tips

Never commit plaintext tokens, passwords, OAuth data, or generated auth
databases. Runtime secret files live outside the repo; only `secrets/*.gpg`
should be tracked. Before adding new config, scan with
`rg -n --hidden -i 'token|secret|password|oauth|api[_-]?key' path/to/file`.
