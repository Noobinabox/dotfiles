#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runtime_dir="${XDG_CONFIG_HOME:-$HOME/.config}/secrets"
secrets_dir="$repo_root/secrets"
# shellcheck source=scripts/lib/gum.sh
source "$repo_root/scripts/lib/gum.sh"

mkdir -p "$secrets_dir"

encrypt_one() {
  local name="$1"
  local src="$runtime_dir/$name"
  local dst="$secrets_dir/$name.gpg"

  if [[ ! -f "$src" ]]; then
    dotfiles_error "missing $src"
    return 1
  fi

  dotfiles_info "$name"
  if [[ -n "${GPG_RECIPIENT:-}" ]]; then
    gpg --yes --encrypt --recipient "$GPG_RECIPIENT" --output "$dst" "$src"
  elif [[ "${GPG_SYMMETRIC:-}" == "1" ]]; then
    gpg --yes --symmetric --cipher-algo AES256 --output "$dst" "$src"
  else
    dotfiles_error "set GPG_RECIPIENT=<key id/email> or GPG_SYMMETRIC=1"
    return 1
  fi
}

dotfiles_heading "encrypting secrets"
encrypt_one shell.env
encrypt_one npm.env

dotfiles_success "encrypted secrets into $secrets_dir"
