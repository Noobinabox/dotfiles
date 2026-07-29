#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runtime_dir="${XDG_CONFIG_HOME:-$HOME/.config}/secrets"
secrets_dir="$repo_root/secrets"

mkdir -p "$runtime_dir"
chmod 700 "$runtime_dir"

for encrypted in "$secrets_dir"/*.env.gpg; do
  [[ -e "$encrypted" ]] || {
    printf 'no encrypted env files found in %s\n' "$secrets_dir" >&2
    exit 1
  }

  name="$(basename "$encrypted" .gpg)"
  target="$runtime_dir/$name"
  gpg --yes --decrypt --output "$target" "$encrypted"
  chmod 600 "$target"
done

printf 'decrypted secrets into %s\n' "$runtime_dir"

