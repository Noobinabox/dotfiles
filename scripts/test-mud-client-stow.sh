#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
target="$work_dir/home"
config_dir="$target/.config/mud-client"
mkdir -p "$config_dir/scripts" "$config_dir/characters"
printf 'source config\n' >"$work_dir/original.toml"
ln -s "$work_dir/original.toml" "$config_dir/config.toml"
printf 'local runtime\n' >"$config_dir/config.toml.runtime.toml"
printf 'old backup\n' >"$config_dir/config.toml.backup.fixture"
printf 'old profile\n' >"$config_dir/characters/skjor.toml"
printf 'old script\n' >"$config_dir/scripts/init.lua"

cd "$repo_root"
STOW_TARGET="$target" DOTFILES_BACKUP_DIR="$work_dir/backup" scripts/install.sh tools >/dev/null
[[ -L "$config_dir" ]]
while IFS= read -r -d '' config; do
	config_path="${config#tools/}"
	[[ -f "$target/$config_path" && ! -L "$target/$config_path" ]]
	[[ "$(realpath "$target/$config_path")" == "$repo_root/$config" ]]
done < <(find tools/.config/mud-client -type f -print0)
[[ -L "$work_dir/backup/.config/mud-client/config.toml" ]]
[[ "$(<"$work_dir/original.toml")" == 'source config' ]]
[[ "$(<"$work_dir/backup/.config/mud-client/characters/skjor.toml")" == 'old profile' ]]
[[ "$(<"$work_dir/backup/.config/mud-client/scripts/init.lua")" == 'old script' ]]
[[ "$(<"$work_dir/backup/.config/mud-client/config.toml.runtime.toml")" == 'local runtime' ]]
cmp "$config_dir/config.toml.runtime.toml" tools/.config/mud-client/config.toml.runtime.toml
[[ "$(<"$work_dir/backup/.config/mud-client/config.toml.backup.fixture")" == 'old backup' ]]

# Reinstalling preserves links and does not create additional backups.
STOW_TARGET="$target" DOTFILES_BACKUP_DIR="$work_dir/reinstall-backup" scripts/install.sh tools >/dev/null
[[ ! -e "$work_dir/reinstall-backup/.config/mud-client" ]]

clean_target="$work_dir/clean"
mkdir "$clean_target"
STOW_TARGET="$clean_target" DOTFILES_BACKUP_DIR="$work_dir/clean-backup" scripts/install.sh tools >/dev/null
[[ "$(realpath "$clean_target/.config/mud-client")" == "$repo_root/tools/.config/mud-client" ]]
[[ ! -L "$clean_target/.config/mud-client/config.toml.runtime.toml" ]]
cmp "$clean_target/.config/mud-client/config.toml.runtime.toml" tools/.config/mud-client/config.toml.runtime.toml
printf 'MUD client Stow checks passed\n'
