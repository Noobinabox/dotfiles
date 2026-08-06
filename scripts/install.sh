#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target="${STOW_TARGET:-$HOME}"
backup_root="${DOTFILES_BACKUP_DIR:-$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)}"
# shellcheck source=scripts/lib/gum.sh
source "$repo_root/scripts/lib/gum.sh"

if [[ "$#" -gt 0 ]]; then
  packages=("$@")
else
  packages=(shell npm git nvim doom tmux tools systemd)
fi

cd "$repo_root"

backup_path() {
  local path="$1"
  local full="$target/$path"

  [[ -e "$full" || -L "$full" ]] || return 0
  [[ -L "$full" ]] && return 0

  mkdir -p "$backup_root/$(dirname "$path")"
  mv "$full" "$backup_root/$path"
  dotfiles_info "backed up $full"
}

dotfiles_heading "backing up existing unmanaged files"
backup_path .zshrc
backup_path .zshenv
backup_path .bashrc
backup_path .profile
backup_path .bashrc_aliases
backup_path .p10k.zsh
backup_path .npmrc
backup_path .gitconfig
backup_path .angular-config.json
backup_path .config/nvim
backup_path .config/doom
backup_path .config/tmux/tmux.conf
backup_path .config/glow/glow.yml
backup_path .config/yazi
backup_path .config/spotify-player/app.toml
backup_path .config/htop/htoprc
backup_path .config/bpytop/bpytop.conf
backup_path .config/harper-ls/dictionary.txt
backup_path .config/gh/config.yml
backup_path .codex/config.toml
backup_path .config/systemd/user/dotfiles-sync.service
backup_path .config/systemd/user/dotfiles-sync.timer

dotfiles_heading "stowing packages"
for package in "${packages[@]}"; do
  dotfiles_info "$package"
  stow --target="$target" "$package"
done

dotfiles_success "stowed packages into $target"
dotfiles_info "backup root: $backup_root"
