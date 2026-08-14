#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
from pathlib import Path
from typing import Any

from theme_schema import ensure_hex, validate_theme_object


REPO_ROOT = Path(__file__).resolve().parents[1]
THEMES_DIR = REPO_ROOT / "themes"
PYWAL_COLORS = Path(os.environ.get("PYWAL_CACHE_DIR", Path.home() / ".cache/wal")) / "colors.json"
THEME_NAME = re.compile(r"^[a-z0-9][a-z0-9-]*$")


def read_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise ValueError(f"{path}: invalid JSON: {error}") from error

    if not isinstance(data, dict):
        raise ValueError(f"{path}: expected a JSON object")
    return data


def normalize_theme_name(name: str) -> str:
    if not THEME_NAME.fullmatch(name):
        raise ValueError("theme name must use lowercase letters, numbers, and hyphens")
    return name


def title_from_name(name: str) -> str:
    return " ".join(part.capitalize() for part in name.split("-"))


def from_pywal(data: dict[str, Any], name: str) -> dict[str, str]:
    colors = data.get("colors")
    special = data.get("special")
    if not isinstance(colors, dict) or not isinstance(special, dict):
        raise ValueError("pywal colors.json must contain colors and special objects")

    def wal_color(index: int) -> str:
        return ensure_hex(colors.get(f"color{index}"), f"colors.color{index}")

    background = ensure_hex(special.get("background"), "special.background")
    foreground = ensure_hex(special.get("foreground"), "special.foreground")
    cursor = ensure_hex(special.get("cursor", foreground), "special.cursor")

    return {
        "name": name,
        "displayName": title_from_name(name),
        "black": wal_color(0),
        "red": wal_color(1),
        "green": wal_color(2),
        "yellow": wal_color(3),
        "blue": wal_color(4),
        "purple": wal_color(5),
        "cyan": wal_color(6),
        "white": wal_color(7),
        "brightBlack": wal_color(8),
        "brightRed": wal_color(9),
        "brightGreen": wal_color(10),
        "brightYellow": wal_color(11),
        "brightBlue": wal_color(12),
        "brightPurple": wal_color(13),
        "brightCyan": wal_color(14),
        "brightWhite": wal_color(15),
        "background": background,
        "foreground": foreground,
        "dimForeground": wal_color(8),
        "brightForeground": wal_color(15),
        "selectionBackground": wal_color(8),
        "cursorColor": cursor,
        "orange": wal_color(3),
        "error": wal_color(1),
        "comment": wal_color(8),
        "surface": wal_color(0),
        "surfaceDark": background,
        "surfaceLight": wal_color(8),
        "border": wal_color(8),
    }


def imported_theme(data: dict[str, Any], name: str) -> dict[str, Any]:
    data["name"] = name
    data.setdefault("displayName", title_from_name(name))
    return data


def write_theme(theme: dict[str, Any], name: str) -> None:
    output = THEMES_DIR / f"{name}.json"
    if output.exists():
        raise ValueError(f"{output} already exists")
    validated = validate_theme_object(theme)
    output.write_text(json.dumps(validated, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Create a dotfiles theme from pywal16 output.")
    parser.add_argument("--name", required=True, help="Theme id to write under themes/<name>.json.")
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--from-pywal-cache", action="store_true", help="Read ~/.cache/wal/colors.json.")
    source.add_argument("--from-json", metavar="PATH", help="Import an existing JSON palette.")
    args = parser.parse_args()

    try:
        name = normalize_theme_name(args.name)
        if args.from_pywal_cache:
            theme = from_pywal(read_json(PYWAL_COLORS), name)
        else:
            theme = imported_theme(read_json(Path(args.from_json).expanduser()), name)
        write_theme(theme, name)
    except ValueError as error:
        print(f"error: {error}")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
