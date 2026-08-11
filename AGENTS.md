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
