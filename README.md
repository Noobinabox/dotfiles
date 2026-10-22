# Dotfiles

```text
         _       _      __ _ _
      __| | ___ | |_   / _(_) | ___  ___
     / _` |/ _ \| __| | |_| | |/ _ \/ __|
    | (_| | (_) | |_  |  _| | |  __/\__ \
     \__,_|\___/ \__| |_| |_|_|\___||___/

        one repo  |  many tools  |  stow links
```

This repository is the source of truth for my personal dotfile configuration.
It uses [GNU Stow](https://www.gnu.org/software/stow/) to symlink files from
this repo into `$HOME`, so configuration can be versioned here while tools still
read their normal paths.

## Quick Start

```sh
cd ~/repos/personal/dot-files
scripts/check.sh
scripts/decrypt-secrets.sh
scripts/install.sh
exec zsh -l
```

```text
repo package path              stow link target
─────────────────────────────  ─────────────────────────
shell/.zshrc                   ~/.zshrc
nvim/.config/nvim/init.lua     ~/.config/nvim/init.lua
tmux/.config/tmux/tmux.conf    ~/.config/tmux/tmux.conf
tools/.config/yazi             ~/.config/yazi
tools/.config/spotify-player   ~/.config/spotify-player
tools/.config/mud-client       ~/.config/mud-client
tools/.codex/*.md              ~/.codex/*.md
```

## What This Manages

The repo is organized as stow packages:

- `shell`: zsh, bash, shared aliases/functions, profile files, and Powerlevel10k
- `npm`: npm config with credentials supplied by environment variables
- `git`: Git config
- `nvim`: Neovim config
- `doom`: personal Doom Emacs config
- `tmux`: tmux config
- `tools`: small CLI/tool configs such as `glow`, `yazi`, `spotify-player`,
  `htop`, `bpytop`, `harper-ls`, GitHub CLI config, Angular config, and Codex
  config and instructions, plus MUD client config, Lua scripts, and character profiles
- `systemd`: user service and timer for automatic dotfiles sync
- `secrets`: encrypted secret env files and SSH keys

Generated state, caches, histories, auth databases, plugin installs, and nested
Git metadata are intentionally excluded.

```text
tracked here          encrypted here         kept out
────────────          ──────────────         ────────
dotfiles              secrets/*.gpg          caches
editor config         shell.env.gpg          auth DBs
tool config           npm.env.gpg            histories
```

## First-Time Setup

Install the baseline tools needed to run the dotfiles installer:

```sh
sudo apt install stow gpg
```

Clone this repository, then preview what stow will do:

```sh
cd ~/repos/personal/dot-files
scripts/check.sh
```

Decrypt secrets before opening a normal shell if you need private registries,
Databricks, or other secret-backed commands:

```sh
scripts/decrypt-secrets.sh
```

Apply the symlinks:

```sh
scripts/install.sh
```

`scripts/install.sh` backs up existing non-symlink files to
`~/.dotfiles-backup/<timestamp>/` before running stow.

Bootstrap applications used by the managed configs:

```sh
./setup.sh --check
./setup.sh
```

On Debian or Ubuntu, Yazi comes from its upstream apt repository on this
machine. Add that source before running `./setup.sh` if `apt install yazi` is
not available yet:

```sh
curl -fsSL https://yazi-rs.github.io/builds/yazi-keyring.gpg | sudo tee /usr/share/keyrings/yazi-keyring.gpg >/dev/null
echo 'deb [signed-by=/usr/share/keyrings/yazi-keyring.gpg] https://yazi-rs.github.io/builds/ stable main' | sudo tee /etc/apt/sources.list.d/yazi.list >/dev/null
sudo apt update
```

To bootstrap dependencies and stow configs in one run:

```sh
./setup.sh --stow
```

`setup.sh` detects Linux, Fedora, WSL, macOS, Windows, and Termux environments.
Fedora uses its native `dnf` package manager. WSL uses the
Linux package manager for Linux tools and expects Windows Terminal (`wt.exe`)
for the native terminal. When run from Windows, system packages are left to
the native Windows setup (for example, `winget`) instead of trying to install
Linux packages or requiring Alacritty. Termux uses its native `pkg` package
manager and does not download desktop Linux binaries.

## Daily Use

After changing config in this repo, run:

```sh
scripts/check.sh
scripts/test-setup-platforms.sh
```

Reload shell config:

```sh
exec zsh -l
```

Apply a specific package only:

```sh
scripts/install.sh shell
scripts/install.sh nvim
scripts/install.sh tools
```

Inspect managed links:

```sh
find ~ -maxdepth 3 -type l -lname '*dot-files*' -print
```

## Package Commands

Shell package helpers are distro-aware. On this machine they resolve to `apt`,
but the same commands also support `dnf`, `pacman`, `zypper`, and `apk`:

```sh
update
upgrade
search ripgrep
install ripgrep
remove ripgrep
```

`setup.sh` sources the same helpers and installs system packages through the
shared `install` implementation. Tool-specific ecosystems still use their own
installers: NVM for Node, npm for global JavaScript CLIs, rustup for Rust,
Mason for Neovim LSP/formatter tools, Doom for Emacs packages, and TPM for tmux
plugins.

The `install` shell function intentionally shadows the coreutils file-copy
utility. Use `command install ...` when you need the coreutils command.

Lazygit and Sesh are installed into `~/.local/bin` from pinned upstream releases
with SHA256 verification on Linux, WSL, Fedora, and macOS. Termux builds the
pinned versions with Go; Windows uses its native package manager. Existing
executables on `PATH` are kept. To install only these two tools:

```sh
bash scripts/install-tui-tools.sh
```

Use `--check` to report missing tools without downloading or installing.
Set `DOTFILES_TUI_BIN_DIR` to override the default installation directory.

## Git and Project Sessions

Run `lg` (or `lazygit`) inside a Git repository to review changes, stage selected
lines, and manage branches. In tmux, `Ctrl-a g` opens Lazygit in a popup rooted
at the current pane's directory.

Sesh uses the existing zoxide history and tmux sessions to switch projects.
Press `Ctrl-a T` in tmux to open its session picker, or run `sesh picker`.
Selecting a project connects to its session, creating one when needed.
Use `sesh connect /path/to/project` to open a project directly.

After applying these dotfiles, restart your shell for `lg` and reload tmux with
`tmux source-file ~/.config/tmux/tmux.conf` for the popup bindings.

## Workspace Recovery After Reboot

Tmux Resurrect saves sessions, windows, pane layouts, and working directories.
Continuum saves automatically every five minutes and restores the last snapshot
when the first tmux server starts. After rebooting, start `tmux`, then use Sesh
to switch projects. Both `Ctrl-a s` and `Ctrl-a Ctrl-s` open the session picker;
manual save has no shortcut. Manual restore is `Ctrl-a`, then `Ctrl-r`.

Neovim uses its native session files to save open files, splits, tabs, and cursor
positions every minute, after file writes, on focus loss, and when exiting.
Starting `nvim` without file arguments restores the saved workspace for the
current directory and tmux session/window/pane. Explicit file arguments open
normally. `<Space>qs` saves and `<Space>qr` restores manually. In already-open
Neovim instances, run `:lua require("config.sessions").setup()` once, then
`<Space>qs` to capture the current layout. New instances enable saving at startup.

Editor snapshots stay under Neovim's state directory (`~/.local/state/nvim/sessions`
by default), outside Git projects. Tmux snapshots stay in Resurrect's local data
directory. Save file changes before rebooting: snapshots preserve layout and
filenames, not unsaved text or process memory. Configured applications restart;
running tests, servers, and network connections do not resume execution.

The tmux plugin loader runs after the palette, and theme application reloads
the full tmux configuration to preserve Continuum's status-line save hook.

## File Navigation

`vf` is the fast file launcher. It searches files recursively, including hidden
files, from the current directory with `fzf`, while still respecting ignore
rules when `fd` is available. It previews the highlighted file, then opens the
selected file or files with the action you choose.

```sh
vf
vf README
vf --edit init.lua
vf --view notes
vf --explore package
vf --help
```

Preview behavior:

- Markdown files use Glow with the active managed theme style.
- Other files use `batcat` or `bat` when available.
- Plain `sed` output is the fallback.

Selection behavior:

- Press `Enter` to accept the highlighted file.
- Press `Tab` to toggle multiple file selections.
- Press `Esc` to cancel without doing anything.

Actions:

- `edit`: opens all selected files in one Neovim process.
- `view`: opens all selected files read-only with `nvim -R`.
- `explore`: opens Yazi with the first selected file highlighted.

`vf --explore` intentionally uses the first selected file as Yazi's starting
entry. Once Yazi is open, use its own Vim-style selection workflow:

- `h`/`j`/`k`/`l`: parent/down/up/enter
- `gg`/`G`: top/bottom
- `/`, `n`, `N`: find and move between matches
- `v`: visual selection mode
- `V`: toggle the hovered file
- `yy`: yank selected files
- `dd`: cut selected files
- `p`: paste yanked files
- `ge`: open the hovered file with the default opener
- `gv`: view the hovered file read-only with `nvim -R`
- `go`: choose an opener for the hovered file

Yazi is the richer file browsing and management layer. Its config is stowed
from `tools/.config/yazi` to `~/.config/yazi`, uses Vim-style navigation, and
loads the active managed theme flavor. Restore managed Yazi packages and
flavors with:

```sh
scripts/install.sh tools
ya pkg install
```

To restore the Yazi packages against the repo config without stowing first:

```sh
YAZI_CONFIG_HOME="$PWD/tools/.config/yazi" ya pkg install
```

## Themes

Theme definitions live in `themes/`. Generate app-specific theme files, then
apply one theme across the supported repo configs:

```sh
scripts/generate-themes.py --write
scripts/apply-theme.sh
```

Tmux inactive tabs use the theme foreground on its background so labels remain
readable in light themes. The selected tab uses the theme's blue accent.
The generated palette also owns the session label, directory display, menus,
popups, and copy/window-picker selections. Picker selections use the palette's
selection background rather than its yellow accent. Tokyo Night's tmux theme
plugin is no longer loaded, so its hard-coded colors cannot override the palette.

The theme selector also generates a Codex syntax theme and sets `tui.theme` to
`dotfiles-current`, preserving other Codex settings. Code, diffs, and displayed
commands use the selected palette. Stow the `tools` package once after adding
this integration to link `~/.codex/themes`. Restart Codex after switching themes,
or use `/theme` to select `dotfiles-current` in the running session.
Added and removed diff lines use subtle palette-derived background tints so
light syntax colors do not fall back to dark red/green blocks. Light themes
use the dim foreground for comments to keep them readable over diff tints.

Spotify Player, bpytop, bat (including `vf` previews), and Powerlevel10k also
use generated palettes. The selector rebuilds bat's theme cache when installed
and selects htop's light-terminal or default scheme according to the background.
Other settings in Spotify Player, bpytop, htop, and Codex are preserved.
Stow `tools` once to link the new bat and app theme files. Restart running apps
and editors after changing themes; reload the zsh prompt with `exec zsh -l`.

Kitty is also Stow-managed at `~/.config/kitty/kitty.conf` and shares the
Alacritty-style font, padding, opacity, cursor, bell, and generated 16-color
palette settings. Kitty is skipped from Termux package checks because it is a
desktop terminal rather than a Termux-native package.

The picker uses `fzf` when available and falls back to a numbered shell prompt.
It lists repository themes and pywal16 built-in themes. Selecting a pywal16
theme creates `themes/pywal-<theme>.json` first if that repo theme does not
exist yet, then applies it like any other managed theme.

Apply a repository theme without prompting:

```sh
scripts/apply-theme.sh tokyo-night
scripts/apply-theme.sh rose-pine-moon
```

Create and apply a pywal16 built-in theme without prompting:

```sh
scripts/apply-theme.sh --wal-theme tokyonight-night
scripts/apply-theme.sh --wal-theme rose-pine-moon
```

Use `--repo-only` to update only repo-managed Linux-side configs. Without that
flag, the script also backs up and updates the Windows-side terminal files:

```text
/mnt/c/Users/slyon/AppData/Roaming/alacritty/alacritty.toml
/mnt/c/Users/slyon/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json
```

Check generated theme files without applying anything:

```sh
scripts/apply-theme.sh --check
```

List selectable themes:

```sh
scripts/apply-theme.sh --list
scripts/apply-theme.sh --list-wal
scripts/apply-theme.sh --list-all
```

Create a new theme from a pywal16 palette:

```sh
scripts/create-theme.sh --name my-wallpaper --image ~/Pictures/wallpaper.jpg
scripts/create-theme.sh --name pywal-theme --wal-theme base16-gruvbox-dark-hard
```

The script runs `wal` with an isolated output directory, imports the generated
pywal colors into `themes/<name>.json`, regenerates app-specific theme files,
and runs the theme drift check. Pywal's `color0` through `color15` become the
ANSI terminal keys in the canonical JSON; app accent colors such as comments,
borders, and errors are derived from that same palette unless explicitly set
later. Use `./setup.sh --check` to confirm `pywal16` is installed.

On Termux, applying a theme also writes the native terminal palette to
`~/.termux/colors.properties`. Restart the Termux session or open a new one to
see the updated colors.

## Auto-Sync

This repo can sync itself every 10 minutes with a user-level systemd timer.
The timer runs `scripts/auto-sync.sh`, which:

- refuses to overlap with another run
- runs `scripts/check.sh` before committing
- commits all non-ignored changes
- rebases on the configured upstream
- pushes without force

Install and enable the timer:

```sh
scripts/install.sh systemd
systemctl --user daemon-reload
systemctl --user enable --now dotfiles-sync.timer
```

Check timer status:

```sh
systemctl --user list-timers dotfiles-sync.timer
systemctl --user status dotfiles-sync.timer
```

Inspect sync logs:

```sh
journalctl --user -u dotfiles-sync.service -n 100 --no-pager
```

Run one sync manually:

```sh
systemctl --user start dotfiles-sync.service
```

Disable auto-sync:

```sh
systemctl --user disable --now dotfiles-sync.timer
```

If you want the timer to run even when no user session is active:

```sh
loginctl enable-linger "$USER"
```

## Secrets

Plaintext secrets do not belong in tracked config files. Runtime secret files
live outside the repo:

- `~/.config/secrets/shell.env`
- `~/.config/secrets/npm.env`
- `~/.ssh` (keys and SSH configuration)

Tracked secret files are GPG encrypted:

- `secrets/shell.env.gpg`
- `secrets/npm.env.gpg`
- `secrets/ssh.tar.gz.gpg`

To decrypt on this machine:

```sh
scripts/decrypt-secrets.sh
```

To update secrets:

```sh
$EDITOR ~/.config/secrets/shell.env
$EDITOR ~/.config/secrets/npm.env
GPG_SYMMETRIC=1 scripts/encrypt-secrets.sh
```

To use recipient-based encryption instead of symmetric/passphrase encryption:

```sh
GPG_RECIPIENT='your-key-id-or-email' scripts/encrypt-secrets.sh
```

Both scripts accept optional names: `shell.env`, `npm.env`, and `ssh`.
With no names they process all three; missing sources/backups are reported
and skipped. To back up only SSH files:

```sh
GPG_SYMMETRIC=1 scripts/encrypt-secrets.sh ssh
scripts/decrypt-secrets.sh ssh
```

Directory backups follow symlinks, storing their contents as ordinary files
so they can be restored on another machine. Socket files are skipped; other special
files (such as FIFOs) cause backup to fail. Both scripts require `python3` for
directory archives. Restore validates archive paths and file types and installs
directories with mode 700 and files with mode 600. Existing destinations are
moved into private sibling `.<name>.backup.XXXXXX/original` backups before
replacement; unrelated contents survive in those backups. Destination symlinks
are refused. Failed encryption preserves the previous encrypted backup, and
failed decryption or archive validation preserves the current destination.
`XDG_CONFIG_HOME` is honored for env files; SSH uses `$HOME/.ssh`.
Only ciphertext belongs in this repository; keep the GPG key or passphrase
available separately for recovery.

MUD client files are managed in plaintext by the `tools` Stow package at
`~/.config/mud-client`. Run `scripts/install.sh tools` to install its config,
RoTS data, Lua scripts, character profiles, runtime config, and LuaLS settings.
The main config includes `weather-highlights.toml`, converted from
`tintin-rots/weather/weather.highlights.tt` with its colors, bold, underline,
and blink styles. Duplicate entries are collapsed.
Use `/reload` after changing the highlight rules.
The installer backs up the existing directory before Stow links the whole
directory. This keeps `config.toml.runtime.toml` a regular file, as required by
the client, and lets atomic saves update the repository. Previous untracked
files and old backups remain in the installer's timestamped backup directory.
External directory symlinks are refused. Keep passwords out of these tracked
configs. MUD client files are no longer encrypted or
restored by the secret scripts; obsolete MUD archives are ignored.

Verify secret-backed tools without printing secret values:

```sh
zsh -lic 'for v in GENAI_GATEWAY_AZURE_API_KEY DATABRICKS_HOST DATABRICKS_TOKEN AZURE_ARTIFACTS_NPM_USERNAME AZURE_ARTIFACTS_NPM_PASSWORD; do [[ -n ${(P)v} ]] && echo "$v=present" || echo "$v=missing"; done'
zsh -lic 'npm whoami --registry=https://pkgs.dev.azure.com/Vizientinc/_packaging/Vizient/npm/registry/'
zsh -lic 'curl -fsS -H "Authorization: Bearer $DATABRICKS_TOKEN" "$DATABRICKS_HOST/api/2.0/clusters/list" >/dev/null && echo "databricks=ok"'
```

```text
edit local secret  ->  encrypt with gpg  ->  commit .gpg only
decrypt .gpg       ->  source env files   ->  tools work normally
```

## Adding Configs

Add files under the package that matches their home path. For example:

```text
shell/.zshrc              -> ~/.zshrc
tools/.config/htop/htoprc -> ~/.config/htop/htoprc
nvim/.config/nvim/init.lua -> ~/.config/nvim/init.lua
```

Before adding a new config, check it for secrets:

```sh
rg -n --hidden -i 'token|secret|password|oauth|api[_-]?key' path/to/file
```

Do not import generated directories such as caches, plugin installs, database
files, app session storage, shell history, or nested `.git` directories.

## Recovery

If a stowed config breaks something, restore the previous copy from the latest
backup:

```sh
ls -td ~/.dotfiles-backup/* | head -1
```

Then copy the needed file back into this repo or directly into `$HOME` after
unstowing the package:

```sh
stow --delete --target="$HOME" shell
cp ~/.dotfiles-backup/<timestamp>/.zshrc ~/.zshrc
```

Once fixed in the repo, rerun:

```sh
scripts/check.sh
scripts/install.sh
```

## External Bootstraps

Some tools are referenced by config but are not vendored here:

- Oh My Zsh
- Powerlevel10k theme installation
- NVM
- rustup and `~/.cargo/env`
- tmux plugins
- Doom Emacs core
- Yazi apt source on Debian or Ubuntu, if the distro package is not available

Install or update those tools with their normal package managers.
