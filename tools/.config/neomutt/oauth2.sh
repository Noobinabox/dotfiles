#!/usr/bin/env bash
set -euo pipefail
umask 077

# Reuse the maintained NeoMutt helper instead of implementing OAuth ourselves.
helper="${NEOMUTT_OAUTH2_HELPER:-}"
if [[ -z "$helper" ]]; then
	for candidate in /usr/share/neomutt/oauth2/mutt_oauth2.py /usr/local/share/neomutt/oauth2/mutt_oauth2.py /opt/homebrew/share/neomutt/oauth2/mutt_oauth2.py; do
		if [[ -r "$candidate" ]]; then
			helper="$candidate"
			break
		fi
	done
fi

if [[ -z "$helper" || ! -f "$helper" || ! -r "$helper" ]]; then
	printf 'NeoMutt OAuth2: install mutt_oauth2.py or set NEOMUTT_OAUTH2_HELPER to its path. See docs/neomutt.md.\n' >&2
	exit 1
fi

state_dir="$HOME/.config/neomutt-work"
mkdir -p "$state_dir"
if [[ -L "$state_dir" ]]; then
	printf 'NeoMutt OAuth2: token directory must be a real directory, not a symlink.\n' >&2
	exit 1
fi
chmod 700 "$state_dir"

# The upstream helper does not persist its encryption command between runs.
recipient_file="$state_dir/gpg-recipient"
if [[ ! -f "$recipient_file" ]]; then
	printf 'NeoMutt OAuth2: save your full GPG fingerprint in ~/.config/neomutt-work/gpg-recipient. See docs/neomutt.md.\n' >&2
	exit 1
fi
recipient="$(<"$recipient_file")"
if [[ ! "$recipient" =~ ^[[:xdigit:]]{40}$ && ! "$recipient" =~ ^[[:xdigit:]]{64}$ ]]; then
	printf 'NeoMutt OAuth2: gpg-recipient must contain one full GPG fingerprint (40 or 64 hex characters).\n' >&2
	exit 1
fi

token_file="$state_dir/work.tokens.gpg"
if [[ -L "$token_file" ]]; then
	printf 'NeoMutt OAuth2: refusing a symlinked token file.\n' >&2
	exit 1
fi

# Pinentry needs the terminal when GPG is launched from an OAuth command pipe.
if [[ -t 0 ]]; then
	export GPG_TTY
	GPG_TTY="$(tty)"
fi

exec python3 "$helper" "$token_file" --encryption-pipe "gpg --encrypt --recipient $recipient" "$@"
