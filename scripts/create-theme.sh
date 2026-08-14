#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
created_theme=false

# shellcheck source=scripts/lib/gum.sh
source "$repo_root/scripts/lib/gum.sh"

if ! command -v wal >/dev/null 2>&1 && [[ -d "$HOME/.local/lib/python/bin" ]]; then
	PATH="$HOME/.local/lib/python/bin:$PATH"
	export PATH
fi

usage() {
	command cat <<'USAGE'
Usage: scripts/create-theme.sh --name THEME [--image PATH | --wal-theme NAME | --from-json PATH]

Create a canonical theme palette, then regenerate app-specific outputs.

Options:
  --name THEME      Theme id to write under themes/THEME.json.
  --image PATH      Generate a palette from an image with pywal16.
  --wal-theme NAME  Generate a palette from a pywal16 built-in theme.
  --from-json PATH  Import an existing JSON palette.
  --help            Show this help.

The pywal16 CLI must be available as `wal` for --image and --wal-theme.
USAGE
}

theme_name=""
image_path=""
wal_theme=""
json_path=""

while [[ "$#" -gt 0 ]]; do
	case "$1" in
	--name)
		theme_name="${2:-}"
		shift
		;;
	--image)
		image_path="${2:-}"
		shift
		;;
	--wal-theme)
		wal_theme="${2:-}"
		shift
		;;
	--from-json)
		json_path="${2:-}"
		shift
		;;
	--help | -h)
		usage
		exit 0
		;;
	-*)
		printf 'unknown option: %s\n' "$1" >&2
		usage >&2
		exit 2
		;;
	*)
		printf 'unexpected argument: %s\n' "$1" >&2
		usage >&2
		exit 2
		;;
	esac
	shift
done

if [[ -z "$theme_name" ]]; then
	dotfiles_error "--name is required"
	exit 2
fi

if [[ ! "$theme_name" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
	dotfiles_error "theme name must use lowercase letters, numbers, and hyphens"
	exit 2
fi

if [[ -e "$repo_root/themes/$theme_name.json" ]]; then
	dotfiles_error "$repo_root/themes/$theme_name.json already exists"
	exit 1
fi

source_count=0
[[ -n "$image_path" ]] && source_count=$((source_count + 1))
[[ -n "$wal_theme" ]] && source_count=$((source_count + 1))
[[ -n "$json_path" ]] && source_count=$((source_count + 1))

if ((source_count != 1)); then
	dotfiles_error "choose exactly one of --image, --wal-theme, or --from-json"
	exit 2
fi

cd "$repo_root"

cleanup_created_theme() {
	if [[ "$created_theme" == true ]]; then
		rm -f "$repo_root/themes/$theme_name.json"
		rm -rf "$repo_root/themes/generated/$theme_name"
	fi
}

trap cleanup_created_theme ERR

if [[ -n "$json_path" ]]; then
	python3 "$repo_root/scripts/theme_from_pywal.py" --name "$theme_name" --from-json "$json_path"
	created_theme=true
else
	if ! command -v wal >/dev/null 2>&1; then
		dotfiles_error "pywal16 is required; run ./setup.sh or install python-pywal16 so the wal command is available"
		exit 1
	fi

	dotfiles_heading "generating pywal16 palette"
	pywal_cache="$(mktemp -d)"
	trap 'rm -rf "$pywal_cache"' EXIT
	if [[ -n "$image_path" ]]; then
		wal -n -s -e -q --out-dir "$pywal_cache" -i "$image_path"
	else
		wal -n -s -e -q --out-dir "$pywal_cache" --theme "$wal_theme"
	fi

	PYWAL_CACHE_DIR="$pywal_cache" python3 "$repo_root/scripts/theme_from_pywal.py" --name "$theme_name" --from-pywal-cache
	created_theme=true
fi

dotfiles_heading "generating app theme outputs"
"$repo_root/scripts/generate-themes.py" --write
"$repo_root/scripts/apply-theme.sh" --check
created_theme=false

dotfiles_success "created theme: $theme_name"
