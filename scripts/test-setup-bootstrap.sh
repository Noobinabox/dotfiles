#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
export BOOTSTRAP_TEST_REPO="$repo_root"
# Load the actual functions without running package managers or plugin installs.
sed '/^install_system_packages$/,$d; s|^repo_root=.*|repo_root="$BOOTSTRAP_TEST_REPO"|' "$repo_root/setup.sh" >"$test_root/functions.sh"
mkdir "$test_root/home"
export HOME="$test_root/home" DOTFILES_PLATFORM=wsl
source "$test_root/functions.sh"
# Used by the sourced setup functions.
# shellcheck disable=SC2034
check_only=true
# Production checks require executable files; provide the version probes here.
have() {
	case "$1" in obsidian) return 1 ;; nvim | dotnet | csharpier | npm) return 0 ;; *) type -P "$1" >/dev/null 2>&1 ;; esac
}
nvim() { printf 'NVIM v%s\n' "$test_version"; }
for test_version in 0.11.5 0.12.3 0.13.0 0.12.3-dev; do
	missing=()
	install_user_local_tools >/dev/null
	found=false
	for item in "${missing[@]}"; do [[ "$item" != "nvim "* ]] || found=true; done
	if [[ "$test_version" == 0.12.3 ]]; then [[ "$found" == false ]]; else [[ "$found" == true ]]; fi
done
missing=()
install_obsidian >/dev/null
[[ "${missing[*]}" == obsidian ]]
# Checking a fresh home must not create directories or install anything.
[[ -z "$(ls -A "$HOME")" ]]
dotnet() {
	case "$1" in
	--list-sdks) printf '%s\n' "$sdk_output" ;;
	--list-runtimes) printf 'Microsoft.AspNetCore.App 8.0.1 [/tmp]\n' ;;
	esac
}
csharpier() { :; }
for sdk_output in $'8.0.100 [/tmp]\n10.0.100 [/tmp]' '8.0.100 [/tmp]'; do
	missing=()
	install_dotnet_tools >/dev/null
	if [[ "$sdk_output" == *10.0* ]]; then [[ ${#missing[@]} == 0 ]]; else [[ "${missing[*]}" == 'dotnet SDK 10' ]]; fi
done
# Public npm installs recover from a rejected primary hostname without
# bypassing TLS checks or silently replacing an explicitly chosen registry.
# Used by the sourced setup function.
# shellcheck disable=SC2034
check_only=false
npm() { printf '%s' "$NPM_CONFIG_REGISTRY" >"$test_root/npm-registry"; }
curl() { [[ "${!#}" == https://registry.npmjs.com/-/ping ]]; }
unset DOTFILES_NPM_REGISTRY
export NPM_CONFIG_REGISTRY=https://registry.npmjs.org
install_npm_globals >/dev/null
[[ "$(cat "$test_root/npm-registry")" == https://registry.npmjs.com ]]
export DOTFILES_NPM_REGISTRY=https://registry.example.invalid
export NPM_CONFIG_REGISTRY="$DOTFILES_NPM_REGISTRY"
if install_npm_globals >/dev/null 2>&1; then
	printf 'Explicit npm registry failure was ignored\n' >&2
	exit 1
fi
# Setup delegates to the existing restore helper only in its default mode.
repo_root="$test_root/secret-fixture"
mkdir -p "$repo_root/scripts"
export SETUP_SECRET_MARKER="$test_root/restore-called"
cat >"$repo_root/scripts/decrypt-secrets.sh" <<'STUB'
#!/usr/bin/env bash
printf 'called\n' > "$SETUP_SECRET_MARKER"
exit "${SETUP_SECRET_STATUS:-0}"
STUB
chmod +x "$repo_root/scripts/decrypt-secrets.sh"
export check_only=true run_stow=true restore_encrypted_secrets=true
restore_setup_secrets >/dev/null
[[ ! -e "$SETUP_SECRET_MARKER" ]]
export check_only=false restore_encrypted_secrets=false
restore_setup_secrets >/dev/null
[[ ! -e "$SETUP_SECRET_MARKER" ]]
export restore_encrypted_secrets=true run_stow=false
restore_setup_secrets >/dev/null
[[ ! -e "$SETUP_SECRET_MARKER" ]]
export run_stow=true
restore_setup_secrets >/dev/null
[[ -e "$SETUP_SECRET_MARKER" ]]
export SETUP_SECRET_STATUS=7
if restore_setup_secrets >/dev/null 2>&1; then
	printf 'Secret restore failure was ignored\n' >&2
	exit 1
fi
printf 'fresh-home bootstrap checks passed\n'
