#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runtime_dir="${XDG_CONFIG_HOME:-$HOME/.config}/secrets"
secrets_dir="$repo_root/secrets"
# shellcheck source=scripts/lib/gum.sh
source "$repo_root/scripts/lib/gum.sh"

mkdir -p "$runtime_dir"
chmod 700 "$runtime_dir"

dotfiles_heading "decrypting secrets"
for encrypted in "$secrets_dir"/*.env.gpg; do
  [[ -e "$encrypted" ]] || {
    dotfiles_error "no encrypted env files found in $secrets_dir"
    exit 1
  }

  name="$(basename "$encrypted" .gpg)"
  target="$runtime_dir/$name"
  dotfiles_info "$name"
  gpg --yes --decrypt --output "$target" "$encrypted"
  chmod 600 "$target"
done

dotfiles_success "decrypted secrets into $runtime_dir"
