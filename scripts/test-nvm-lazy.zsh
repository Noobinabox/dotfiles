#!/usr/bin/env zsh
set -eu

repo_root=${0:A:h:h}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
export NVM_DIR="$test_root/nvm"
unset NVM_BIN
mkdir -p "$NVM_DIR/alias/lts" "$NVM_DIR/versions/node/v24.18.0/bin" "$test_root/bin"
print 'lts/*' > "$NVM_DIR/alias/default"
print 'lts/test' > "$NVM_DIR/alias/lts/*"
print 'v24.18.0' > "$NVM_DIR/alias/lts/test"
cat > "$NVM_DIR/nvm.sh" <<'FIXTURE'
print loaded >> "$NVM_DIR/loads"
export PATH="$NVM_DIR/../bin:$PATH"
function nvm() { print -r -- "nvm:$*"; }
FIXTURE
cat > "$test_root/bin/node" <<'FIXTURE'
#!/bin/sh
printf '%s\n' "$@"
exit 7
FIXTURE
chmod +x "$test_root/bin/node"
cp "$test_root/bin/node" "$NVM_DIR/versions/node/v24.18.0/bin/node"

source "$repo_root/shell/.config/zsh/nvm-lazy.zsh"
[[ ! -e "$NVM_DIR/loads" ]]
# An external process must see the configured runtime before any wrapper runs.
result=$(/usr/bin/env node external) && exit 1 || command_status=$?
[[ $command_status == 7 && $result == external ]]
[[ ! -e "$NVM_DIR/loads" ]]
# Sourcing twice must not eagerly load NVM or replace its wrappers.
source "$repo_root/shell/.config/zsh/nvm-lazy.zsh"
[[ ! -e "$NVM_DIR/loads" ]]
result=$(node 'argument with spaces' --version) && exit 1 || command_status=$?
[[ $command_status == 7 && "$result" == $'argument with spaces\n--version' ]]
[[ $(<"$NVM_DIR/loads") == loaded ]]
# The command substitution above used a subshell; load in this shell too.
nvm use > "$test_root/result"
[[ $(<"$test_root/result") == 'nvm:use' ]]
[[ ! -v 'functions[node]' && ! -v 'functions[ng]' ]]
source "$repo_root/shell/.config/zsh/nvm-lazy.zsh"
[[ ! -v 'functions[node]' ]]
nvm current > /dev/null
[[ $(wc -l < "$NVM_DIR/loads") == 2 ]]

# No installed NVM must leave system commands alone.
unfunction nvm
export NVM_DIR="$test_root/missing"
source "$repo_root/shell/.config/zsh/nvm-lazy.zsh"
[[ ! -v 'functions[node]' && ! -v 'functions[nvm]' ]]
print 'lazy NVM checks passed'
