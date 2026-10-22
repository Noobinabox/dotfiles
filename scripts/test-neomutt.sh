#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
target="$work_dir/home"
mkdir -p "$target/.config/neomutt" "$target/.config/neomutt-work"
printf 'original config\n' >"$target/.config/neomutt/neomuttrc"
cp "$repo_root/tools/.config/neomutt/work-account.example" "$target/.config/neomutt-work/account.rc"
printf '%s\n' '0123456789ABCDEF0123456789ABCDEF01234567' >"$target/.config/neomutt-work/gpg-recipient"

cd "$repo_root"
STOW_TARGET="$target" DOTFILES_BACKUP_DIR="$work_dir/backup" scripts/install.sh tools >/dev/null
[[ "$(<"$work_dir/backup/.config/neomutt/neomuttrc")" == 'original config' ]]
[[ "$(realpath "$target/.config/neomutt/neomuttrc")" == "$repo_root/tools/.config/neomutt/neomuttrc" ]]
[[ ! -L "$target/.config/neomutt-work" ]]
STOW_TARGET="$target" DOTFILES_BACKUP_DIR="$work_dir/reinstall" scripts/install.sh tools >/dev/null
[[ ! -e "$work_dir/reinstall/.config/neomutt" ]]

wrapper="$target/.config/neomutt/oauth2.sh"
if HOME="$target" NEOMUTT_OAUTH2_HELPER="$work_dir/missing.py" bash "$wrapper" >"$work_dir/out" 2>"$work_dir/error"; then
	printf 'missing OAuth helper unexpectedly succeeded\n' >&2
	exit 1
fi
[[ ! -s "$work_dir/out" ]]
[[ ! -e "$target/.local/share/neomutt" ]]
rg -q 'install mutt_oauth2.py' "$work_dir/error"

# A fake provider verifies paths, forwarding, permissions, and error propagation
# without accessing GPG, a mailbox, or the network.
mock_helper="$work_dir/helper with spaces.py"
printf '%s\n' \
	'import os, pathlib, stat, sys' \
	'path = pathlib.Path(sys.argv[1])' \
	'assert str(path) == os.environ["EXPECTED_TOKEN_PATH"]' \
	'assert stat.S_IMODE(path.parent.stat().st_mode) == 0o700' \
	'assert sys.argv[2:] == ["--encryption-pipe", "gpg --encrypt --recipient 0123456789ABCDEF0123456789ABCDEF01234567", "--email", "test@example.invalid"]' \
	'path.touch(mode=0o666)' \
	'assert stat.S_IMODE(path.stat().st_mode) == 0o600' \
	'print("fixture-access-value")' \
	'sys.exit(int(os.environ.get("MOCK_EXIT", "0")))' >"$mock_helper"
export HOME="$target"
export NEOMUTT_OAUTH2_HELPER="$mock_helper"
export EXPECTED_TOKEN_PATH="$HOME/.config/neomutt-work/work.tokens.gpg"
output="$(bash "$wrapper" --email test@example.invalid)"
[[ "$output" == fixture-access-value ]]
if MOCK_EXIT=7 bash "$wrapper" --email test@example.invalid >"$work_dir/out"; then
	exit 1
else
	[[ "$?" == 7 ]]
fi
mv "$EXPECTED_TOKEN_PATH" "$work_dir/token-fixture"
ln -s "$work_dir/token-fixture" "$EXPECTED_TOKEN_PATH"
if bash "$wrapper" >"$work_dir/out" 2>"$work_dir/error"; then
	exit 1
fi
[[ ! -s "$work_dir/out" ]]
rg -q 'symlinked token file' "$work_dir/error"

printf 'invalid fingerprint\n' >"$target/.config/neomutt-work/gpg-recipient"
if bash "$wrapper" >"$work_dir/out" 2>"$work_dir/error"; then
	exit 1
fi
[[ ! -s "$work_dir/out" ]]
rg -q 'full GPG fingerprint' "$work_dir/error"

if command -v neomutt >/dev/null 2>&1; then
	neomutt -n -F "$target/.config/neomutt/neomuttrc" \
		-Q imap_user -Q smtp_user -Q folder -Q smtp_url \
		-Q imap_authenticators -Q smtp_authenticators \
		-Q ssl_force_tls -Q ssl_verify_host -Q ssl_verify_dates \
		-Q imap_oauth_refresh_command -Q smtp_oauth_refresh_command >"$work_dir/config"
	rg -q 'imap_user = "your.name@company.example"' "$work_dir/config"
	rg -q 'smtp_url = "smtp://smtp.office365.com:587/"' "$work_dir/config"
	rg -q 'imap_authenticators = "xoauth2"' "$work_dir/config"
	rg -q 'smtp_authenticators = "xoauth2"' "$work_dir/config"
else
	printf 'NeoMutt not installed; config parse check skipped\n' >&2
fi
printf 'NeoMutt checks passed\n'
