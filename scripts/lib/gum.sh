#!/usr/bin/env bash

dotfiles_has_gum() {
  command -v gum >/dev/null 2>&1 && [[ -t 1 ]]
}

dotfiles_gum() {
  local gum_command
  gum_command="$(command -v gum)"
  "$gum_command" "$@"
}

dotfiles_heading() {
  if dotfiles_has_gum; then
    dotfiles_gum style --bold --foreground 63 "==> $*"
  else
    printf '\n==> %s\n' "$*"
  fi
}

dotfiles_info() {
  if dotfiles_has_gum; then
    dotfiles_gum style --foreground 244 "  $*"
  else
    printf '  %s\n' "$*"
  fi
}

dotfiles_success() {
  if dotfiles_has_gum; then
    dotfiles_gum style --bold --foreground 114 "ok: $*"
  else
    printf 'ok: %s\n' "$*"
  fi
}

dotfiles_warn() {
  if dotfiles_has_gum; then
    dotfiles_gum style --bold --foreground 179 "warn: $*" >&2
  else
    printf 'warn: %s\n' "$*" >&2
  fi
}

dotfiles_error() {
  if dotfiles_has_gum; then
    dotfiles_gum style --bold --foreground 203 "error: $*" >&2
  else
    printf 'error: %s\n' "$*" >&2
  fi
}

dotfiles_confirm() {
  local prompt="$1"

  if dotfiles_has_gum; then
    dotfiles_gum confirm "$prompt"
  else
    read -r -p "$prompt [y/N] " reply
    [[ "$reply" == [Yy] || "$reply" == [Yy][Ee][Ss] ]]
  fi
}
