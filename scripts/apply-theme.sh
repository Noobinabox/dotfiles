#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
backup_root="${DOTFILES_BACKUP_DIR:-$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)-$$}"
alacritty_config="${ALACRITTY_CONFIG:-/mnt/c/Users/slyon/AppData/Roaming/alacritty/alacritty.toml}"
windows_terminal_settings="${WINDOWS_TERMINAL_SETTINGS:-/mnt/c/Users/slyon/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json}"

# shellcheck source=scripts/lib/gum.sh
source "$repo_root/scripts/lib/gum.sh"

usage() {
	command cat <<'USAGE'
Usage: scripts/apply-theme.sh [--list] [--list-wal] [--list-all] [--check] [--repo-only] [--wal-theme NAME] [THEME]

Select and apply a global dotfiles theme.

Options:
  --list            List repository themes.
  --list-wal        List pywal16 built-in themes.
  --list-all        List repository themes and pywal16 built-in themes.
  --check           Verify generated theme outputs are current.
  --repo-only       Apply only repo-managed Linux-side configs.
  --wal-theme NAME  Create/apply a pywal16 built-in theme as pywal-NAME.
  --help            Show this help.

With no THEME, an interactive picker is shown with repository themes and
pywal16 built-in themes. fzf is used when available, with a numbered shell
prompt as a fallback.
USAGE
}

list_themes() {
	"$repo_root/scripts/generate-themes.py" --list
}

ensure_wal_path() {
	if ! command -v wal >/dev/null 2>&1 && [[ -d "$HOME/.local/lib/python/bin" ]]; then
		PATH="$HOME/.local/lib/python/bin:$PATH"
		export PATH
	fi
}

wal_available() {
	ensure_wal_path
	command -v wal >/dev/null 2>&1
}

list_wal_themes() {
	wal_available || return 1
	wal --theme 2>/dev/null |
		sed -E 's/\x1b\[[0-9;]*m//g' |
		sed -n 's/^ - //p' |
		sed -E 's/[[:space:]]+\(last used\)$//' |
		sort -u
}

normalize_wal_theme_name() {
	local name="$1"
	name="$(printf '%s' "$name" |
		tr '[:upper:]' '[:lower:]' |
		sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"

	if [[ -z "$name" ]]; then
		dotfiles_error "could not normalize pywal theme name: $1"
		exit 1
	fi

	printf 'pywal-%s\n' "$name"
}

list_all_theme_rows() {
	local theme

	while IFS= read -r theme; do
		[[ -n "$theme" ]] && printf 'repo\t%s\n' "$theme"
	done < <(list_themes)

	if wal_available; then
		while IFS= read -r theme; do
			[[ -n "$theme" ]] && printf 'wal\t%s\n' "$theme"
		done < <(list_wal_themes)
	fi
}

list_all_themes() {
	list_all_theme_rows | awk -F '\t' '{ printf "%s\t%s\n", $1, $2 }'
}

select_theme() {
	local rows selected index choice count kind name
	rows="$(list_all_theme_rows)"

	if command -v fzf >/dev/null 2>&1; then
		selected="$(printf '%s\n' "$rows" | fzf --prompt='Theme> ' --height=40% --reverse --delimiter=$'\t' --with-nth=1,2)"
		[[ -n "$selected" ]] || exit 1
		printf '%s\n' "$selected"
		return
	fi

	dotfiles_heading "available themes"
	index=1
	while IFS=$'\t' read -r kind name; do
		printf '%d) [%s] %s\n' "$index" "$kind" "$name"
		index=$((index + 1))
	done <<<"$rows"

	count=$((index - 1))
	printf 'Select theme [1-%d]: ' "$count" >&2
	read -r choice

	if [[ ! "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > count)); then
		dotfiles_error "invalid theme selection"
		exit 1
	fi

	printf '%s\n' "$rows" | sed -n "${choice}p"
}

ensure_wal_theme_created() {
	local source_theme="$1"
	local target_theme="$2"

	if [[ -f "$repo_root/themes/$target_theme.json" ]]; then
		dotfiles_info "using existing generated pywal theme: $target_theme"
		return
	fi

	dotfiles_heading "creating pywal theme: $target_theme"
	"$repo_root/scripts/create-theme.sh" --name "$target_theme" --wal-theme "$source_theme"
}

backup_file() {
	local path="$1"
	local backup_path

	[[ -e "$path" || -L "$path" ]] || return 0

	backup_path="$backup_root/windows/${path#/}"
	mkdir -p "$(dirname "$backup_path")"
	cp -a "$path" "$backup_path"
	dotfiles_info "backed up $path"
}

preflight_windows_apply() {
	local tmpdir="$1"
	local alacritty_copy="$tmpdir/alacritty.toml"
	local windows_terminal_copy="$tmpdir/settings.json"

	[[ -f "$alacritty_config" ]] || {
		dotfiles_error "Alacritty config not found: $alacritty_config"
		exit 1
	}
	[[ -f "$windows_terminal_settings" ]] || {
		dotfiles_error "Windows Terminal settings not found: $windows_terminal_settings"
		exit 1
	}

	cp -a "$alacritty_config" "$alacritty_copy"
	cp -a "$windows_terminal_settings" "$windows_terminal_copy"
	"$repo_root/scripts/generate-themes.py" --apply-alacritty "$theme" "$alacritty_copy"
	"$repo_root/scripts/generate-themes.py" --apply-windows-terminal "$theme" "$windows_terminal_copy"
}

repo_only=false
theme=""
wal_theme=""

while [[ "$#" -gt 0 ]]; do
	case "$1" in
	--list)
		list_themes
		exit 0
		;;
	--list-wal)
		if ! list_wal_themes; then
			dotfiles_error "pywal16 is required; run ./setup.sh or install python-pywal16 so the wal command is available"
			exit 1
		fi
		exit 0
		;;
	--list-all)
		list_all_themes
		exit 0
		;;
	--check)
		"$repo_root/scripts/generate-themes.py" --check
		exit 0
		;;
	--repo-only)
		repo_only=true
		;;
	--wal-theme)
		if [[ -z "${2:-}" || "${2:-}" == -* ]]; then
			dotfiles_error "--wal-theme requires a pywal16 theme name"
			exit 2
		fi
		wal_theme="$2"
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
		if [[ -n "$theme" ]]; then
			dotfiles_error "only one theme can be applied at a time"
			exit 2
		fi
		theme="$1"
		;;
	esac
	shift
done

cd "$repo_root"

if [[ -n "$theme" && -n "$wal_theme" ]]; then
	dotfiles_error "choose either THEME or --wal-theme, not both"
	exit 2
fi

if [[ -n "$wal_theme" ]]; then
	theme="$(normalize_wal_theme_name "$wal_theme")"
fi

if [[ -z "$theme" ]]; then
	selected="$(select_theme)"
	selection_kind="${selected%%$'\t'*}"
	selection_value="${selected#*$'\t'}"

	if [[ "$selection_kind" == "wal" ]]; then
		wal_theme="$selection_value"
		theme="$(normalize_wal_theme_name "$wal_theme")"
	else
		theme="$selection_value"
	fi
fi

if [[ -n "$wal_theme" ]]; then
	if ! wal_available; then
		dotfiles_error "pywal16 is required; run ./setup.sh or install python-pywal16 so the wal command is available"
		exit 1
	fi
	ensure_wal_theme_created "$wal_theme" "$theme"
fi

dotfiles_heading "generating theme outputs"
"$repo_root/scripts/generate-themes.py" --write

if [[ "$repo_only" == false ]]; then
	dotfiles_heading "preflighting Windows terminal themes"
	tmpdir="$(mktemp -d)"
	trap 'rm -rf "$tmpdir"' EXIT
	preflight_windows_apply "$tmpdir"
fi

dotfiles_heading "applying repo theme: $theme"
"$repo_root/scripts/generate-themes.py" --apply-repo "$theme"

if [[ "$repo_only" == false ]]; then
	dotfiles_heading "applying Windows terminal themes"
	backup_file "$alacritty_config"
	backup_file "$windows_terminal_settings"
	"$repo_root/scripts/generate-themes.py" --apply-alacritty "$theme" "$alacritty_config"
	"$repo_root/scripts/generate-themes.py" --apply-windows-terminal "$theme" "$windows_terminal_settings"
	dotfiles_info "backup root: $backup_root"
fi

dotfiles_success "theme applied: $theme"
