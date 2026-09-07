#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/vault/Dailies"

cat >"$tmp/vault/Alpha.md" <<'EOF'
---
id: Alpha ID
aliases: [First Alias]
tags: [project, test-note]
created: 2026-01-01
updated: 2026-01-02
---
# Alpha
Paragraph #keep with `inline code`, **bold**, *italic*, <u>under</u>, ++gone++, and ~~strike~~.
---
Combined ***both*** and ___bothunder___.
Nested **bold *inner*** and *italic **inner***.
Code span `**no** [[Beta]]`.
| Name | Link |
| --- | --- |
| Alpha | [[Beta]] |
- [ ] Root task [[First Alias]]
- Bullet [site](https://example.com) and <https://example.org> and <mailto:test@example.com>.
- Link with [title](https://example.com "Title") and [paren](https://example.com/a_(b)).
- More links [single](https://example.com 'Title') and [titleparen](https://example.com (Title)).
- Nested label [a [nested] label](https://example.net).
- Angle link [angle](<https://example.com/a-b>).
- Escaped paren [escaped](https://example.com/a\)b).
- Email <user@example.com>.
- Reference [docs][docs ref].
- Angle reference [angle ref][angle ref].
- Space angle reference [space ref][space ref].
- Reference title variants [single ref][single ref] and [paren ref][paren ref].
- Collapsed [docs ref][] and shortcut [docs ref].
* Star bullet ![`image`](image.png)
+ Plus bullet
## Section #tag
  - [>] Active [[#Section]]
[[Beta|**B**]]
~~~python
[[Not A Link]]
~~~
> [!note] Heading
> Body
>
> [!warning]
> Second body

[docs ref]: https://example.com/docs
[angle ref]: <https://example.com/angle>
[space ref]: <https://example.com/a b>
[single ref]: https://example.com/single 'Title'
[paren ref]: https://example.com/paren (Title)
EOF

cat >"$tmp/vault/Beta.md" <<'EOF'
# Beta
EOF

cat >"$tmp/vault/Dailies/2026-09-02.md" <<'EOF'
# 2026-09-02
[[Alpha]]
[1/3] [/] [C-c]
[missing collapsed][]
[missing explicit][missing-ref]
[[Missing Note]] and [missing explicit][missing-ref]
EOF

"$repo_root/scripts/convert-vault-to-org.py" --vault "$tmp/vault" --output "$tmp/out" >/dev/null

alpha_file="$(find "$tmp/out" -maxdepth 1 -name '*-alpha_id.org' -print -quit)"
beta_file="$(find "$tmp/out" -maxdepth 1 -name '*-beta.org' -print -quit)"
daily_file="$(find "$tmp/out/daily" -maxdepth 1 -name '*-2026-09-02.org' -print -quit)"

test -n "$alpha_file"
test -n "$beta_file"
test -n "$daily_file"
test -f "$tmp/out/.org-conversion-output"
grep -q '^| Source | Target | Title | Org ID | Aliases |$' "$tmp/out/conversion-ledger.md"
grep -q '| Alpha.md | .* | Alpha ID | .* | First Alias |' "$tmp/out/conversion-ledger.md"
grep -q '^#+title: Alpha ID$' "$alpha_file"
grep -q '^#+ROAM_ALIASES: "First Alias"$' "$alpha_file"
grep -q '^#+filetags: :project:test_note:$' "$alpha_file"
grep -q '^Paragraph #keep with ~inline code~, \*bold\*, /italic/, _under_, +gone+, and +strike+\.$' "$alpha_file"
! grep -q '^-----$' "$alpha_file"
grep -q '^Combined \*/both/\* and \*/bothunder/\*\.$' "$alpha_file"
grep -q '^Nested \*bold /inner/\* and /italic \*inner\*/\.$' "$alpha_file"
grep -q '^Code span ~\*\*no\*\* \[\[Beta\]\]~\.$' "$alpha_file"
grep -Eq '^\| Name[[:space:]]+\| Link[[:space:]]+\|$' "$alpha_file"
grep -Eq '^\|[-]+\+[-]+\|$' "$alpha_file"
grep -Eq '^\| Alpha[[:space:]]+\| \[\[id:.*\]\[Beta\]\] \|$' "$alpha_file"
grep -q '^+ Bullet \[\[https://example.com\]\[site\]\] and \[\[https://example.org\]\] and \[\[mailto:test@example.com\]\]\.$' "$alpha_file"
grep -q '^+ Link with \[\[https://example.com\]\[title\]\] and \[\[https://example.com/a_(b)\]\[paren\]\]\.$' "$alpha_file"
grep -q "^+ More links \\[\\[https://example.com\\]\\[single\\]\\] and \\[\\[https://example.com\\]\\[titleparen\\]\\]\\.$" "$alpha_file"
grep -q '^+ Nested label \[\[https://example.net\]\[a \[nested\] label\]\]\.$' "$alpha_file"
grep -q '^+ Angle link \[\[https://example.com/a-b\]\[angle\]\]\.$' "$alpha_file"
grep -q '^+ Escaped paren \[\[https://example.com/a)b\]\[escaped\]\]\.$' "$alpha_file"
grep -q '^+ Email \[\[mailto:user@example.com\]\[user@example.com\]\]\.$' "$alpha_file"
grep -q '^+ Reference \[\[https://example.com/docs\]\[docs\]\]\.$' "$alpha_file"
grep -q '^+ Angle reference \[\[https://example.com/angle\]\[angle ref\]\]\.$' "$alpha_file"
grep -q '^+ Space angle reference \[\[https://example.com/a%20b\]\[space ref\]\]\.$' "$alpha_file"
grep -q '^+ Reference title variants \[\[https://example.com/single\]\[single ref\]\] and \[\[https://example.com/paren\]\[paren ref\]\]\.$' "$alpha_file"
grep -q '^+ Collapsed \[\[https://example.com/docs\]\[docs ref\]\] and shortcut \[\[https://example.com/docs\]\[docs ref\]\]\.$' "$alpha_file"
grep -q '^+ Star bullet !\[`image`\](image.png)$' "$alpha_file"
grep -q '^+ Plus bullet$' "$alpha_file"
grep -q '^\*\* Section :tag:$' "$alpha_file"
test "$(grep -c '^:CUSTOM_ID:' "$alpha_file")" -eq 1
! grep -q '^:CUSTOM_ID:' "$beta_file"
grep -q '^\*\* TODO Root task \[\[id:' "$alpha_file"
grep -q '^\*\*\*\* CURRENTLY_WORKING Active \[\[#h-' "$alpha_file"
! grep -q '^#+TODO:' "$alpha_file"
! grep -q '^#+TODO:' "$beta_file"
grep -q '^\[\[id:.*\]\[\*\*B\*\*\]\]$' "$alpha_file"
grep -q '^#+begin_src python$' "$alpha_file"
grep -q '^\[\[Not A Link\]\]$' "$alpha_file"
grep -q '^#+begin_callout note Heading$' "$alpha_file"
test "$(grep -c '^#+end_callout$' "$alpha_file")" -eq 2
grep -q '^#+begin_callout warning$' "$alpha_file"
grep -q '\[missing reference: missing collapsed\]' "$tmp/out/conversion-ledger.md"
grep -q '\[missing reference: missing-ref\]' "$tmp/out/conversion-ledger.md"
grep -q '\[missing target\].*\[\[Missing Note\]\]' "$tmp/out/conversion-ledger.md"
! grep -q '\[missing reference: 1/3\]' "$tmp/out/conversion-ledger.md"
! grep -q '\[missing reference: /\]' "$tmp/out/conversion-ledger.md"
! grep -q '\[missing reference: C-c\]' "$tmp/out/conversion-ledger.md"
! grep -q '\[missing target\].*\[\[https\?://' "$tmp/out/conversion-ledger.md"
! grep -q '\[missing target\].*\[\[mailto:' "$tmp/out/conversion-ledger.md"

if "$repo_root/scripts/convert-vault-to-org.py" --vault "$tmp/vault" --output "$tmp/vault" --force >/dev/null 2>&1; then
  echo "unsafe source-vault output was allowed" >&2
  exit 1
fi

mkdir "$tmp/plain"
if "$repo_root/scripts/convert-vault-to-org.py" --vault "$tmp/vault" --output "$tmp/plain" --force >/dev/null 2>&1; then
  echo "unmarked output replacement was allowed" >&2
  exit 1
fi

printf 'not this converter\n' >"$tmp/out/.org-conversion-output"
if "$repo_root/scripts/convert-vault-to-org.py" --vault "$tmp/vault" --output "$tmp/out" --force >/dev/null 2>&1; then
  echo "tampered output marker replacement was allowed" >&2
  exit 1
fi
