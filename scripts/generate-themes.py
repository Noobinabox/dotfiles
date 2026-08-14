#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import tomllib
from pathlib import Path
from typing import Any

from theme_schema import validate_theme_object


REPO_ROOT = Path(__file__).resolve().parents[1]
THEMES_DIR = REPO_ROOT / "themes"
GENERATED_DIR = THEMES_DIR / "generated"


def load_theme(path: Path) -> dict[str, str]:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise ValueError(f"{path}: invalid JSON: {error}") from error

    return validate_theme_object(raw, path)


def theme_paths() -> list[Path]:
    return sorted(
        path
        for path in THEMES_DIR.glob("*.json")
        if path.is_file() and path.parent != GENERATED_DIR
    )


def load_themes() -> list[dict[str, str]]:
    themes = [load_theme(path) for path in theme_paths()]
    if not themes:
        raise ValueError("no theme definitions found")
    return themes


def display_name(theme: dict[str, str]) -> str:
    return theme.get("displayName", theme["name"])


def color(theme: dict[str, str], key: str, fallback: str | None = None) -> str:
    value = theme.get(key)
    if value is None:
        if fallback is None:
            raise KeyError(key)
        value = theme[fallback]
    return value


def json_text(value: Any) -> str:
    return json.dumps(value, indent=2, ensure_ascii=True) + "\n"


def windows_terminal_scheme(theme: dict[str, str]) -> dict[str, str]:
    return {
        "name": display_name(theme),
        "black": theme["black"],
        "red": theme["red"],
        "green": theme["green"],
        "yellow": theme["yellow"],
        "blue": theme["blue"],
        "purple": theme["purple"],
        "cyan": theme["cyan"],
        "white": theme["white"],
        "brightBlack": theme["brightBlack"],
        "brightRed": theme["brightRed"],
        "brightGreen": theme["brightGreen"],
        "brightYellow": theme["brightYellow"],
        "brightBlue": theme["brightBlue"],
        "brightPurple": theme["brightPurple"],
        "brightCyan": theme["brightCyan"],
        "brightWhite": theme["brightWhite"],
        "background": theme["background"],
        "foreground": theme["foreground"],
        "selectionBackground": theme["selectionBackground"],
        "cursorColor": theme["cursorColor"],
    }


def windows_terminal_theme(theme: dict[str, str]) -> dict[str, Any]:
    return {
        "name": display_name(theme),
        "tab": {
            "background": f"{theme['background']}FF",
            "iconStyle": "default",
            "showCloseButton": "always",
            "unfocusedBackground": None,
        },
        "tabRow": {
            "background": f"{color(theme, 'surfaceDark', 'background')}FF",
            "unfocusedBackground": f"{theme['background']}FF",
        },
        "window": {
            "applicationTheme": "dark",
            "experimental.rainbowFrame": False,
            "frame": None,
            "unfocusedFrame": None,
            "useMica": False,
        },
    }


def alacritty_toml(theme: dict[str, str]) -> str:
    indexed_16 = color(theme, "orange", "yellow")
    indexed_17 = color(theme, "error", "red")
    return f"""[colors.primary]
background = "{theme['background']}"
foreground = "{theme['foreground']}"
dim_foreground = "{color(theme, 'dimForeground', 'white')}"
bright_foreground = "{color(theme, 'brightForeground', 'brightWhite')}"

[colors.cursor]
text = "{theme['background']}"
cursor = "{theme['cursorColor']}"

[colors.vi_mode_cursor]
text = "{theme['background']}"
cursor = "{theme['cursorColor']}"

[colors.search.matches]
foreground = "{theme['background']}"
background = "{theme['blue']}"

[colors.search.focused_match]
foreground = "{theme['background']}"
background = "{indexed_16}"

[colors.footer_bar]
foreground = "{theme['background']}"
background = "{theme['white']}"

[colors.hints.start]
foreground = "{theme['background']}"
background = "{theme['yellow']}"

[colors.hints.end]
foreground = "{theme['background']}"
background = "{theme['white']}"

[colors.selection]
text = "{theme['foreground']}"
background = "{theme['selectionBackground']}"

[colors.normal]
black = "{theme['black']}"
red = "{theme['red']}"
green = "{theme['green']}"
yellow = "{theme['yellow']}"
blue = "{theme['blue']}"
magenta = "{theme['purple']}"
cyan = "{theme['cyan']}"
white = "{theme['white']}"

[colors.bright]
black = "{theme['brightBlack']}"
red = "{theme['brightRed']}"
green = "{theme['brightGreen']}"
yellow = "{theme['brightYellow']}"
blue = "{theme['brightBlue']}"
magenta = "{theme['brightPurple']}"
cyan = "{theme['brightCyan']}"
white = "{theme['brightWhite']}"

[colors.dim]
black = "{theme['brightBlack']}"
red = "{theme['red']}"
green = "{theme['green']}"
yellow = "{theme['yellow']}"
blue = "{theme['blue']}"
magenta = "{theme['purple']}"
cyan = "{theme['cyan']}"
white = "{theme['brightWhite']}"

[[colors.indexed_colors]]
index = 16
color = "{indexed_16}"

[[colors.indexed_colors]]
index = 17
color = "{indexed_17}"
"""


def glow_style(theme: dict[str, str]) -> dict[str, Any]:
    surface = color(theme, "surface", "background")
    code_background = color(theme, "surfaceDark", "background")
    comment = color(theme, "comment", "brightBlack")
    orange = color(theme, "orange", "yellow")
    error = color(theme, "error", "red")
    return {
        "document": {
            "block_prefix": "\n",
            "block_suffix": "\n",
            "color": theme["foreground"],
            "background_color": theme["background"],
            "margin": 2,
        },
        "block_quote": {"color": theme["white"], "indent": 1, "indent_token": "| "},
        "paragraph": {},
        "list": {"level_indent": 2},
        "heading": {"block_suffix": "\n", "color": theme["blue"], "bold": True},
        "h1": {
            "prefix": " ",
            "suffix": " ",
            "color": theme["background"],
            "background_color": theme["blue"],
            "bold": True,
        },
        "h2": {"prefix": "## ", "color": theme["purple"]},
        "h3": {"prefix": "### ", "color": theme["cyan"]},
        "h4": {"prefix": "#### ", "color": theme["green"]},
        "h5": {"prefix": "##### ", "color": theme["yellow"]},
        "h6": {"prefix": "###### ", "color": theme["red"], "bold": False},
        "text": {},
        "strikethrough": {"crossed_out": True},
        "emph": {"italic": True, "color": theme["purple"]},
        "strong": {"bold": True, "color": theme["foreground"]},
        "hr": {"color": theme["brightBlack"], "format": "\n--------\n"},
        "item": {"block_prefix": "- "},
        "enumeration": {"block_prefix": ". "},
        "task": {"ticked": "[x] ", "unticked": "[ ] "},
        "link": {"color": theme["green"], "underline": True},
        "link_text": {"color": theme["cyan"], "bold": True},
        "image": {"color": orange, "underline": True},
        "image_text": {"color": comment, "format": "Image: {{.text}} ->"},
        "code": {"prefix": " ", "suffix": " ", "color": orange, "background_color": surface},
        "code_block": {
            "color": theme["foreground"],
            "background_color": code_background,
            "margin": 2,
            "chroma": {
                "text": {"color": theme["foreground"]},
                "error": {"color": theme["foreground"], "background_color": error},
                "comment": {"color": comment, "italic": True},
                "comment_preproc": {"color": theme["yellow"]},
                "keyword": {"color": theme["purple"]},
                "keyword_reserved": {"color": theme["red"]},
                "keyword_namespace": {"color": theme["blue"]},
                "keyword_type": {"color": theme["cyan"]},
                "operator": {"color": theme["cyan"]},
                "punctuation": {"color": theme["cyan"]},
                "name": {"color": theme["foreground"]},
                "name_builtin": {"color": theme["cyan"]},
                "name_tag": {"color": theme["red"]},
                "name_attribute": {"color": theme["blue"]},
                "name_class": {"color": theme["green"], "bold": True},
                "name_constant": {"color": orange},
                "name_decorator": {"color": theme["yellow"]},
                "name_exception": {"color": theme["red"]},
                "name_function": {"color": theme["blue"]},
                "name_other": {},
                "literal": {"color": orange},
                "literal_number": {"color": orange},
                "literal_date": {"color": theme["green"]},
                "literal_string": {"color": theme["green"]},
                "literal_string_escape": {"color": theme["cyan"]},
                "generic_deleted": {"color": theme["red"]},
                "generic_emph": {"italic": True},
                "generic_inserted": {"color": theme["green"]},
                "generic_strong": {"bold": True},
                "generic_subheading": {"color": comment},
                "background": {"background_color": code_background},
            },
        },
        "table": {"color": theme["foreground"]},
        "definition_list": {},
        "definition_term": {"color": theme["blue"], "bold": True},
        "definition_description": {"block_prefix": "\n=> "},
        "html_block": {"color": comment},
        "html_span": {"color": comment},
    }


def yazi_flavor(theme: dict[str, str]) -> str:
    surface = color(theme, "surfaceLight", "brightBlack")
    comment = color(theme, "comment", "brightBlack")
    error = color(theme, "error", "red")
    return f"""# Generated by scripts/generate-themes.py

[mgr]
cwd = {{ fg = "{theme['blue']}" }}
find_keyword  = {{ fg = "{theme['red']}", bold = true, italic = true, underline = true }}
find_position = {{ fg = "{theme['purple']}", bg = "reset", bold = true, italic = true }}
marker_copied   = {{ fg = "{theme['green']}", bg = "{theme['green']}" }}
marker_cut      = {{ fg = "{theme['yellow']}", bg = "{theme['red']}" }}
marker_marked   = {{ fg = "{theme['blue']}", bg = "{theme['cyan']}" }}
marker_selected = {{ fg = "{theme['yellow']}", bg = "{theme['yellow']}" }}
count_copied   = {{ fg = "{theme['background']}", bg = "{theme['green']}" }}
count_cut      = {{ fg = "{theme['background']}", bg = "{theme['yellow']}" }}
count_selected = {{ fg = "{theme['background']}", bg = "{theme['blue']}" }}
border_symbol = "│"
border_style  = {{ fg = "{theme['brightBlack']}" }}

[tabs]
active   = {{ fg = "{theme['background']}", bg = "{theme['blue']}", bold = true }}
inactive = {{ fg = "{theme['blue']}", bg = "{surface}" }}

[mode]
normal_main = {{ fg = "{theme['background']}", bg = "{theme['blue']}", bold = true }}
normal_alt  = {{ fg = "{theme['blue']}", bg = "{surface}" }}
select_main = {{ fg = "{theme['background']}", bg = "{theme['green']}", bold = true }}
select_alt  = {{ fg = "{theme['blue']}", bg = "{surface}" }}
unset_main = {{ fg = "{theme['background']}", bg = "{theme['purple']}", bold = true }}
unset_alt  = {{ fg = "{theme['blue']}", bg = "{surface}" }}

[status]
overall = {{ fg = "{theme['blue']}" }}
sep_left  = {{ open = "", close = "" }}
sep_right = {{ open = "", close = "" }}
progress_label = {{ fg = "{theme['background']}", bold = true }}
progress_normal = {{ fg = "{theme['blue']}", bg = "{surface}" }}
progress_error = {{ fg = "{theme['red']}", bg = "{surface}" }}
perm_sep   = {{ fg = "{theme['blue']}" }}
perm_type  = {{ fg = "{theme['green']}" }}
perm_read  = {{ fg = "{theme['yellow']}" }}
perm_write = {{ fg = "{theme['red']}" }}
perm_exec  = {{ fg = "{theme['purple']}" }}

[pick]
border = {{ fg = "{theme['blue']}" }}
active = {{ fg = "{theme['purple']}", bold = true }}
inactive = {{}}

[input]
border   = {{ fg = "{theme['blue']}" }}
title    = {{}}
value    = {{}}
selected = {{ reversed = true }}

[cmp]
border = {{ fg = "{theme['blue']}" }}

[tasks]
border  = {{ fg = "{theme['blue']}" }}
title   = {{}}
hovered = {{ fg = "{theme['purple']}", underline = true }}

[which]
mask            = {{ bg = "{theme['brightBlack']}" }}
cand            = {{ fg = "{theme['green']}" }}
rest            = {{ fg = "{theme['white']}" }}
desc            = {{ fg = "{theme['purple']}" }}
separator       = "  "
separator_style = {{ fg = "{comment}" }}

[help]
on      = {{ fg = "{theme['green']}" }}
run     = {{ fg = "{theme['purple']}" }}
hovered = {{ reversed = true, bold = true }}
footer  = {{ fg = "{theme['background']}", bg = "{theme['white']}" }}

[spot]
border   = {{ fg = "{theme['blue']}" }}
title    = {{ fg = "{theme['blue']}" }}
tbl_col  = {{ fg = "{theme['green']}" }}
tbl_cell = {{ fg = "{theme['purple']}", bg = "{surface}" }}

[notify]
title_info  = {{ fg = "{theme['green']}" }}
title_warn  = {{ fg = "{theme['yellow']}" }}
title_error = {{ fg = "{error}" }}

[filetype]
rules = [
  {{ mime = "image/*", fg = "{theme['yellow']}" }},
  {{ mime = "video/*", fg = "{theme['red']}" }},
  {{ mime = "audio/*", fg = "{theme['red']}" }},
  {{ mime = "application/zip", fg = "{theme['purple']}" }},
  {{ mime = "application/x-tar", fg = "{theme['purple']}" }},
  {{ mime = "application/x-bzip*", fg = "{theme['purple']}" }},
  {{ mime = "application/x-bzip2", fg = "{theme['purple']}" }},
  {{ mime = "application/x-7z-compressed", fg = "{theme['purple']}" }},
  {{ mime = "application/x-rar", fg = "{theme['purple']}" }},
  {{ mime = "application/x-xz", fg = "{theme['purple']}" }},
  {{ mime = "application/doc", fg = "{theme['green']}" }},
  {{ mime = "application/epub+zip", fg = "{theme['green']}" }},
  {{ mime = "application/pdf", fg = "{theme['green']}" }},
  {{ mime = "application/rtf", fg = "{theme['green']}" }},
  {{ mime = "application/vnd.*", fg = "{theme['green']}" }},
  {{ mime = "*", is = "orphan", fg = "{theme['red']}", bg = "{theme['background']}" }},
  {{ mime = "application/*exec*", fg = "{theme['red']}" }},
  {{ url = "*", fg = "{theme['foreground']}" }},
  {{ url = "*/", fg = "{theme['blue']}" }},
]
"""


def tmux_conf(theme: dict[str, str]) -> str:
    surface = color(theme, "surface", "background")
    return f"""# Generated by scripts/generate-themes.py
set -g status-style "fg={theme['foreground']},bg={theme['background']}"
set -g message-style "fg={theme['foreground']},bg={surface}"
set -g pane-border-style "fg={theme['brightBlack']}"
set -g pane-active-border-style "fg={theme['blue']}"
set -g window-status-style "fg={theme['white']},bg={theme['background']}"
set -g window-status-current-style "fg={theme['background']},bg={theme['blue']},bold"
set -g mode-style "fg={theme['background']},bg={theme['yellow']}"
"""


def nvim_lua(theme: dict[str, str]) -> str:
    comment = color(theme, "comment", "brightBlack")
    surface = color(theme, "surface", "background")
    surface_dark = color(theme, "surfaceDark", "black")
    surface_light = color(theme, "surfaceLight", "brightBlack")
    border = color(theme, "border", "brightBlack")
    orange = color(theme, "orange", "yellow")
    error = color(theme, "error", "red")
    groups = {
        "Normal": {"fg": theme["foreground"], "bg": theme["background"]},
        "NormalFloat": {"fg": theme["foreground"], "bg": surface},
        "FloatBorder": {"fg": border, "bg": surface},
        "Comment": {"fg": comment, "italic": True},
        "Constant": {"fg": orange},
        "String": {"fg": theme["green"]},
        "Character": {"fg": theme["green"]},
        "Number": {"fg": orange},
        "Boolean": {"fg": orange},
        "Identifier": {"fg": theme["foreground"]},
        "Function": {"fg": theme["blue"]},
        "Statement": {"fg": theme["purple"]},
        "Conditional": {"fg": theme["purple"]},
        "Repeat": {"fg": theme["purple"]},
        "Label": {"fg": theme["purple"]},
        "Operator": {"fg": theme["cyan"]},
        "Keyword": {"fg": theme["purple"]},
        "Exception": {"fg": theme["red"]},
        "PreProc": {"fg": theme["yellow"]},
        "Type": {"fg": theme["cyan"]},
        "Special": {"fg": theme["cyan"]},
        "Underlined": {"fg": theme["blue"], "underline": True},
        "Error": {"fg": error},
        "Todo": {"fg": theme["yellow"], "bold": True},
        "Cursor": {"fg": theme["background"], "bg": theme["cursorColor"]},
        "CursorLine": {"bg": surface_dark},
        "CursorLineNr": {"fg": theme["yellow"], "bold": True},
        "LineNr": {"fg": theme["brightBlack"]},
        "Visual": {"bg": theme["selectionBackground"]},
        "Search": {"fg": theme["background"], "bg": theme["yellow"]},
        "IncSearch": {"fg": theme["background"], "bg": orange},
        "Pmenu": {"fg": theme["foreground"], "bg": surface},
        "PmenuSel": {"fg": theme["background"], "bg": theme["blue"]},
        "StatusLine": {"fg": theme["foreground"], "bg": surface},
        "StatusLineNC": {"fg": theme["white"], "bg": surface_dark},
        "VertSplit": {"fg": border},
        "WinSeparator": {"fg": border},
        "TabLine": {"fg": theme["white"], "bg": surface_dark},
        "TabLineSel": {"fg": theme["background"], "bg": theme["blue"], "bold": True},
        "MatchParen": {"fg": theme["yellow"], "bold": True},
        "Directory": {"fg": theme["blue"]},
        "DiffAdd": {"fg": theme["green"], "bg": surface_dark},
        "DiffChange": {"fg": theme["yellow"], "bg": surface_dark},
        "DiffDelete": {"fg": theme["red"], "bg": surface_dark},
        "DiffText": {"fg": theme["blue"], "bg": surface_light},
        "DiagnosticError": {"fg": error},
        "DiagnosticWarn": {"fg": theme["yellow"]},
        "DiagnosticInfo": {"fg": theme["blue"]},
        "DiagnosticHint": {"fg": theme["cyan"]},
        "SpellBad": {"sp": theme["red"], "underline": True},
        "SpellCap": {"sp": theme["yellow"], "underline": True},
        "SpellLocal": {"sp": theme["cyan"], "underline": True},
        "SpellRare": {"sp": theme["purple"], "underline": True},
        "RenderMarkdownCheckboxImportant": {"fg": theme["yellow"], "bold": True},
        "RenderMarkdownCheckboxWorking": {"fg": theme["blue"]},
        "RenderMarkdownCheckboxDeferred": {"fg": comment, "strikethrough": True},
        "RenderMarkdownCheckboxQuestion": {"fg": orange},
    }
    lines = [
        "-- Generated by scripts/generate-themes.py",
        "vim.cmd('highlight clear')",
        "vim.o.termguicolors = true",
        f"vim.g.colors_name = {json.dumps('dotfiles-' + theme['name'])}",
        "local groups = " + lua_table(groups),
        "for group, spec in pairs(groups) do",
        "  vim.api.nvim_set_hl(0, group, spec)",
        "end",
        "",
    ]
    return "\n".join(lines)


def lua_table(value: Any) -> str:
    if isinstance(value, dict):
        parts = []
        for key, item in value.items():
            parts.append(f"[{json.dumps(key)}] = {lua_table(item)}")
        return "{ " + ", ".join(parts) + " }"
    if isinstance(value, bool):
        return "true" if value else "false"
    return json.dumps(value)


def doom_elisp(theme: dict[str, str]) -> str:
    comment = color(theme, "comment", "brightBlack")
    surface = color(theme, "surface", "background")
    surface_dark = color(theme, "surfaceDark", "black")
    surface_light = color(theme, "surfaceLight", "brightBlack")
    border = color(theme, "border", "brightBlack")
    orange = color(theme, "orange", "yellow")
    error = color(theme, "error", "red")
    return f""";;; dotfiles-current-theme.el --- Generated by scripts/generate-themes.py -*- lexical-binding: t; -*-

(deftheme dotfiles-current "Generated dotfiles theme.")

(let ((background "{theme['background']}")
      (foreground "{theme['foreground']}")
      (surface "{surface}")
      (surface-dark "{surface_dark}")
      (surface-light "{surface_light}")
      (border "{border}")
      (comment "{comment}")
      (red "{theme['red']}")
      (green "{theme['green']}")
      (yellow "{theme['yellow']}")
      (blue "{theme['blue']}")
      (purple "{theme['purple']}")
      (cyan "{theme['cyan']}")
      (orange "{orange}")
      (error "{error}"))
  (custom-theme-set-faces
   'dotfiles-current
   `(default ((t (:foreground ,foreground :background ,background))))
   `(cursor ((t (:background "{theme['cursorColor']}"))))
   `(fringe ((t (:background ,background))))
   `(region ((t (:background "{theme['selectionBackground']}"))))
   `(highlight ((t (:background ,surface))))
   `(minibuffer-prompt ((t (:foreground ,blue :weight bold))))
   `(link ((t (:foreground ,blue :underline t))))
   `(error ((t (:foreground ,error))))
   `(warning ((t (:foreground ,yellow))))
   `(success ((t (:foreground ,green))))
   `(font-lock-builtin-face ((t (:foreground ,cyan))))
   `(font-lock-comment-face ((t (:foreground ,comment :slant italic))))
   `(font-lock-constant-face ((t (:foreground ,orange))))
   `(font-lock-function-name-face ((t (:foreground ,blue))))
   `(font-lock-keyword-face ((t (:foreground ,purple))))
   `(font-lock-string-face ((t (:foreground ,green))))
   `(font-lock-type-face ((t (:foreground ,cyan))))
   `(font-lock-variable-name-face ((t (:foreground ,foreground))))
   `(font-lock-warning-face ((t (:foreground ,yellow :weight bold))))
   `(line-number ((t (:foreground "{theme['brightBlack']}" :background ,background))))
   `(line-number-current-line ((t (:foreground ,yellow :background ,surface-dark :weight bold))))
   `(mode-line ((t (:foreground ,foreground :background ,surface :box (:line-width -1 :color ,border)))))
   `(mode-line-inactive ((t (:foreground "{theme['white']}" :background ,surface-dark :box (:line-width -1 :color ,border)))))
   `(vertical-border ((t (:foreground ,border))))
   `(show-paren-match ((t (:foreground ,yellow :weight bold))))
   `(isearch ((t (:foreground ,background :background ,orange))))
   `(lazy-highlight ((t (:foreground ,background :background ,yellow))))
   `(diff-added ((t (:foreground ,green :background ,surface-dark))))
   `(diff-changed ((t (:foreground ,yellow :background ,surface-dark))))
   `(diff-removed ((t (:foreground ,red :background ,surface-dark))))
   `(org-level-1 ((t (:foreground ,blue :weight bold))))
   `(org-level-2 ((t (:foreground ,purple :weight bold))))
   `(org-level-3 ((t (:foreground ,cyan :weight bold))))
   `(org-level-4 ((t (:foreground ,green :weight bold))))
   `(org-code ((t (:foreground ,orange :background ,surface))))
   `(org-block ((t (:background ,surface-dark))))
   `(org-block-begin-line ((t (:foreground ,comment :background ,surface-dark))))
   `(org-block-end-line ((t (:foreground ,comment :background ,surface-dark)))) ))

;;;###autoload
(when load-file-name
  (add-to-list 'custom-theme-load-path (file-name-directory load-file-name)))

(provide-theme 'dotfiles-current)
;;; dotfiles-current-theme.el ends here
"""


def generated_files(theme: dict[str, str]) -> dict[Path, str]:
    theme_dir = GENERATED_DIR / theme["name"]
    return {
        theme_dir / "alacritty.toml": alacritty_toml(theme),
        theme_dir / "windows-terminal-scheme.json": json_text(windows_terminal_scheme(theme)),
        theme_dir / "windows-terminal-theme.json": json_text(windows_terminal_theme(theme)),
        theme_dir / "glow.json": json_text(glow_style(theme)),
        theme_dir / "yazi-flavor.toml": yazi_flavor(theme),
        theme_dir / "tmux.conf": tmux_conf(theme),
        theme_dir / "nvim.lua": nvim_lua(theme),
        theme_dir / "doom-theme.el": doom_elisp(theme),
    }


def write_generated(themes: list[dict[str, str]]) -> None:
    for theme in themes:
        for path, content in generated_files(theme).items():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")


def check_generated(themes: list[dict[str, str]]) -> int:
    failed = False
    for theme in themes:
        for path, expected in generated_files(theme).items():
            if not path.exists():
                print(f"missing generated file: {path.relative_to(REPO_ROOT)}")
                failed = True
                continue
            actual = path.read_text(encoding="utf-8")
            if actual != expected:
                print(f"stale generated file: {path.relative_to(REPO_ROOT)}")
                failed = True
    active_theme_path = REPO_ROOT / "tools/.config/theme-pack/current-theme"
    if not active_theme_path.exists():
        print(f"missing active theme file: {active_theme_path.relative_to(REPO_ROOT)}")
        return 1

    try:
        active_theme = find_theme(active_theme_path.read_text(encoding="utf-8").strip(), themes)
    except ValueError as error:
        print(f"error: {error}")
        return 1

    for path, expected in active_repo_files(active_theme).items():
        if not path.exists():
            print(f"missing active theme output: {path.relative_to(REPO_ROOT)}")
            failed = True
            continue
        actual = path.read_text(encoding="utf-8")
        if actual != expected:
            print(f"stale active theme output: {path.relative_to(REPO_ROOT)}")
            failed = True
    return 1 if failed else 0


def find_theme(name: str, themes: list[dict[str, str]]) -> dict[str, str]:
    for theme in themes:
        if theme["name"] == name:
            return theme
    available = ", ".join(theme["name"] for theme in themes)
    raise ValueError(f"unknown theme '{name}'. Available themes: {available}")


def replace_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def active_repo_files(theme: dict[str, str]) -> dict[Path, str]:
    name = theme["name"]
    generated = generated_files(theme)
    return {
        REPO_ROOT / "tools/.config/theme-pack/current-theme": f"{name}\n",
        REPO_ROOT / "tools/.config/glow/theme.json": generated[GENERATED_DIR / name / "glow.json"],
        REPO_ROOT / "tools/.config/yazi/theme.toml": (
            "#:schema https://yazi-rs.github.io/schemas/theme.json\n\n"
            f"[flavor]\ndark = \"{name}\"\nlight = \"{name}\"\n"
        ),
        REPO_ROOT / f"tools/.config/yazi/flavors/{name}.yazi/flavor.toml": (
            generated[GENERATED_DIR / name / "yazi-flavor.toml"]
        ),
        REPO_ROOT / "tools/.config/theme-pack/tmux/current.conf": generated[
            GENERATED_DIR / name / "tmux.conf"
        ],
        REPO_ROOT / "tools/.config/theme-pack/nvim/current.lua": generated[
            GENERATED_DIR / name / "nvim.lua"
        ],
        REPO_ROOT / "tools/.config/theme-pack/doom/dotfiles-current-theme.el": generated[
            GENERATED_DIR / name / "doom-theme.el"
        ],
    }


def apply_repo_theme(theme: dict[str, str]) -> None:
    for path, content in active_repo_files(theme).items():
        replace_file(path, content)


def strip_alacritty_colors(text: str) -> str:
    kept: list[str] = []
    in_colors = False
    for line in text.splitlines():
        stripped = line.strip()
        is_header = stripped.startswith("[") and stripped.endswith("]")
        if is_header:
            in_colors = (
                stripped.startswith("[colors.")
                or stripped.startswith("[[colors.")
                or stripped == "[colors]"
            )
        if not in_colors:
            kept.append(line)
    return "\n".join(kept).rstrip() + "\n"


def apply_alacritty_theme(theme: dict[str, str], config_path: Path) -> None:
    if not config_path.exists():
        raise ValueError(f"Alacritty config not found: {config_path}")
    text = config_path.read_text(encoding="utf-8")
    try:
        tomllib.loads(text)
    except tomllib.TOMLDecodeError as error:
        raise ValueError(f"{config_path}: invalid TOML before applying theme: {error}") from error

    stripped = strip_alacritty_colors(text)
    next_text = f"{stripped}\n{alacritty_toml(theme)}"
    try:
        tomllib.loads(next_text)
    except tomllib.TOMLDecodeError as error:
        raise ValueError(f"{config_path}: generated Alacritty TOML is invalid: {error}") from error
    config_path.write_text(next_text, encoding="utf-8")


def replace_named(items: list[Any], replacement: dict[str, Any]) -> list[Any]:
    name = replacement["name"]
    next_items: list[Any] = []
    replaced = False
    for item in items:
        if isinstance(item, dict) and item.get("name") == name:
            next_items.append(replacement)
            replaced = True
        else:
            next_items.append(item)
    if not replaced:
        next_items.append(replacement)
    return next_items


def ensure_list(value: Any, field_name: str) -> list[Any]:
    if not isinstance(value, list):
        raise ValueError(f"Windows Terminal {field_name} must be a list")
    for index, item in enumerate(value):
        if not isinstance(item, dict):
            raise ValueError(f"Windows Terminal {field_name}[{index}] must be an object")
    return value


def apply_windows_terminal_theme(
    theme: dict[str, str], settings_path: Path, managed_scheme_names: set[str]
) -> None:
    if not settings_path.exists():
        raise ValueError(f"Windows Terminal settings not found: {settings_path}")

    settings = json.loads(settings_path.read_text(encoding="utf-8"))
    if not isinstance(settings, dict):
        raise ValueError(f"{settings_path}: settings must be a JSON object")

    scheme_name = display_name(theme)
    settings["schemes"] = replace_named(
        ensure_list(settings.get("schemes", []), "schemes"),
        windows_terminal_scheme(theme),
    )
    settings["themes"] = replace_named(
        ensure_list(settings.get("themes", []), "themes"),
        windows_terminal_theme(theme),
    )
    settings["theme"] = scheme_name

    profiles = settings.setdefault("profiles", {})
    if not isinstance(profiles, dict):
        raise ValueError("Windows Terminal profiles must be an object")

    defaults = profiles.setdefault("defaults", {})
    if not isinstance(defaults, dict):
        raise ValueError("Windows Terminal profiles.defaults must be an object")
    defaults["colorScheme"] = scheme_name

    profile_list = ensure_list(profiles.get("list", []), "profiles.list")
    for profile in profile_list:
        if isinstance(profile, dict) and profile.get("colorScheme") in managed_scheme_names:
            profile["colorScheme"] = scheme_name

    settings_path.write_text(json_text(settings), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate and apply dotfiles themes.")
    parser.add_argument("--list", action="store_true", help="List available theme names.")
    parser.add_argument("--check", action="store_true", help="Verify generated outputs are current.")
    parser.add_argument("--write", action="store_true", help="Write generated outputs.")
    parser.add_argument("--apply-repo", metavar="THEME", help="Apply a generated theme to repo-managed configs.")
    parser.add_argument("--apply-alacritty", nargs=2, metavar=("THEME", "PATH"), help="Apply colors to an Alacritty config.")
    parser.add_argument("--apply-windows-terminal", nargs=2, metavar=("THEME", "PATH"), help="Apply colors to Windows Terminal settings.")
    args = parser.parse_args()

    try:
        themes = load_themes()
        if args.list:
            for theme in themes:
                print(theme["name"])
        if args.write or args.apply_repo or args.apply_alacritty or args.apply_windows_terminal:
            write_generated(themes)
        if args.check:
            return check_generated(themes)
        if args.apply_repo:
            apply_repo_theme(find_theme(args.apply_repo, themes))
        if args.apply_alacritty:
            theme = find_theme(args.apply_alacritty[0], themes)
            apply_alacritty_theme(theme, Path(args.apply_alacritty[1]).expanduser())
        if args.apply_windows_terminal:
            theme = find_theme(args.apply_windows_terminal[0], themes)
            managed_names = {display_name(managed_theme) for managed_theme in themes}
            apply_windows_terminal_theme(
                theme,
                Path(args.apply_windows_terminal[1]).expanduser(),
                managed_names,
            )
    except ValueError as error:
        print(f"error: {error}")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
