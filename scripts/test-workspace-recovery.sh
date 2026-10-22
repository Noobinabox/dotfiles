#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
socket="$test_root/tmux.sock"
cleanup() {
	tmux -S "$socket" kill-server 2>/dev/null || true
	rm -rf "$test_root"
}
trap cleanup EXIT

if command -v nvim >/dev/null 2>&1; then
	XDG_STATE_HOME="$test_root/state" nvim --headless -u NONE -l "$repo_root/nvim/.config/nvim/scripts/test-sessions.lua"
else
	printf 'SKIP: Neovim session checks require nvim\n'
fi

resurrect="${TMUX_PLUGIN_MANAGER_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/tmux/plugins}/tmux-resurrect"
if ! command -v tmux >/dev/null 2>&1 || [[ ! -f "$resurrect/resurrect.tmux" ]]; then
	printf 'SKIP: tmux recovery checks require tmux and tmux-resurrect\n'
	exit 0
fi

# All state and server mutations are isolated from the user's active workspace.
mkdir -p "$test_root/first project" "$test_root/second-project"
tmux -S "$socket" -f /dev/null new-session -d -s recovery-test -c "$test_root/first project"
tmux -S "$socket" set -g @resurrect-dir "$test_root/snapshots"
tmux -S "$socket" split-window -h -t recovery-test -c "$test_root/second-project"
tmux -S "$socket" run-shell "bash '$resurrect/scripts/save.sh' quiet"
[[ -e "$test_root/snapshots/last" ]]
tmux -S "$socket" kill-server

tmux -S "$socket" -f /dev/null new-session -d -s bootstrap
tmux -S "$socket" set -g @resurrect-dir "$test_root/snapshots"
tmux -S "$socket" run-shell "bash '$resurrect/scripts/restore.sh'"
[[ "$(tmux -S "$socket" list-panes -t recovery-test -F '#{pane_current_path}' | wc -l)" -eq 2 ]]
paths="$(tmux -S "$socket" list-panes -t recovery-test -F '#{pane_current_path}')"
[[ "$paths" == *"$test_root/first project"* && "$paths" == *"$test_root/second-project"* ]]
printf 'tmux save/restore checks passed\n'
