#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
setup="$repo_root/setup.sh"
aliases="$repo_root/shell/.bashrc_aliases"

assert_platform() {
	local expected="$1"
	local actual
	actual="$(DOTFILES_PLATFORM="$expected" "$setup" --print-platform)"
	[[ "$actual" == "$expected" ]] || {
		printf 'expected platform %s, got %s\n' "$expected" "$actual" >&2
		exit 1
	}
}

for platform in linux fedora wsl termux windows macos; do
	assert_platform "$platform"
done

termux_bin="$(mktemp -d)"
trap 'rm -rf "$termux_bin"' EXIT
mkdir "$termux_bin/bin"
touch "$termux_bin/bin/pkg"
chmod +x "$termux_bin/bin/pkg"

manager="$(PREFIX="$termux_bin" PATH="$termux_bin:$PATH" bash -c \
	'source "$1"; dotfiles_pkg_manager' bash "$aliases")"
[[ "$manager" == pkg ]] || {
	printf 'expected Termux package manager pkg, got %s\n' "$manager" >&2
	exit 1
}

bash -n "$setup" "$aliases"
printf 'setup platform checks passed\n'
