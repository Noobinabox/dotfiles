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

package_selected() {
	local wanted="$1"
	local package

	for package in "${packages[@]}"; do
		[[ "$package" == "$wanted" ]] && return 0
	done

	return 1
}

path_is_inside_repo() {
	local resolved
	resolved="$(realpath -m "$1")"
	[[ "$resolved" == "$repo_root" || "$resolved" == "$repo_root/"* ]]
}

ensure_real_dir() {
	local path="$1"
	local full="$target/$path"

	if [[ -L "$full" ]]; then
		if path_is_inside_repo "$full"; then
			rm "$full"
		else
			dotfiles_error "$full is a symlink outside this repo; move it before stowing"
			exit 1
		fi
	fi

	mkdir -p "$full"
}

backup_path() {
	local path="$1"
	local full="$target/$path"

	[[ -e "$full" || -L "$full" ]] || return 0
	[[ -L "$full" ]] && return 0
	path_is_inside_repo "$full" && return 0

	mkdir -p "$backup_root/$(dirname "$path")"
	mv "$full" "$backup_root/$path"
	dotfiles_info "backed up $full"
}

if package_selected tools; then
	ensure_real_dir .codex
fi

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
backup_path .config/glow/theme.json
backup_path .config/theme-pack
backup_path .config/yazi
backup_path .config/spotify-player/app.toml
backup_path .config/htop/htoprc
backup_path .config/bpytop/bpytop.conf
backup_path .config/harper-ls/dictionary.txt
backup_path .config/gh/config.yml
if package_selected tools; then
	while IFS= read -r -d '' codex_doc; do
		backup_path ".codex/$(basename "$codex_doc")"
	done < <(find tools/.codex -maxdepth 1 -type f -name '*.md' -print0 | sort -z)
	backup_path .codex/config.toml
fi
backup_path .config/systemd/user/dotfiles-sync.service
backup_path .config/systemd/user/dotfiles-sync.timer

dotfiles_heading "stowing packages"
for package in "${packages[@]}"; do
	dotfiles_info "$package"
	stow --target="$target" "$package"
done

dotfiles_success "stowed packages into $target"
dotfiles_info "backup root: $backup_root"
