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

if [[ -n "${GPG_RECIPIENT:-}" ]]; then
	encryption_args=(--encrypt --recipient "$GPG_RECIPIENT")
elif [[ "${GPG_SYMMETRIC:-}" == "1" ]]; then
	encryption_args=(--symmetric --cipher-algo AES256)
else
	dotfiles_error "set GPG_RECIPIENT=<key id/email> or GPG_SYMMETRIC=1"
	exit 1
fi

mkdir -p "$secrets_dir"
work_dir="$(mktemp -d "$secrets_dir/.encrypt.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT

encrypt_one() {
	local name="$1"
	secret_paths "$name"

	if [[ ! -e "$source_path" ]]; then
		dotfiles_warn "missing $source_path; skipped"
		return 0
	fi
	if [[ "$name" == ssh ]]; then
		[[ -d "$source_path" ]] || {
			dotfiles_error "expected directory: $source_path"
			return 1
		}
		dotfiles_info "$name"
		# Dereference config links so backups work without the original checkout.
		python3 "$repo_root/scripts/lib/secret-archive.py" pack "$source_path" |
			gpg --yes "${encryption_args[@]}" --output "$work_dir/encrypted"
	elif [[ -f "$source_path" ]]; then
		dotfiles_info "$name"
		gpg --yes "${encryption_args[@]}" --output "$work_dir/encrypted" "$source_path"
	else
		dotfiles_error "expected file: $source_path"
		return 1
	fi
	mv -f "$work_dir/encrypted" "$encrypted_path"
}

dotfiles_heading "encrypting secrets"
for name in "${secret_names[@]}"; do
	encrypt_one "$name"
done

dotfiles_success "encrypted secrets into $secrets_dir"
