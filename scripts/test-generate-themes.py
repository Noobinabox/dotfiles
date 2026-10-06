#!/usr/bin/env python3
"""Regression checks for Codex palette generation and safe config updates."""
import importlib.util
import plistlib
import sys
import tempfile
import tomllib
import unittest
from pathlib import Path
from unittest.mock import patch


sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location(
    "generate_themes", Path(__file__).with_name("generate-themes.py")
)
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)


class CodexThemeTests(unittest.TestCase):
    def test_all_palettes_produce_parseable_matching_themes(self):
        for theme in generator.load_themes():
            with self.subTest(theme=theme["name"]):
                parsed = plistlib.loads(generator.codex_theme(theme).encode())
                defaults = parsed["settings"][0]["settings"]
                self.assertEqual(defaults["foreground"], theme["foreground"])
                self.assertEqual(defaults["background"], theme["background"])
                self.assertTrue(any(
                    item.get("scope") == "string"
                    and item["settings"]["foreground"] == theme["green"]
                    for item in parsed["settings"]
                ))

    def test_config_updates_preserve_other_settings_and_are_idempotent(self):
        inputs = [
            '',
            'model = "example"\n',
            '[tui]',
            '[tui] # interface\nstatus_line = ["model"]\n',
            '# Keep this comment\n[tui]\ntheme = "dracula"\n'
            'status_line = ["model"]\n[tui.extra]\ncount = 3\n'
            '[features]\nmemories = true\n',
            '[other]\ntheme = "unrelated"\n[tui]\ntheme = "github"',
        ]
        for text in inputs:
            with self.subTest(text=text):
                expected = tomllib.loads(text)
                expected.setdefault("tui", {})["theme"] = generator.CODEX_THEME_NAME
                updated = generator.codex_config_with_theme(text)
                self.assertEqual(tomllib.loads(updated), expected)
                self.assertEqual(generator.codex_config_with_theme(updated), updated)
                if "# Keep this comment" in text:
                    self.assertIn("# Keep this comment", updated)

    def test_invalid_or_unsupported_config_fails_safely(self):
        for text in ['[tui', 'tui = false', 'tui = { theme = "dracula" }',
                     '["tui"]\ntheme = "dracula"\n']:
            with self.subTest(text=text), self.assertRaises(ValueError):
                generator.codex_config_with_theme(text)

    def test_switching_light_and_dark_updates_palette_without_config_loss(self):
        themes = generator.load_themes()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = root / "tools/.codex/config.toml"
            config.parent.mkdir(parents=True)
            config.write_text('[tui]\ntheme = "dracula"\n'
                              '[features]\nmemories = true\n', encoding="utf-8")
            with patch.object(generator, "REPO_ROOT", root):
                for name in ["github-light", "tokyo-night", "github-light"]:
                    theme = generator.find_theme(name, themes)
                    generator.apply_repo_theme(theme)
                    generated = root / "tools/.codex/themes/dotfiles-current.tmTheme"
                    parsed = plistlib.loads(generated.read_bytes())
                    self.assertEqual(parsed["settings"][0]["settings"]["foreground"],
                                     theme["foreground"])
                    self.assertEqual(parsed["settings"][0]["settings"]["background"],
                                     theme["background"])
                    self.assertEqual(tomllib.loads(config.read_text())["tui"]["theme"],
                                     generator.CODEX_THEME_NAME)
                    self.assertEqual(tomllib.loads(config.read_text())["features"],
                                     {"memories": True})
                    self.assertEqual((root / "tools/.config/theme-pack/current-theme")
                                     .read_text().strip(), name)


if __name__ == "__main__":
    unittest.main()
