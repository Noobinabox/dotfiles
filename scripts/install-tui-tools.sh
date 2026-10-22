#!/usr/bin/env bash
set -euo pipefail

bin_dir="${DOTFILES_TUI_BIN_DIR:-$HOME/.local/bin}"
platform="${DOTFILES_PLATFORM:-$(uname -s)}"
if [[ -z "${DOTFILES_PLATFORM:-}" && -n "${PREFIX:-}" && -x "$PREFIX/bin/pkg" ]]; then
	platform=termux
fi

check_only=false
if [[ "$#" -gt 1 ]]; then
	printf 'Usage: bash scripts/install-tui-tools.sh [--check]\n' >&2
	exit 2
fi
case "${1:-}" in
--check) check_only=true ;;
"") ;;
*)
	printf 'Usage: bash scripts/install-tui-tools.sh [--check]\n' >&2
	exit 2
	;;
esac

missing=()
for tool in lazygit sesh; do
	command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
[[ "${#missing[@]}" -gt 0 ]] || exit 0

if [[ "$check_only" == true ]]; then
	printf 'missing: %s\n' "${missing[@]}"
	exit 1
fi

case "$platform" in
termux)
	command -v go >/dev/null 2>&1 || {
		printf 'Install Go with pkg install golang, then retry.\n' >&2
		exit 1
	}
	mkdir -p "$bin_dir"
	for tool in "${missing[@]}"; do
		case "$tool" in
		lazygit) module=github.com/jesseduffield/lazygit@v0.66.2 ;;
		sesh) module=github.com/joshmedeski/sesh/v2@v2.33.0 ;;
		esac
		GOBIN="$bin_dir" go install "$module"
	done
	exit 0
	;;
Linux | linux | fedora | wsl) release_os=Linux ;;
Darwin | macos) release_os=Darwin ;;
*)
	printf 'Install Lazygit and Sesh with your native package manager on this platform.\n' >&2
	exit 1
	;;
esac

case "$(uname -m)" in
x86_64 | amd64) release_arch=x86_64 ;;
aarch64 | arm64) release_arch=arm64 ;;
*)
	printf 'Unsupported architecture: %s\n' "$(uname -m)" >&2
	exit 1
	;;
esac

if command -v sha256sum >/dev/null 2>&1; then
	hash_command=(sha256sum)
elif command -v shasum >/dev/null 2>&1; then
	hash_command=(shasum -a 256)
else
	printf 'Install sha256sum or shasum before installing TUI tools.\n' >&2
	exit 1
fi

download_dir="$(mktemp -d)"
trap 'rm -rf "$download_dir"' EXIT
mkdir -p "$bin_dir"

for tool in "${missing[@]}"; do
	case "$tool" in
	lazygit)
		release_url=https://github.com/jesseduffield/lazygit/releases/download/v0.66.2
		archive="lazygit_0.66.2_$(printf '%s' "$release_os" | tr '[:upper:]' '[:lower:]')_${release_arch}.tar.gz"
		checksums=checksums.txt
		;;
	sesh)
		release_url=https://github.com/joshmedeski/sesh/releases/download/v2.33.0
		archive="sesh_${release_os}_${release_arch}.tar.gz"
		checksums=sesh_2.33.0_checksums.txt
		;;
	esac
	curl --proto '=https' --tlsv1.2 -fsSL "$release_url/$archive" -o "$download_dir/$archive"
	curl --proto '=https' --tlsv1.2 -fsSL "$release_url/$checksums" -o "$download_dir/checksums.txt"
	expected="$(awk -v name="$archive" '$2 == name {print $1}' "$download_dir/checksums.txt")"
	actual="$("${hash_command[@]}" "$download_dir/$archive")"
	if [[ ! "$expected" =~ ^[[:xdigit:]]{64}$ || "$expected" != "${actual%% *}" ]]; then
		printf 'Checksum verification failed for %s\n' "$archive" >&2
		exit 1
	fi
	tar -xzf "$download_dir/$archive" -C "$download_dir" "$tool"
	command install -m 755 "$download_dir/$tool" "$bin_dir/$tool"
	printf 'installed: %s\n' "$tool"
done
