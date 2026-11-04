#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
export HOME="$fixture/home" NVM_DIR="$fixture/nvm" OBSIDIAN_TEST_LOG="$fixture/calls"
unset XDG_CONFIG_HOME OBSIDIAN_SYNC_PATH
mkdir -p "$HOME/.config" "$NVM_DIR" "$fixture/bin"
cat >"$NVM_DIR/nvm.sh" <<'STUB'
nvm() { [[ "$*" == 'use --silent default' ]]; }
STUB
cat >"$fixture/bin/ob" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$OBSIDIAN_TEST_LOG"
if [[ "$1" == sync-status ]]; then
  printf '%s\n' "${OBSIDIAN_TEST_STATUS:-Sync Configuration:}"
  exit "${OBSIDIAN_TEST_EXIT:-0}"
fi
STUB
cat >"$fixture/bin/crontab" <<'STUB'
#!/usr/bin/env bash
if [[ ${OBSIDIAN_TEST_CRON:-0} == 1 ]]; then
  printf '*/10 * * * * ob sync --path ~/vault\n'
else
  exit 1
fi
STUB
chmod +x "$fixture/bin/crontab"
chmod +x "$fixture/bin/ob"
export PATH="$fixture/bin:$PATH"
launcher="$repo_root/tools/.local/bin/obsidian-sync"
"$launcher" --check
"$launcher"
diff -u <(printf '%s\n' sync --path "$HOME/vault") "$OBSIDIAN_TEST_LOG"
printf 'OBSIDIAN_SYNC_PATH="%s/custom vault"\n' "$HOME" >"$HOME/.config/obsidian-sync.env"
"$launcher"
diff -u <(printf '%s\n' sync --path "$HOME/custom vault") "$OBSIDIAN_TEST_LOG"
export OBSIDIAN_TEST_EXIT=3
if "$launcher" --check; then exit 1; fi
export OBSIDIAN_TEST_EXIT=0 OBSIDIAN_TEST_STATUS='Not logged in.'
if "$launcher" --check; then exit 1; fi
export OBSIDIAN_TEST_STATUS='End-to-end encryption key missing. Run setup again.'
if "$launcher" --check; then exit 1; fi
if "$launcher" --invalid >/dev/null 2>&1; then exit 1; fi
# Exercise setup activation without contacting a live user systemd manager.
export OBSIDIAN_TEST_REPO="$repo_root"
sed '/^install_system_packages$/,$d; s|^repo_root=.*|repo_root="$OBSIDIAN_TEST_REPO"|' "$repo_root/setup.sh" >"$fixture/setup-functions.sh"
source "$fixture/setup-functions.sh"
mkdir -p "$HOME/.local/bin"
ln -s "$launcher" "$HOME/.local/bin/obsidian-sync"
export run_stow=true check_only=false OBSIDIAN_TEST_STATUS='Sync Configuration:'
systemctl() {
	printf '%s\n' "$*" >>"$fixture/systemctl-calls"
	if [[ "$1" == --user && "$2" == show-environment ]]; then return "${OBSIDIAN_TEST_SYSTEMD_EXIT:-0}"; fi
}
configure_obsidian_sync >/dev/null
grep -qx -- '--user enable --now obsidian-sync.timer' "$fixture/systemctl-calls"
rm "$fixture/systemctl-calls"
export OBSIDIAN_TEST_STATUS='Not logged in.'
configure_obsidian_sync >/dev/null
if grep -q -- 'enable --now' "$fixture/systemctl-calls"; then exit 1; fi
rm "$fixture/systemctl-calls"
export OBSIDIAN_TEST_SYSTEMD_EXIT=1
configure_obsidian_sync >/dev/null
if grep -q -- 'enable --now' "$fixture/systemctl-calls"; then exit 1; fi
rm "$fixture/systemctl-calls"
export OBSIDIAN_TEST_CRON=1
configure_obsidian_sync >/dev/null
[[ ! -e "$fixture/systemctl-calls" ]]
printf 'Obsidian sync launcher and setup activation checks passed\n'
