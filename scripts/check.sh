#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target="${STOW_TARGET:-$HOME}"
packages=(shell npm git nvim doom tmux tools systemd)
# shellcheck source=scripts/lib/gum.sh
source "$repo_root/scripts/lib/gum.sh"

cd "$repo_root"

dotfiles_heading "checking stow links"
for package in "${packages[@]}"; do
  dotfiles_info "$package"
  stow --simulate --verbose --target="$target" "$package"
done

dotfiles_heading "scanning for plaintext secrets"
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
  dotfiles_error "possible plaintext secret found"
  exit 1
fi

dotfiles_success "stow simulation and secret scan passed"
