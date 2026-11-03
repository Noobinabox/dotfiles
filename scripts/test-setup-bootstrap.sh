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
	case "$1" in nvim | dotnet | csharpier) return 0 ;; *) type -P "$1" >/dev/null 2>&1 ;; esac
}
nvim() { printf 'NVIM v%s\n' "$test_version"; }
for test_version in 0.11.5 0.12.3 0.13.0 0.12.3-dev; do
	missing=()
	install_user_local_tools >/dev/null
	found=false
	for item in "${missing[@]}"; do [[ "$item" != "nvim "* ]] || found=true; done
	if [[ "$test_version" == 0.12.3 ]]; then [[ "$found" == false ]]; else [[ "$found" == true ]]; fi
done
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
printf 'fresh-home bootstrap checks passed\n'
