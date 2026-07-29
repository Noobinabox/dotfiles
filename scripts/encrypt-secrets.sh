#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runtime_dir="${XDG_CONFIG_HOME:-$HOME/.config}/secrets"
secrets_dir="$repo_root/secrets"

mkdir -p "$secrets_dir"

encrypt_one() {
  local name="$1"
  local src="$runtime_dir/$name"
  local dst="$secrets_dir/$name.gpg"

  if [[ ! -f "$src" ]]; then
    printf 'missing %s\n' "$src" >&2
    return 1
  fi

  if [[ -n "${GPG_RECIPIENT:-}" ]]; then
    gpg --yes --encrypt --recipient "$GPG_RECIPIENT" --output "$dst" "$src"
  elif [[ "${GPG_SYMMETRIC:-}" == "1" ]]; then
    gpg --yes --symmetric --cipher-algo AES256 --output "$dst" "$src"
  else
    printf 'set GPG_RECIPIENT=<key id/email> or GPG_SYMMETRIC=1\n' >&2
    return 1
  fi
}

encrypt_one shell.env
encrypt_one npm.env

printf 'encrypted secrets into %s\n' "$secrets_dir"

