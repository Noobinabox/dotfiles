#!/usr/bin/env bash

# Resolve the terminal before an archive pipeline replaces GPG's stdin.
prepare_gpg_terminal() {
	local terminal
	if terminal="$(tty 2>/dev/null)"; then
		GPG_TTY="$terminal"
		export GPG_TTY
	elif [[ -t 2 ]] && terminal="$(tty <&2 2>/dev/null)"; then
		GPG_TTY="$terminal"
		export GPG_TTY
	fi
}

# Shared selectors keep backups and restores paired. No arguments selects all.
select_secrets() {
	secret_names=("$@")
	if [[ ${#secret_names[@]} -eq 0 ]]; then
		secret_names=(shell.env npm.env ssh)
	fi
	for name in "${secret_names[@]}"; do
		case "$name" in
		shell.env | npm.env | ssh) ;;
		*)
			dotfiles_error "unknown secret: $name (use shell.env, npm.env, ssh)"
			return 1
			;;
		esac
	done
}

secret_paths() {
	local name="$1"
	case "$name" in
	ssh)
		source_path="$HOME/.ssh"
		encrypted_path="$secrets_dir/ssh.tar.gz.gpg"
		;;
	*)
		source_path="$runtime_dir/$name"
		encrypted_path="$secrets_dir/$name.gpg"
		;;
	esac
}
