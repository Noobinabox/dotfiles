#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
check_only=false
run_stow=false
node_version="${DOTFILES_NODE_VERSION:-24.18.0}"
neovim_version="${DOTFILES_NEOVIM_VERSION:-v0.12.3}"

usage() {
	command cat <<'USAGE'
Usage: ./setup.sh [--check] [--stow]

Bootstraps applications used by this dotfiles repository.

Options:
  --check   Report missing tools without installing.
  --stow    Run scripts/install.sh after dependency setup.
  --help    Show this help.
USAGE
}

while [[ "$#" -gt 0 ]]; do
	case "$1" in
	--check)
		check_only=true
		;;
	--stow)
		run_stow=true
		;;
	--help | -h)
		usage
		exit 0
		;;
	*)
		printf 'unknown option: %s\n' "$1" >&2
		usage >&2
		exit 2
		;;
	esac
	shift
done

# Provides dotfiles_pkg_manager and dotfiles_pkg_install.
# shellcheck source=shell/.bashrc_aliases
source "$repo_root/shell/.bashrc_aliases"
# shellcheck source=scripts/lib/gum.sh
source "$repo_root/scripts/lib/gum.sh"

if [[ "$check_only" == false ]]; then
	export DOTFILES_ASSUME_YES=1
fi

log() {
	dotfiles_heading "$*"
}

info() {
	dotfiles_info "$*"
}

missing=()

have() {
	command -v "$1" >/dev/null 2>&1
}

have_any() {
	local cmd
	for cmd in "$@"; do
		have "$cmd" && return 0
	done
	return 1
}

have_pywal16() {
	have wal || [[ -x "$HOME/.local/lib/python/bin/wal" ]]
}

record_missing() {
	missing+=("$1")
	info "missing: $1"
}

ensure_dir() {
	if [[ "$check_only" == true ]]; then
		return 0
	fi
	mkdir -p "$1"
}

install_system_packages() {
	local manager packages=()

	log "system packages"
	manager="$(dotfiles_pkg_manager)"
	info "package manager: $manager"

	case "$manager" in
	apt)
		packages=(
			bash zsh git openssh-client curl ca-certificates unzip tar xz-utils
			build-essential make cmake stow gpg ripgrep fd-find fzf yazi bat tmux
			shellcheck shfmt less bash-completion libnotify-bin direnv gh glow gum htop
			bpytop gdb emacs lua5.4 clang clangd clang-format gcc g++ default-jdk
			python3-pipx
		)
		;;
	dnf)
		packages=(
			bash zsh git openssh-clients curl ca-certificates unzip tar xz make cmake
			stow gnupg2 ripgrep fd-find fzf yazi bat tmux ShellCheck shfmt less
			bash-completion libnotify direnv gh glow gum htop bpytop gdb emacs lua
			clang clang-tools-extra gcc gcc-c++ java-latest-openjdk-devel pipx
		)
		;;
	pacman)
		packages=(
			bash zsh git openssh curl ca-certificates unzip tar xz base-devel make
			cmake stow gnupg ripgrep fd fzf yazi bat tmux shellcheck shfmt less
			bash-completion libnotify direnv github-cli glow gum htop bpytop gdb emacs
			lua clang gcc jdk-openjdk python-pipx
		)
		;;
	zypper)
		packages=(
			bash zsh git openssh curl ca-certificates unzip tar xz make cmake stow
			gpg2 ripgrep fd fzf yazi bat tmux ShellCheck shfmt less bash-completion
			libnotify-tools direnv gh glow gum htop bpytop gdb emacs lua54 clang clang-tools
			gcc gcc-c++ java-devel python3-pipx
		)
		;;
	apk)
		packages=(
			bash zsh git openssh-client curl ca-certificates unzip tar xz build-base
			make cmake stow gnupg ripgrep fd fzf yazi bat tmux shellcheck shfmt less
			bash-completion libnotify direnv github-cli glow gum htop bpytop gdb emacs
			lua5.4 clang clang-extra-tools gcc g++ openjdk21 py3-pipx
		)
		;;
	*)
		record_missing "supported distro package manager"
		return
		;;
	esac

	if [[ "$check_only" == true ]]; then
		for cmd in bash zsh git ssh curl stow gpg rg fzf yazi ya tmux shellcheck shfmt lesspipe notify-send direnv gh glow gum htop bpytop gdb emacs lua clangd clang-format gcc g++ make cmake java javac; do
			have "$cmd" || record_missing "$cmd"
		done
		if ! have_pywal16; then
			record_missing "pywal16"
			have pipx || record_missing "pipx"
		fi
		have_any fd fdfind || record_missing "fd/fdfind"
		have_any bat batcat || record_missing "bat/batcat"
		return
	fi

	dotfiles_pkg_install "${packages[@]}"
}

install_oh_my_zsh() {
	log "Oh My Zsh and Powerlevel10k"

	if [[ -d "$HOME/.oh-my-zsh" ]]; then
		info "present: ~/.oh-my-zsh"
	elif [[ "$check_only" == true ]]; then
		record_missing "$HOME/.oh-my-zsh"
	else
		git clone https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
	fi

	if [[ -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]]; then
		info "present: powerlevel10k"
	elif [[ "$check_only" == true ]]; then
		record_missing "powerlevel10k"
	else
		git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
	fi
}

install_nvm_node() {
	log "NVM and Node"

	if [[ ! -s "$HOME/.nvm/nvm.sh" ]]; then
		if [[ "$check_only" == true ]]; then
			record_missing "nvm"
			return
		fi
		git clone https://github.com/nvm-sh/nvm.git "$HOME/.nvm"
	fi

	# shellcheck source=/dev/null
	source "$HOME/.nvm/nvm.sh"

	if ! nvm version "$node_version" >/dev/null 2>&1; then
		if [[ "$check_only" == true ]]; then
			record_missing "node $node_version"
			return
		fi
		nvm install "$node_version"
	fi

	nvm use "$node_version" >/dev/null
}

install_npm_globals() {
	local packages=(
		@angular/cli
		@openai/codex
		bash-language-server
		markdownlint-cli
		prettier
		typescript
		typescript-language-server
		yaml-language-server
		vscode-langservers-extracted
	)

	log "npm global tools"

	if ! have npm; then
		record_missing "npm"
		return
	fi

	if [[ "$check_only" == true ]]; then
		for cmd in ng codex bash-language-server markdownlint prettier tsc typescript-language-server yaml-language-server vscode-json-language-server vscode-html-language-server vscode-css-language-server; do
			have "$cmd" || record_missing "$cmd"
		done
		return
	fi

	npm install -g "${packages[@]}"
}

install_user_local_tools() {
	log "user-local tools"
	ensure_dir "$HOME/.local/bin"
	ensure_dir "$HOME/.local/opt"

	if have rustup && [[ -s "$HOME/.cargo/env" ]]; then
		info "present: rustup"
	elif [[ "$check_only" == true ]]; then
		record_missing "rustup"
	else
		curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y
	fi

	if have pulumi; then
		info "present: pulumi"
	elif [[ "$check_only" == true ]]; then
		record_missing "pulumi"
	else
		curl -fsSL https://get.pulumi.com | sh
	fi

	if have nvim; then
		info "present: nvim"
	elif [[ "$check_only" == true ]]; then
		record_missing "nvim"
	else
		local archive="$HOME/.local/opt/nvim-linux-x86_64.tar.gz"
		curl -fsSL "https://github.com/neovim/neovim/releases/download/${neovim_version}/nvim-linux-x86_64.tar.gz" -o "$archive"
		tar -C "$HOME/.local/opt" -xzf "$archive"
		ln -sfn "$HOME/.local/opt/nvim-linux-x86_64/bin/nvim" "$HOME/.local/bin/nvim"
	fi

	if have zoxide; then
		info "present: zoxide"
	elif [[ "$check_only" == true ]]; then
		record_missing "zoxide"
	else
		curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
	fi

	if have_pywal16; then
		info "present: pywal16"
	elif [[ "$check_only" == true ]]; then
		record_missing "pywal16"
	elif have pipx; then
		pipx install pywal16
	else
		record_missing "pipx"
	fi

	if [[ ! -e "$HOME/.local/bin/fd" && -x /usr/bin/fdfind ]]; then
		if [[ "$check_only" == true ]]; then
			record_missing "$HOME/.local/bin/fd symlink"
		else
			ln -s /usr/bin/fdfind "$HOME/.local/bin/fd"
		fi
	fi
}

install_dotnet_tools() {
	log "dotnet tools"

	if ! have dotnet; then
		record_missing "dotnet"
		return
	fi

	if have csharpier; then
		info "present: csharpier"
	elif [[ "$check_only" == true ]]; then
		record_missing "csharpier"
	else
		dotnet tool install --global csharpier
	fi
}

install_neovim_tools() {
	local mason_packages=(
		clangd
		codebook-lsp
		harper-ls
		lua-language-server
		marksman
		omnisharp
		typescript-language-server
		cmake-format
		csharpier
		prettier
		pyright
	)

	mason_tool_present() {
		local tool="$1"

		case "$tool" in
		omnisharp)
			[[ -x "$HOME/.local/share/nvim/mason/bin/OmniSharp" || -x "$HOME/.local/share/nvim/mason/bin/omnisharp-mono" ]]
			;;
		*)
			[[ -x "$HOME/.local/share/nvim/mason/bin/$tool" ]]
			;;
		esac
	}

	log "Neovim plugins and Mason tools"

	if ! have nvim; then
		record_missing "nvim"
		return
	fi

	if [[ "$check_only" == true ]]; then
		nvim --headless "+lua print('nvim-ok')" +qa >/dev/null 2>&1
		for tool in "${mason_packages[@]}"; do
			mason_tool_present "$tool" || record_missing "mason:$tool"
		done
		return
	fi

	nvim --headless "+Lazy! sync" +qa
	nvim --headless "+MasonInstall ${mason_packages[*]}" +qa
}

install_doom() {
	log "Doom Emacs"

	if [[ ! -d "$HOME/.config/emacs" ]]; then
		if [[ "$check_only" == true ]]; then
			record_missing "$HOME/.config/emacs"
			return
		fi
		git clone --depth=1 https://github.com/doomemacs/core "$HOME/.config/emacs"
	fi

	if [[ ! -x "$HOME/.config/emacs/bin/doom" ]]; then
		record_missing "doom executable"
		return
	fi

	if [[ "$check_only" == true ]]; then
		info "present: doom"
		return
	fi

	"$HOME/.config/emacs/bin/doom" sync
}

install_tmux_plugins() {
	log "tmux plugins"

	if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
		if [[ "$check_only" == true ]]; then
			record_missing "tmux plugin manager"
			return
		fi
		git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
	fi

	if [[ "$check_only" == true ]]; then
		info "present: tpm"
		return
	fi

	"$HOME/.tmux/plugins/tpm/bin/install_plugins"
}

validate_shells() {
	log "shell validation"
	zsh -n "$HOME/.zshrc"
	bash -n "$HOME/.bashrc"
}

validate_wsl_helpers() {
	log "WSL helpers"
	if grep -qi microsoft /proc/version 2>/dev/null; then
		have shutdown.exe || record_missing "shutdown.exe"
	else
		info "not WSL; skipping shutdown.exe check"
	fi
}

install_system_packages
install_oh_my_zsh
install_nvm_node
install_npm_globals
install_user_local_tools
install_dotnet_tools
install_neovim_tools
install_doom
install_tmux_plugins
validate_wsl_helpers

if [[ "$run_stow" == true && "$check_only" == false ]]; then
	log "stowing dotfiles"
	"$repo_root/scripts/install.sh"
fi

validate_shells

if [[ "$check_only" == true && "${#missing[@]}" -gt 0 ]]; then
	log "missing dependencies"
	printf '  %s\n' "${missing[@]}"
	exit 1
fi

log "setup complete"
info "secrets are separate; run scripts/decrypt-secrets.sh when needed"
