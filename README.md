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
```

## What This Manages

The repo is organized as stow packages:

- `shell`: zsh, bash, shared aliases/functions, profile files, and Powerlevel10k
- `npm`: npm config with credentials supplied by environment variables
- `git`: Git config
- `nvim`: Neovim config
- `doom`: personal Doom Emacs config
- `tmux`: tmux config
- `tools`: small CLI/tool configs such as `glow`, `htop`, `bpytop`, `harper-ls`,
  GitHub CLI config, Angular config, and Codex config
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

Install required tools:

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
```

Inspect managed links:

```sh
find ~ -maxdepth 3 -type l -lname '*dot-files*' -print
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

Install or update those tools with their normal package managers.
