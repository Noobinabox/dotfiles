#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target="${STOW_TARGET:-$HOME}"
packages=(shell npm git nvim doom tmux tools systemd)
# shellcheck source=scripts/lib/gum.sh
source "$repo_root/scripts/lib/gum.sh"

cd "$repo_root"

if [[ -L "$target/.codex" ]]; then
	dotfiles_error "$target/.codex must be a real directory so Codex runtime state stays out of git"
	exit 1
fi

dotfiles_heading "checking stow links"
for package in "${packages[@]}"; do
	dotfiles_info "$package"
	stow --simulate --verbose --target="$target" "$package"
done

dotfiles_heading "checking clean Codex stow behavior"
clean_target="$(mktemp -d)"
trap 'rm -rf "$clean_target"' EXIT
STOW_TARGET="$clean_target" DOTFILES_BACKUP_DIR="$clean_target/.backup" scripts/install.sh tools >/dev/null

if [[ -L "$clean_target/.codex" ]]; then
	dotfiles_error "clean tools install folded .codex into a symlink"
	exit 1
fi

while IFS= read -r -d '' codex_doc; do
	codex_target="$clean_target/.codex/$(basename "$codex_doc")"

	if [[ ! -L "$codex_target" ]]; then
		dotfiles_error "clean tools install did not stow .codex/$(basename "$codex_doc") as a file link"
		exit 1
	fi
done < <(find tools/.codex -maxdepth 1 -type f -name '*.md' -print0 | sort -z)

dotfiles_heading "checking generated themes"
scripts/generate-themes.py --check

dotfiles_heading "checking TinTin++ LSP"
node scripts/test-tintin-lsp.js

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

dotfiles_success "dotfiles validation passed"
