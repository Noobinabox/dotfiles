#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
inventory_dir="$repo_root/packages/ubuntu"
selected=(apt snap flatpak npm pipx cargo dotnet)

usage() {
	cat <<'USAGE'
Usage: scripts/install-exported-apps.sh [--inventory-dir DIR] [SOURCE...]

Install reviewed inventories exported by scripts/export-installed-apps.sh.
Sources: apt snap flatpak npm pipx cargo dotnet
Without sources, all available inventories are processed.
USAGE
}

while (($#)); do
	case "$1" in
	--inventory-dir)
		(($# >= 2)) || { printf 'missing value for --inventory-dir\n' >&2; exit 2; }
		inventory_dir="$2"
		shift 2
		;;
	--help|-h) usage; exit 0 ;;
	apt|snap|flatpak|npm|pipx|cargo|dotnet)
		if ((${#selected[@]} == 7)); then selected=(); fi
		selected+=("$1"); shift ;;
	*) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
	esac
done

strip_comments() { sed '/^[[:space:]]*#/d;/^[[:space:]]*$/d' "$1"; }
has_entries() { [[ -f "$1" ]] && strip_comments "$1" | grep -q .; }
require_command() {
	command -v "$1" >/dev/null 2>&1 || { printf 'required command unavailable: %s\n' "$1" >&2; return 1; }
}

for source in "${selected[@]}"; do
	case "$source" in
	apt)
		file="$inventory_dir/apt-manual.txt"; has_entries "$file" || continue
		require_command apt-get
		mapfile -t entries < <(strip_comments "$file")
		sudo apt-get install "${entries[@]}"
		;;
	snap)
		file="$inventory_dir/snap.tsv"; has_entries "$file" || continue
		require_command snap
		while IFS=$'\t' read -r app channel; do [[ -n "$app" ]] && sudo snap install "$app" --channel="$channel"; done < <(strip_comments "$file")
		;;
	flatpak)
		file="$inventory_dir/flatpak.tsv"; has_entries "$file" || continue
		require_command flatpak
		while IFS=$'\t' read -r app remote; do [[ -n "$app" ]] && flatpak install --or-update "$remote" "$app"; done < <(strip_comments "$file")
		;;
	npm)
		file="$inventory_dir/npm-global.txt"; has_entries "$file" || continue
		require_command npm; mapfile -t entries < <(strip_comments "$file"); npm install --global "${entries[@]}" ;;
	pipx)
		file="$inventory_dir/pipx.txt"; has_entries "$file" || continue
		require_command pipx; while IFS= read -r app; do pipx install "$app"; done < <(strip_comments "$file") ;;
	cargo)
		file="$inventory_dir/cargo.txt"; has_entries "$file" || continue
		require_command cargo; while IFS= read -r app; do cargo install "$app"; done < <(strip_comments "$file") ;;
	dotnet)
		file="$inventory_dir/dotnet-tools.txt"; has_entries "$file" || continue
		require_command dotnet; while IFS= read -r app; do dotnet tool install --global "$app"; done < <(strip_comments "$file") ;;
	esac
done
