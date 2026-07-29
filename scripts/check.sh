#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target="${STOW_TARGET:-$HOME}"
packages=(shell npm git nvim doom tmux tools)

cd "$repo_root"

for package in "${packages[@]}"; do
  stow --simulate --verbose --target="$target" "$package"
done

matches="$(
  rg -l -P --hidden \
    --glob '!**/.git/**' \
    --glob '!.local/**' \
    --glob '!secrets/*.gpg' \
    --glob '!secrets/README.md' \
    --glob '!scripts/check.sh' \
    -i '(GENAI_GATEWAY_AZURE_API_KEY=.+|DATABRICKS_TOKEN=.+|:_password=(?!\$\{AZURE_ARTIFACTS_NPM_PASSWORD\}).+|oauth_token:|github_pat_|ghp_|api[_-]?key=.*[[:alnum:]]{16,})' . || true
)"

if [[ -n "$matches" ]]; then
  printf '%s\n' "$matches" >&2
  printf 'possible plaintext secret found\n' >&2
  exit 1
fi

printf 'stow simulation and secret scan passed\n'
