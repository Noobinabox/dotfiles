#!/usr/bin/env bash

set -euo pipefail

# Join visual rows that were created by terminal wrapping so URLs are matched
# as one logical line. Normal line breaks remain intact.
pane_output="$(tmux capture-pane -pJ -S -)"
last_url="$(printf '%s\n' "$pane_output" |
  grep -oE 'https?://[^[:space:]<>"'"'"'()]+' |
  sed -E 's/[.,;:!?]+$//' |
  tail -n 1 || true)"

if [[ -z "$last_url" ]]; then
  tmux display-message 'No URL found in pane scrollback'
  exit 0
fi

if [[ -n "${TMUX_YANK_COPY_COMMAND:-}" ]]; then
  printf '%s' "$last_url" | sh -c "$TMUX_YANK_COPY_COMMAND"
elif command -v clip.exe >/dev/null 2>&1; then
  printf '%s' "$last_url" | clip.exe
elif command -v wl-copy >/dev/null 2>&1; then
  printf '%s' "$last_url" | wl-copy
elif command -v xclip >/dev/null 2>&1; then
  printf '%s' "$last_url" | xclip -selection clipboard
elif command -v xsel >/dev/null 2>&1; then
  printf '%s' "$last_url" | xsel --clipboard --input
elif command -v pbcopy >/dev/null 2>&1; then
  printf '%s' "$last_url" | pbcopy
else
  tmux display-message 'No supported clipboard command found'
  exit 1
fi

tmux display-message "Copied URL: $last_url"
