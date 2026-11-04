#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image="${1:-ubuntu:24.04}"
container="dotfiles-setup-test-$$"
logs="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-docker.XXXXXX")"
created=false
cleanup() {
	if [[ "$created" == true ]]; then
		docker cp "$container:/home/bootstrap/setup-logs/." "$logs/" >/dev/null 2>&1 || true
		docker rm -f "$container" >/dev/null 2>&1 || true
	fi
	printf 'Docker verification logs: %s\n' "$logs"
}
trap cleanup EXIT

docker info >/dev/null
printf 'Testing fresh Ubuntu WSL bootstrap using %s\n' "$image"
docker run -d --init --name "$container" "$image" sleep infinity >/dev/null
created=true
# Copy tracked working-tree files, never mount the host home into the container.
(cd "$repo_root" && git ls-files -z | tar --null -T - -cf "$logs/checkout.tar")
docker cp "$logs/checkout.tar" "$container:/tmp/checkout.tar"
rm "$logs/checkout.tar"
docker exec -e DEBIAN_FRONTEND=noninteractive "$container" bash -c '
  set -euo pipefail
  apt-get update && apt-get install -y sudo git
  useradd -m -s /bin/bash bootstrap
  printf "bootstrap ALL=(ALL) NOPASSWD:ALL\n" > /etc/sudoers.d/bootstrap
  mkdir /home/bootstrap/dotfiles /home/bootstrap/setup-logs
  tar -xf /tmp/checkout.tar -C /home/bootstrap/dotfiles
  cp /home/bootstrap/dotfiles/nvim/.config/nvim/lazy-lock.json /home/bootstrap/expected-lazy-lock.json
  chown -R bootstrap:bootstrap /home/bootstrap/dotfiles /home/bootstrap/setup-logs
' >"$logs/prerequisites.log" 2>&1
for phase in first repeat check; do
	printf 'Running %s setup pass\n' "$phase"
	docker exec -u bootstrap -w /home/bootstrap/dotfiles \
		-e HOME=/home/bootstrap -e DOTFILES_PLATFORM=wsl -e DOTFILES_NPM_REGISTRY \
		-e DEBIAN_FRONTEND=noninteractive -e TERM=xterm-256color \
		-e CARGO_BUILD_JOBS=2 -e SETUP_PHASE="$phase" "$container" bash -c '
      args=(--skip-secrets)
      if [[ "$SETUP_PHASE" == check ]]; then args+=(--check); fi
      ./setup.sh "${args[@]}" > "/home/bootstrap/setup-logs/$SETUP_PHASE.log" 2>&1 || {
        tail -n 50 "/home/bootstrap/setup-logs/$SETUP_PHASE.log"
        exit 1
      }
    '
done
for shell in bash zsh; do
	docker exec -u bootstrap -e HOME=/home/bootstrap -e TERM=xterm-256color "$container" \
		"$shell" -lic 'set -e; node --version; nvim --version; command -v csharpier; command -v pulumi' \
		>"$logs/$shell-startup.log" 2>&1
done
docker exec -u bootstrap "$container" python3 -c '
import json
from pathlib import Path
expected = json.loads(Path("/home/bootstrap/expected-lazy-lock.json").read_text())
actual = json.loads(Path("/home/bootstrap/.config/nvim/lazy-lock.json").read_text())
assert expected == actual, "Neovim plugin lock changed during setup"
'
printf 'Ubuntu bootstrap, repeat install, dependency checks, shells, and lock preservation passed\n'
