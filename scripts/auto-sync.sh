#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lock_file="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-auto-sync.lock"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$*"
}

exec 9>"$lock_file"
if ! flock -n 9; then
  log "another auto-sync run is already active"
  exit 0
fi

cd "$repo_root"

export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes}"

git_dir="$(git rev-parse --git-dir)"
upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"

if [[ -z "$upstream" ]]; then
  log "current branch has no upstream; skipping"
  exit 1
fi

if [[ -f "$git_dir/MERGE_HEAD" || -d "$git_dir/rebase-merge" || -d "$git_dir/rebase-apply" ]]; then
  log "repository has an in-progress merge or rebase; skipping"
  exit 1
fi

push_if_ahead() {
  local counts ahead

  counts="$(git rev-list --left-right --count "$upstream"...HEAD)"
  ahead="$(awk '{ print $2 }' <<<"$counts")"

  if [[ "$ahead" -gt 0 ]]; then
    log "pushing $ahead commit(s) to $upstream"
    git push
  else
    log "nothing to push"
  fi
}

log "running dotfiles safety check"
"$repo_root/scripts/check.sh"

git add --all

if git diff --cached --quiet --exit-code; then
  log "no local changes to commit"
  log "rebasing from $upstream"
  git pull --rebase --autostash
  push_if_ahead
  exit 0
fi

commit_message="Auto-sync dotfiles $(date '+%Y-%m-%d %H:%M:%S %Z')"

log "committing local changes"
git commit -m "$commit_message"

log "rebasing from $upstream"
git pull --rebase --autostash

push_if_ahead
log "auto-sync complete"

