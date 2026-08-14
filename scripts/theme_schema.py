from __future__ import annotations

import re
from pathlib import Path
from typing import Any


REQUIRED_COLORS = (
    "name",
    "black",
    "red",
    "green",
    "yellow",
    "blue",
    "purple",
    "cyan",
    "white",
    "brightBlack",
    "brightRed",
    "brightGreen",
    "brightYellow",
    "brightBlue",
    "brightPurple",
    "brightCyan",
    "brightWhite",
    "background",
    "foreground",
    "selectionBackground",
    "cursorColor",
)
HEX_COLOR = re.compile(r"^#[0-9a-fA-F]{6}$")


def ensure_hex(value: Any, key: str) -> str:
    if not isinstance(value, str) or not HEX_COLOR.fullmatch(value):
        raise ValueError(f"{key} must be a #RRGGBB color")
    return value.lower()


def validate_theme_object(raw: Any, path: Path | None = None) -> dict[str, str]:
    label = f"{path}: " if path is not None else ""
    if not isinstance(raw, dict):
        raise ValueError(f"{label}theme must be a JSON object")

    missing = [key for key in REQUIRED_COLORS if key not in raw]
    if missing:
        raise ValueError(f"{label}missing required keys: {', '.join(missing)}")

    theme: dict[str, str] = {}
    for key, value in raw.items():
        if not isinstance(value, str):
            raise ValueError(f"{label}{key} must be a string")
        if key in {"name", "displayName"}:
            theme[key] = value
        else:
            theme[key] = ensure_hex(value, key)

    if path is not None and theme["name"] != path.stem:
        raise ValueError(f"{path}: name must match filename stem")

    return theme
