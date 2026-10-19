#!/usr/bin/env bash

# Shared selectors keep backups and restores paired. No arguments selects all.
select_secrets() {
	secret_names=("$@")
	if [[ ${#secret_names[@]} -eq 0 ]]; then
		secret_names=(shell.env npm.env ssh mud-client)
	fi
	for name in "${secret_names[@]}"; do
		case "$name" in
		shell.env | npm.env | ssh | mud-client) ;;
		*)
			dotfiles_error "unknown secret: $name (use shell.env, npm.env, ssh, mud-client)"
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
	mud-client)
		source_path="${XDG_CONFIG_HOME:-$HOME/.config}/mud-client"
		encrypted_path="$secrets_dir/mud-client.tar.gz.gpg"
		;;
	*)
		source_path="$runtime_dir/$name"
		encrypted_path="$secrets_dir/$name.gpg"
		;;
	esac
}
