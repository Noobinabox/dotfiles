#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
installer="$repo_root/scripts/install-tui-tools.sh"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
export DOTFILES_TUI_BIN_DIR="$test_root/bin"
export DOTFILES_PLATFORM=linux
export TUI_TEST_ROOT="$test_root"
export PATH="$test_root/bin:/usr/bin:/bin"
mkdir -p "$test_root/fixtures" "$test_root/source"

curl() {
	local url destination
	while [[ "$#" -gt 0 ]]; do
		case "$1" in
		https://*) url="$1" ;;
		-o)
			shift
			destination="$1"
			;;
		esac
		shift
	done
	printf '%s\n' "$url" >>"$TUI_TEST_ROOT/downloads"
	cp "$TUI_TEST_ROOT/fixtures/${url##*/}" "$destination"
}
export -f curl

# Check mode must fail for missing tools without creating the install directory.
if bash "$installer" --check >"$test_root/check.log"; then
	printf 'check mode accepted missing tools\n' >&2
	exit 1
fi
[[ ! -e "$test_root/bin" && ! -e "$test_root/downloads" ]]
rg -q 'missing: lazygit' "$test_root/check.log"
rg -q 'missing: sesh' "$test_root/check.log"

case "$(uname -m)" in
x86_64 | amd64) arch=x86_64 ;;
aarch64 | arm64) arch=arm64 ;;
*)
	printf 'unsupported test architecture\n' >&2
	exit 1
	;;
esac

for tool in lazygit sesh; do
	ln -s /usr/bin/true "$test_root/source/$tool"
	case "$tool" in
	lazygit)
		archive="lazygit_0.66.2_linux_${arch}.tar.gz"
		checksums=checksums.txt
		;;
	sesh)
		archive="sesh_Linux_${arch}.tar.gz"
		checksums=sesh_2.33.0_checksums.txt
		;;
	esac
	tar -chzf "$test_root/fixtures/$archive" -C "$test_root/source" "$tool"
	(cd "$test_root/fixtures" && sha256sum "$archive") >"$test_root/fixtures/$checksums"
done

# A corrupt download must never reach extraction or installation.
cp "$test_root/fixtures/checksums.txt" "$test_root/valid-checksums.txt"
printf '%064d  lazygit_0.66.2_linux_%s.tar.gz\n' 0 "$arch" >"$test_root/fixtures/checksums.txt"
if bash "$installer" >"$test_root/corrupt.log" 2>&1; then
	printf 'installer accepted a corrupt archive\n' >&2
	exit 1
fi
rg -q 'Checksum verification failed' "$test_root/corrupt.log"
[[ ! -e "$test_root/bin/lazygit" && ! -e "$test_root/bin/sesh" ]]

cp "$test_root/valid-checksums.txt" "$test_root/fixtures/checksums.txt"
ln -s /usr/bin/true "$test_root/bin/lazygit"
bash "$installer" >/dev/null
[[ -x "$test_root/bin/lazygit" && -x "$test_root/bin/sesh" ]]
[[ -L "$test_root/bin/lazygit" ]]
bash "$installer" --check

# Existing tools must be preserved without further network access.
downloads_before="$(wc -l <"$test_root/downloads")"
bash "$installer"
[[ "$(wc -l <"$test_root/downloads")" == "$downloads_before" ]]

# Windows bootstrap should report missing native tools and continue.
# The sourced setup function invokes these stubs and reads the variables.
# shellcheck disable=SC2329,SC2034
windows_output="$(
	# shellcheck source=/dev/null
	source <(sed -n '/^install_tui_tools() {$/,/^}$/p' "$repo_root/setup.sh")
	log() { :; }
	info() { :; }
	have() { return 1; }
	record_missing() { printf 'missing: %s\n' "$1"; }
	platform=windows
	check_only=false
	install_tui_tools
)"
[[ "$windows_output" == $'missing: lazygit\nmissing: sesh' ]]

printf 'TUI installer checks passed\n'
