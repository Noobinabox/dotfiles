#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runtime_dir="${XDG_CONFIG_HOME:-$HOME/.config}/secrets"
secrets_dir="$repo_root/secrets"
# shellcheck source=scripts/lib/gum.sh
source "$repo_root/scripts/lib/gum.sh"
# shellcheck source=scripts/lib/secrets.sh
source "$repo_root/scripts/lib/secrets.sh"
umask 077
select_secrets "$@"
work_dir=""
trap '[[ -z "$work_dir" ]] || rm -rf "$work_dir"' EXIT

dotfiles_heading "decrypting secrets"
for name in "${secret_names[@]}"; do
	secret_paths "$name"
	if [[ ! -f "$encrypted_path" ]]; then
		dotfiles_warn "missing $encrypted_path; skipped"
		continue
	fi
	if [[ -L "$source_path" ]]; then
		dotfiles_error "refusing to replace symlink: $source_path"
		exit 1
	fi
	parent="$(dirname "$source_path")"
	mkdir -p "$parent"
	work_dir="$(mktemp -d "$parent/.decrypt.XXXXXX")"
	dotfiles_info "$name"
	gpg --yes --decrypt --output "$work_dir/plaintext" "$encrypted_path"
	if [[ "$name" == ssh ]]; then
		mkdir "$work_dir/restored"
		python3 "$repo_root/scripts/lib/secret-archive.py" unpack "$work_dir/plaintext" "$work_dir/restored"
		restored="$work_dir/restored"
	else
		chmod 700 "$runtime_dir"
		restored="$work_dir/plaintext"
	fi
	if [[ -e "$source_path" ]]; then
		backup_dir="$(mktemp -d "$parent/.${name}.backup.XXXXXX")"
		mv "$source_path" "$backup_dir/original"
		if ! mv "$restored" "$source_path"; then
			mv "$backup_dir/original" "$source_path"
			exit 1
		fi
		dotfiles_info "previous $name saved in $backup_dir/original"
	else
		mv "$restored" "$source_path"
	fi
	rm -rf "$work_dir"
	work_dir=""
done

dotfiles_success "secret restore complete"
