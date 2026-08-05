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
```

## What This Manages

The repo is organized as stow packages:

- `shell`: zsh, bash, shared aliases/functions, profile files, and Powerlevel10k
- `npm`: npm config with credentials supplied by environment variables
- `git`: Git config
- `nvim`: Neovim config
- `doom`: personal Doom Emacs config
- `tmux`: tmux config
- `tools`: small CLI/tool configs such as `glow`, `yazi`, `htop`, `bpytop`,
  `harper-ls`, GitHub CLI config, Angular config, and Codex config
- `systemd`: user service and timer for automatic dotfiles sync
- `secrets`: encrypted secret env files

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

## Daily Use

After changing config in this repo, run:

```sh
scripts/check.sh
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

## File Navigation

`vf` is the fast file launcher. It searches files recursively from the current
directory with `fzf`, previews the highlighted file, then opens the selected
file or files with the action you choose.

```sh
vf
vf README
vf --edit init.lua
vf --view notes
vf --explore package
vf --help
```

Preview behavior:

- Markdown files use Glow with the managed Tokyo Night style.
- Other files use `batcat` or `bat` when available.
- Plain `sed` output is the fallback.

Selection behavior:

- Press `Enter` to accept the highlighted file.
- Press `Tab` to toggle multiple file selections.
- Press `Esc` to cancel without doing anything.

Actions:

- `edit`: opens all selected files in one Neovim process.
- `view`: opens all selected files read-only with `nvim -R`.
- `explore`: opens Yazi in the parent directory of the first selected file.

`vf --explore` intentionally opens a directory instead of passing every selected
file to Yazi. Once Yazi is open, use its own Vim-style selection workflow:

- `h`/`j`/`k`/`l`: parent/down/up/enter
- `gg`/`G`: top/bottom
- `/`, `n`, `N`: find and move between matches
- `v`: visual selection mode
- `V`: toggle the hovered file
- `yy`: yank selected files
- `dd`: cut selected files
- `p`: paste yanked files
- `ge`: open the hovered file with the default opener
- `gv` or `go`: choose an opener for the hovered file, including read-only view

Yazi is the richer file browsing and management layer. Its config is stowed
from `tools/.config/yazi` to `~/.config/yazi`, uses Vim-style navigation, and
loads the Tokyo Night flavor. Restore managed Yazi packages and flavors with:

```sh
ya pkg install
```

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

Tracked secret files are GPG encrypted:

- `secrets/shell.env.gpg`
- `secrets/npm.env.gpg`

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
