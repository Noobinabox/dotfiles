#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT

stub_bin="$test_root/bin"
output_dir="$test_root/output"
mkdir -p "$stub_bin"

cat >"$stub_bin/apt-mark" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' zsh git zsh
STUB

cat >"$stub_bin/snap" <<'STUB'
#!/usr/bin/env bash
printf 'Name Version Rev Tracking Publisher Notes\n'
printf 'demo 1 1 latest/stable example -\n'
printf 'other 2 2 2.0/stable example -\n'
STUB

cat >"$stub_bin/flatpak" <<'STUB'
#!/usr/bin/env bash
printf 'org.example.App\tflathub\n'
STUB

cat >"$stub_bin/npm" <<'STUB'
#!/usr/bin/env bash
cat <<'JSON'
{"dependencies":{"@openai/codex":{"version":"1"},"prettier":{"version":"1"}}}
JSON
STUB

cat >"$stub_bin/node" <<'STUB'
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n' '@openai/codex' prettier
STUB

cat >"$stub_bin/pipx" <<'STUB'
#!/usr/bin/env bash
printf 'black 1.0\n'
STUB

cat >"$stub_bin/cargo" <<'STUB'
#!/usr/bin/env bash
printf 'ripgrep v1.0:\n'
printf '  rg\n'
STUB

cat >"$stub_bin/dotnet" <<'STUB'
#!/usr/bin/env bash
printf 'Package Id Version Commands\n'
printf '%s\n' '---------------------------------'
printf 'csharpier 1.0 csharpier\n'
STUB

chmod +x "$stub_bin"/*
PATH="$stub_bin:$PATH" "$repo_root/scripts/export-installed-apps.sh" --output-dir "$output_dir" >/dev/null

grep -qx 'git' <(tail -n +4 "$output_dir/apt-manual.txt")
grep -qx 'zsh' <(tail -n +4 "$output_dir/apt-manual.txt")
[[ "$(tail -n +4 "$output_dir/apt-manual.txt" | wc -l)" -eq 2 ]]
grep -qx $'demo\tlatest/stable' <(tail -n +4 "$output_dir/snap.tsv")
grep -qx $'org.example.App\tflathub' <(tail -n +4 "$output_dir/flatpak.tsv")
grep -qx '@openai/codex' <(tail -n +4 "$output_dir/npm-global.txt")
grep -qx 'black' <(tail -n +4 "$output_dir/pipx.txt")
grep -qx 'ripgrep' <(tail -n +4 "$output_dir/cargo.txt")
grep -qx 'csharpier' <(tail -n +4 "$output_dir/dotnet-tools.txt")

cp -R "$output_dir" "$test_root/first"
PATH="$stub_bin:$PATH" "$repo_root/scripts/export-installed-apps.sh" --output-dir "$output_dir" >/dev/null
diff -r "$test_root/first" "$output_dir"

# A command that emits partial output and fails must never publish those entries.
printf '#!/usr/bin/env bash\nprintf "partial-package\\n"\nexit 1\n' >"$stub_bin/pipx"
PATH="$stub_bin:$PATH" "$repo_root/scripts/export-installed-apps.sh" --output-dir "$output_dir" >/dev/null 2>&1
! grep -q '^partial-package' "$output_dir/pipx.txt"
grep -q '^# The source command' "$output_dir/pipx.txt"

if "$repo_root/scripts/export-installed-apps.sh" --output-dir >/dev/null 2>&1; then
	exit 1
fi

printf 'installed-app inventory checks passed\n'
