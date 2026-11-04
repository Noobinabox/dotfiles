#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
check_only=false
run_stow=true
restore_encrypted_secrets=true
print_platform=false
node_version="${DOTFILES_NODE_VERSION:-lts/*}"
neovim_version="${DOTFILES_NEOVIM_VERSION:-v0.12.3}"
gum_version=2.0.2
glow_version=3.0.0

detect_platform() {
	if [[ -n "${DOTFILES_PLATFORM:-}" ]]; then
		printf '%s\n' "$DOTFILES_PLATFORM"
		return
	fi

	case "$(uname -s)" in
	Darwin*) printf 'macos\n' ;;
	MINGW* | MSYS* | CYGWIN*) printf 'windows\n' ;;
	Linux*)
		if [[ -n "${PREFIX:-}" && -x "$PREFIX/bin/pkg" ]]; then
			printf 'termux\n'
		elif [[ -r /etc/os-release ]] && . /etc/os-release && [[ "${ID:-}" == fedora ]]; then
			printf 'fedora\n'
		elif [[ ! -f /.dockerenv ]] && grep -qi microsoft /proc/version 2>/dev/null; then
			printf 'wsl\n'
		else
			printf 'linux\n'
		fi
		;;
	*) printf 'unknown\n' ;;
	esac
}

platform="$(detect_platform)"

usage() {
	command cat <<'USAGE'
Usage: ./setup.sh [--check] [--stow | --no-stow] [--skip-secrets] [--print-platform]

Bootstraps applications used by this dotfiles repository.

Options:
  --check   Report missing tools without installing.
  --stow    Stow configs before plugin setup (default).
  --no-stow Install tools only; skip configuration and plugin setup.
  --skip-secrets Skip restoring encrypted environment files and SSH keys.
  --print-platform
            Print the detected platform and exit without installing anything.
  --help    Show this help.
USAGE
}

while [[ "$#" -gt 0 ]]; do
	case "$1" in
	--print-platform)
		print_platform=true
		;;
	--check)
		check_only=true
		;;
	--skip-secrets)
		restore_encrypted_secrets=false
		;;
	--no-stow)
		run_stow=false
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

if [[ "$print_platform" == true ]]; then
	printf '%s\n' "$platform"
	exit 0
fi

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

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.dotnet/tools:$HOME/.pulumi/bin:$PATH"
export NPM_CONFIG_USERCONFIG=/dev/null
export NPM_CONFIG_REGISTRY="${DOTFILES_NPM_REGISTRY:-https://registry.npmjs.org}"
missing=()

have() {
	type -P "$1" >/dev/null 2>&1
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
	if [[ "$platform" == windows || "$platform" == macos ]]; then
		info "$platform detected; use the native package manager for system packages"
		return 0
	fi
	manager="$(dotfiles_pkg_manager)"
	info "package manager: $manager"

	case "$manager" in
	pkg)
		packages=(bash zsh git openssh curl ca-certificates unzip tar xz-utils stow
			ripgrep fd fzf yazi bat tmux w3m shellcheck shfmt less direnv gh glow
			gum htop gdb emacs lua54 clang openjdk-21 python neovim nodejs
			rust golang)
		;;
	apt)
		packages=(
			bash zsh git openssh-client curl ca-certificates unzip tar xz-utils
			build-essential make cmake stow gpg ripgrep fd-find fzf bat tmux w3m lynx
			shellcheck shfmt less bash-completion libnotify-bin direnv gh htop
			bpytop gdb emacs lua5.4 clang clangd clang-format gcc g++ default-jdk
			pipx python3-venv software-properties-common jq ffmpeg poppler-utils
			libasound2-dev libdbus-1-dev libssl-dev pkg-config
		)
		;;
	dnf)
		packages=(
			bash zsh git openssh-clients curl ca-certificates unzip tar xz make cmake
			stow gnupg2 ripgrep fd-find fzf yazi bat tmux w3m kitty ShellCheck shfmt less
			bash-completion libnotify direnv gh glow gum htop bpytop gdb emacs lua
			clang clang-tools-extra gcc gcc-c++ java-latest-openjdk-devel pipx
		)
		;;
	pacman)
		packages=(
			bash zsh git openssh curl ca-certificates unzip tar xz base-devel make
			cmake stow gnupg ripgrep fd fzf yazi bat tmux w3m kitty shellcheck shfmt less
			bash-completion libnotify direnv github-cli glow gum htop bpytop gdb emacs
			lua clang gcc jdk-openjdk python-pipx
		)
		;;
	zypper)
		packages=(
			bash zsh git openssh curl ca-certificates unzip tar xz make cmake stow
			gpg2 ripgrep fd fzf yazi bat tmux w3m ShellCheck shfmt less bash-completion
			libnotify-tools direnv gh glow gum kitty htop bpytop gdb emacs lua54 clang clang-tools
			gcc gcc-c++ java-devel python3-pipx
		)
		;;
	apk)
		packages=(
			bash zsh git openssh-client curl ca-certificates unzip tar xz build-base
			make cmake stow gnupg ripgrep fd fzf yazi bat tmux w3m shellcheck shfmt less
			bash-completion libnotify direnv github-cli glow gum kitty htop bpytop gdb emacs
			lua5.4 clang clang-extra-tools gcc g++ openjdk21 py3-pipx
		)
		;;
	*)
		record_missing "supported distro package manager"
		return
		;;
	esac

	if [[ "$check_only" == true ]]; then
		for cmd in bash zsh git ssh curl stow gpg jq ffmpeg pdftotext lynx pipx rg fzf yazi ya tmux w3m shellcheck shfmt lesspipe notify-send direnv gh glow gum htop bpytop gdb emacs lua clangd clang-format gcc g++ make cmake java javac; do
			have "$cmd" || record_missing "$cmd"
		done
		if [[ "$platform" != termux && "$platform" != wsl ]]; then
			have kitty || record_missing kitty
		fi
		if ! have_pywal16; then
			record_missing "pywal16"
			have pipx || record_missing "pipx"
		fi
		have_any fd fdfind || record_missing "fd/fdfind"
		have_any bat batcat || record_missing "bat/batcat"
		return
	fi

	if [[ "$manager" == apt ]]; then
		sudo apt-get update
		sudo apt-get install -y curl ca-certificates gpg software-properties-common
		sudo add-apt-repository -y universe
		install_ubuntu_repositories
		packages+=(yazi dotnet-sdk-10.0 dotnet-sdk-8.0 aspnetcore-runtime-8.0)
		if [[ "$platform" != wsl ]]; then packages+=(kitty); fi
	fi
	dotfiles_pkg_install "${packages[@]}"
	if [[ "$manager" == apt ]]; then install_charm_tools; fi
}

install_charm_tools() (
	local directory tool version filename base checksum arch
	directory="$(mktemp -d)"
	trap 'rm -rf "$directory"' EXIT
	arch="$(dpkg --print-architecture)"
	for tool in gum glow; do
		if have "$tool"; then continue; fi
		case "$tool" in gum) version="$gum_version" ;; glow) version="$glow_version" ;; esac
		filename="${tool}_${version}_${arch}.deb"
		base="https://github.com/charmbracelet/$tool/releases/download/v$version"
		curl --retry 3 -fsSL "$base/$filename" -o "$directory/$filename"
		curl --retry 3 -fsSL "$base/checksums.txt" -o "$directory/checksums.txt"
		checksum="$(awk -v file="$filename" '$2 == file {print $1}' "$directory/checksums.txt")"
		[[ "$checksum" =~ ^[a-f0-9]{64}$ ]] || {
			printf 'Missing checksum for %s\n' "$filename" >&2
			exit 1
		}
		(cd "$directory" && printf '%s  %s\n' "$checksum" "$filename" | sha256sum --check --status)
		sudo apt-get install -y "$directory/$filename"
	done
)

install_ubuntu_repositories() {
	# Yazi publishes signed packages outside the Ubuntu archives.
	sudo mkdir -p /etc/apt/keyrings
	curl -fsSL https://yazi-rs.github.io/builds/yazi-keyring.gpg | sudo tee /etc/apt/keyrings/yazi.gpg >/dev/null
	printf 'deb [signed-by=/etc/apt/keyrings/yazi.gpg] https://yazi-rs.github.io/builds/ stable main\n' | sudo tee /etc/apt/sources.list.d/yazi.list >/dev/null
	sudo apt-get update
	local package
	for package in dotnet-sdk-8.0 dotnet-sdk-10.0; do
		if ! apt-cache policy "$package" | grep -E 'Candidate: [0-9]' >/dev/null; then
			sudo add-apt-repository -y ppa:dotnet/backports
			sudo apt-get update
			break
		fi
	done
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
	source "$HOME/.nvm/nvm.sh" --no-use

	if [[ "$(nvm version "$node_version")" == "N/A" ]]; then
		if [[ "$check_only" == true ]]; then
			record_missing "node $node_version"
			return
		fi
		nvm install "$node_version"
	fi

	if [[ "$check_only" == false ]]; then nvm alias default "$node_version" >/dev/null; fi
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

	# Some networks reject TLS to the primary npm hostname. Both endpoints
	# belong to npm; retain certificate checks and honor explicit overrides.
	if ! curl --connect-timeout 15 --max-time 30 -fsS "$NPM_CONFIG_REGISTRY/-/ping" >/dev/null; then
		if [[ -n "${DOTFILES_NPM_REGISTRY:-}" ]]; then
			printf 'Configured npm registry is unreachable; check DOTFILES_NPM_REGISTRY and network access.\n' >&2
			return 1
		fi
		export NPM_CONFIG_REGISTRY=https://registry.npmjs.com
		curl --connect-timeout 15 --max-time 30 -fsS "$NPM_CONFIG_REGISTRY/-/ping" >/dev/null
		info "using npm alternate HTTPS endpoint: $NPM_CONFIG_REGISTRY"
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

	if have nvim && nvim --version | sed -n '1p' | grep -Eq '^NVIM v0\.12\.[0-9]+$'; then
		info "present: nvim"
	elif [[ "$check_only" == true ]]; then
		record_missing "nvim $neovim_version"
	else
		if [[ "$platform" != linux && "$platform" != fedora && "$platform" != wsl ]]; then
			record_missing "nvim (install with the native platform package manager)"
			return
		fi
		local arch
		case "$(uname -m)" in
		x86_64 | amd64) arch=x86_64 ;;
		aarch64 | arm64) arch=arm64 ;;
		*)
			printf 'Unsupported Neovim architecture\n' >&2
			exit 1
			;;
		esac
		[[ "$neovim_version" =~ ^v0\.12\.[0-9]+$ ]] || {
			printf 'DOTFILES_NEOVIM_VERSION must be v0.12.x\n' >&2
			exit 1
		}
		local archive="$HOME/.local/opt/nvim-linux-$arch.tar.gz"
		curl -fsSL "https://github.com/neovim/neovim/releases/download/${neovim_version}/nvim-linux-${arch}.tar.gz" -o "$archive"
		tar -C "$HOME/.local/opt" -xzf "$archive"
		ln -sfn "$HOME/.local/opt/nvim-linux-${arch}/bin/nvim" "$HOME/.local/bin/nvim"
		hash -r
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

	if [[ "$check_only" == true && "$(dotfiles_pkg_manager)" == apt ]]; then
		local version
		for version in 8 10; do
			dotnet --list-sdks | grep -Eq "^${version}\\." || record_missing "dotnet SDK $version"
		done
		dotnet --list-runtimes | grep -Eq '^Microsoft.AspNetCore.App 8\.' || record_missing "ASP.NET Core runtime 8"
	fi
	if have csharpier; then
		info "present: csharpier"
	elif [[ "$check_only" == true ]]; then
		record_missing "csharpier"
	else
		dotnet tool install --global csharpier
	fi
}

install_tui_tools() {
	log "Lazygit and Sesh"
	if [[ "$check_only" == true || "$platform" == windows ]]; then
		local tool
		for tool in lazygit sesh; do
			have "$tool" || record_missing "$tool"
		done
		if [[ "$check_only" == false && "$platform" == windows ]]; then
			info "install missing TUI tools with the native Windows package manager"
		fi
	else
		DOTFILES_PLATFORM="$platform" bash "$repo_root/scripts/install-tui-tools.sh"
	fi
}

install_neovim_tools() {
	local mason_packages=(
		clangd
		codebook
		harper-ls
		lua-language-server
		marksman
		omnisharp
		typescript-language-server
		cmakelang
		csharpier
		prettier
		pyright
	)

	mason_tool_present() {
		local tool="$1"

		case "$tool" in
		codebook) [[ -x "$HOME/.local/share/nvim/mason/bin/codebook-lsp" ]] ;;
		cmakelang) [[ -x "$HOME/.local/share/nvim/mason/bin/cmake-format" ]] ;;
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
		# Check only filesystem state; starting Neovim can install plugins.
		for tool in "${mason_packages[@]}"; do
			mason_tool_present "$tool" || record_missing "mason:$tool"
		done
		return
	fi

	(
		local lockfile="$HOME/.config/nvim/lazy-lock.json"
		local backup
		backup="$(mktemp)"
		cp "$lockfile" "$backup"
		# Lazy install rewrites the lock, including already installed checkouts.
		# Preserve the tracked versions before invoking restore.
		trap 'cp "$backup" "$lockfile"; rm -f "$backup"' EXIT
		nvim --headless "+Lazy! install" +qa
		cp "$backup" "$lockfile"
		nvim --headless "+Lazy! restore" +qa
	)
	if ! nvim --headless "+MasonInstall ${mason_packages[*]}" +qa; then
		printf 'Mason tool installation failed. Recent installer diagnostics:\n' >&2
		tail -n 30 "${XDG_STATE_HOME:-$HOME/.local/state}/nvim/mason.log" >&2 || true
		return 1
	fi
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

	# TPM reads options through tmux; a fresh WSL home has no running server.
	(
		local socket="dotfiles-setup-$$"
		trap 'tmux -L "$socket" kill-server 2>/dev/null || true' EXIT
		tmux -L "$socket" -f "$HOME/.config/tmux/tmux.conf" new-session -d -s bootstrap
		local tmux_context
		tmux_context="$(tmux -L "$socket" display-message -p '#{socket_path}'),0,0"
		local status=0
		TMUX="$tmux_context" "$HOME/.tmux/plugins/tpm/bin/install_plugins" || status=$?
		tmux -L "$socket" kill-server
		exit "$status"
	)
}

install_cargo_tools() {
	local tool
	for tool in spotify_player tree-sitter; do
		if have "$tool"; then
			if [[ "$tool" != tree-sitter ]]; then continue; fi
			local version
			version="$(tree-sitter --version | awk '{print $2}')"
			if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$(printf '%s\n' 0.26.1 "$version" | sort -V | sed -n '1p')" == 0.26.1 ]]; then continue; fi
		fi
		if [[ "$check_only" == true ]]; then
			record_missing "$tool"
			continue
		fi
		case "$tool" in
		tree-sitter) cargo install tree-sitter-cli --version 0.26.13 --locked --force ;;
		spotify_player) cargo install spotify_player --locked ;;
		esac
	done
}

restore_setup_secrets() {
	if [[ "$check_only" == true || "$run_stow" == false || "$restore_encrypted_secrets" == false ]]; then
		return 0
	fi
	log "restoring encrypted secrets"
	if ! "$repo_root/scripts/decrypt-secrets.sh"; then
		printf 'Secret restore failed. Supply the encryption passphrase or import the required GPG private key, then retry scripts/decrypt-secrets.sh. Use --skip-secrets for a tool/config-only setup.\n' >&2
		return 1
	fi
}

validate_shells() {
	log "shell validation"
	if have zsh; then zsh -n "$repo_root/shell/.zshrc"; fi
	bash -n "$repo_root/shell/.bashrc"
}

validate_wsl_helpers() {
	log "WSL helpers"
	if [[ "$platform" == wsl ]]; then
		have shutdown.exe || info "optional Windows interop unavailable: shutdown.exe"
		have wt.exe || info "optional Windows Terminal unavailable: wt.exe"
	else
		info "not WSL; skipping shutdown.exe check"
	fi
}

install_system_packages
install_oh_my_zsh
install_nvm_node
install_npm_globals
install_user_local_tools
install_cargo_tools
install_tui_tools
install_dotnet_tools

if [[ "$run_stow" == true ]]; then
	if [[ "$check_only" == false ]]; then
		log "stowing dotfiles"
		"$repo_root/scripts/install.sh"
	fi
	install_neovim_tools
	install_doom
	install_tmux_plugins
	if have ya; then
		if [[ "$check_only" == false ]]; then ya pkg install; fi
	else
		record_missing "ya"
	fi
fi
validate_wsl_helpers
validate_shells

if [[ "${#missing[@]}" -gt 0 ]]; then
	log "missing dependencies"
	printf '  %s\n' "${missing[@]}"
	exit 1
fi

restore_setup_secrets
log "setup complete"
