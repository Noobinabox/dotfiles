# Load NVM only when a Node tool is first used, including in a clean login PATH.
if [[ -s "$NVM_DIR/nvm.sh" ]] && (( ! $+functions[nvm] )); then
  # External tools (including editor language servers) need Node on PATH even
  # before a shell wrapper runs. Resolve ordinary aliases without spawning NVM.
  function _dotfiles_node_path() {
    local version=default candidate
    local -A seen
    local -a versions
    if [[ -n ${NVM_BIN:-} && -x "$NVM_BIN/node" ]]; then
      path=("$NVM_BIN" ${path:#"$NVM_BIN"})
      return 0
    fi
    while [[ -r "$NVM_DIR/alias/$version" ]]; do
      [[ -z ${seen[$version]:-} ]] || return 1
      seen[$version]=1
      version=$(<"$NVM_DIR/alias/$version")
      version=${${version%%$'\n'*}//[[:space:]]/}
    done
    [[ $version == system ]] && return 0
    case $version in
      node|stable) version='' ;;
      *) [[ $version =~ '^v?[0-9]+(\.[0-9]+){0,2}$' ]] || return 1
         version=${version#v} ;;
    esac
    versions=("$NVM_DIR"/versions/node/v*(N/nOn))
    for candidate in "${versions[@]}"; do
      if [[ -z $version || ${candidate:t} == v$version || ${candidate:t} == v$version.* ]]; then
        [[ -x "$candidate/bin/node" ]] || continue
        export NVM_BIN="$candidate/bin"
        path=("$NVM_BIN" ${path:#"$NVM_BIN"})
        return 0
      fi
    done
    return 1
  }
  # Let NVM handle uncommon aliases or unavailable defaults with its normal
  # diagnostics instead of guessing which installed runtime should be used.
  if ! _dotfiles_node_path; then
    source "$NVM_DIR/nvm.sh"
  fi
  unfunction _dotfiles_node_path
fi

if [[ -s "$NVM_DIR/nvm.sh" ]] && (( ! $+functions[nvm] )); then
  function _dotfiles_load_nvm() {
    unfunction nvm node npm npx corepack ng yarn pnpm
    source "$NVM_DIR/nvm.sh" || return
    [[ ! -s "$NVM_DIR/bash_completion" ]] || source "$NVM_DIR/bash_completion"
    return 0
  }

  function nvm() { _dotfiles_load_nvm && nvm "$@"; }
  function node() { _dotfiles_load_nvm && node "$@"; }
  function npm() { _dotfiles_load_nvm && npm "$@"; }
  function npx() { _dotfiles_load_nvm && npx "$@"; }
  function corepack() { _dotfiles_load_nvm && corepack "$@"; }
  function ng() { _dotfiles_load_nvm && ng "$@"; }
  function yarn() { _dotfiles_load_nvm && yarn "$@"; }
  function pnpm() { _dotfiles_load_nvm && pnpm "$@"; }
fi
