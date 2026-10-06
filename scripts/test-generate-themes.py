#!/usr/bin/env python3
"""Regression checks for shared theme generation and safe config updates."""
import importlib.util
import plistlib
import os
import shutil
import subprocess
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


def contrast_ratio(foreground, background):
    def luminance(hex_color):
        components = [int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
        linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in components]
        return sum(c * weight for c, weight in zip(linear, (0.2126, 0.7152, 0.0722)))

    light, dark = sorted((luminance(foreground), luminance(background)), reverse=True)
    return (light + 0.05) / (dark + 0.05)


class CodexThemeTests(unittest.TestCase):
    def test_all_palettes_produce_parseable_matching_themes(self):
        for theme in generator.load_themes():
            with self.subTest(theme=theme["name"]):
                parsed = plistlib.loads(generator.textmate_theme(theme).encode())
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
            fixtures = {
                "spotify-player/app.toml": 'theme = "dracula"\nclient_port = 8080\n',
                "bpytop/bpytop.conf": 'color_theme="Default"\nupdate_ms=2000\n',
                "htop/htoprc": 'color_scheme=0\ndelay=15\n',
            }
            for filename, content in fixtures.items():
                path = root / "tools/.config" / filename
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding="utf-8")
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
                    spotify = tomllib.loads((root / "tools/.config/spotify-player/app.toml").read_text())
                    self.assertEqual(spotify, {"theme": "dotfiles-current", "client_port": 8080})
                    htop = (root / "tools/.config/htop/htoprc").read_text()
                    self.assertIn("delay=15", htop)
                    self.assertIn(f'color_scheme={3 if name == "github-light" else 0}', htop)
                    bpytop = (root / "tools/.config/bpytop/bpytop.conf").read_text()
                    self.assertEqual(bpytop, 'color_theme="+dotfiles-current"\nupdate_ms=2000\n')
                    bat = root / "tools/.config/bat/themes/dotfiles-current.tmTheme"
                    self.assertEqual(plistlib.loads(bat.read_bytes())["name"], generator.BAT_THEME_NAME)
                    shell = (root / "tools/.config/theme-pack/shell/current.zsh").read_text()
                    self.assertIn(f"local grey='{theme['dimForeground']}'", shell)

    def test_spotify_root_setting_preserves_multiline_and_nested_settings(self):
        text = '# comment\ntheme = "dracula"\nplayback_format = """\n{track}\n{album}\n"""\n[device]\nvolume = 75\n'
        updated = generator.toml_string_setting(text, "theme", "dotfiles-current")
        original = tomllib.loads(text)
        original["theme"] = "dotfiles-current"
        self.assertEqual(tomllib.loads(updated), original)
        self.assertEqual(generator.toml_string_setting(updated, "theme", "dotfiles-current"), updated)
        self.assertIn("# comment", updated)

    def test_line_settings_reject_missing_and_duplicate_keys(self):
        for text in ["delay=15\n", "color_scheme=0\ncolor_scheme=3\n"]:
            with self.subTest(text=text), self.assertRaises(ValueError):
                generator.line_setting(text, "color_scheme", "3")

    def test_generated_light_theme_text_has_readable_contrast(self):
        theme = generator.find_theme("github-light", generator.load_themes())
        alacritty = tomllib.loads(generator.alacritty_toml(theme))
        yazi = tomllib.loads(generator.yazi_flavor(theme))
        pairs = [(theme["foreground"], theme["background"])]
        for name in ["footer_bar", "hints"]:
            style = alacritty["colors"][name]
            if name == "hints":
                style = style["end"]
            pairs.append((style["foreground"], style["background"]))
        pairs.append((yazi["help"]["footer"]["fg"], yazi["help"]["footer"]["bg"]))
        pairs.append((generator.glow_style(theme)["block_quote"]["color"], theme["background"]))

        for foreground, background in pairs:
            self.assertGreaterEqual(contrast_ratio(foreground, background), 4.5)

    def test_diff_backgrounds_follow_palette_brightness(self):
        for theme in generator.load_themes():
            with self.subTest(theme=theme["name"]):
                parsed = plistlib.loads(generator.textmate_theme(theme).encode())
                scopes = {
                    scope.strip(): item["settings"]
                    for item in parsed["settings"] if "scope" in item
                    for scope in item["scope"].split(",")
                }
                backgrounds = [scopes[scope]["background"]
                               for scope in ["markup.inserted", "markup.deleted"]]
                self.assertNotEqual(*backgrounds)
                for background in backgrounds:
                    self.assertLess(contrast_ratio(background, theme["background"]), 1.3)
                self.assertNotIn("background", scopes["invalid"])

    def test_github_light_syntax_is_readable_on_code_and_diff_backgrounds(self):
        theme = generator.find_theme("github-light", generator.load_themes())
        parsed = plistlib.loads(generator.textmate_theme(theme).encode())
        settings = parsed["settings"]
        backgrounds = [theme["background"]] + [
            item["settings"]["background"] for item in settings[1:]
            if "background" in item["settings"]
        ]
        for item in settings:
            for background in backgrounds:
                with self.subTest(scope=item.get("scope", "default"), background=background):
                    self.assertGreaterEqual(
                        contrast_ratio(item["settings"]["foreground"], background), 4.5
                    )

    def test_tmux_reloading_updates_picker_and_status_colors(self):
        tmux = shutil.which("tmux")
        if not tmux:
            self.skipTest("tmux is not installed")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            command = [tmux, "-S", str(root / "tmux.sock")]

            def run(*arguments):
                return subprocess.run(command + list(arguments), check=True,
                                      capture_output=True, text=True, timeout=10).stdout.strip()

            try:
                run("-f", "/dev/null", "new-session", "-d", "-s", "theme-test", "sleep 60")
                run("set", "-g", "status-left", "#[fg=red,bg=black]OLD")
                run("set", "-g", "status-right", "#[fg=white,bg=black]OLD")
                themes = generator.load_themes()
                for name in ["github-light", "tokyo-night", "github-light"]:
                    with self.subTest(theme=name):
                        theme = generator.find_theme(name, themes)
                        config = root / "theme.conf"
                        config.write_text(generator.tmux_conf(theme), encoding="utf-8")
                        run("source-file", str(config))
                        expected_selection = (f"fg={theme['foreground']},"
                                              f"bg={theme['selectionBackground']},bold")
                        self.assertEqual(run("show", "-gwv", "mode-style"), expected_selection)
                        self.assertEqual(run("show", "-gv", "menu-selected-style"),
                                         expected_selection)
                        self.assertEqual(run("show", "-gv", "status-left-style"),
                                         f"fg={theme['foreground']},bg={theme['surface']},bold")
                        self.assertEqual(run("show", "-gv", "status-right-style"),
                                         f"fg={theme['foreground']},bg={theme['background']}")
                        self.assertEqual(run("show", "-gwv", "window-status-current-style"),
                                         f"fg={theme['background']},bg={theme['blue']},bold")
                        self.assertEqual(run("show", "-gwv", "popup-style"),
                                         f"fg={theme['foreground']},bg={theme['background']}")
                        self.assertEqual(run("show", "-gv", "status-left"),
                                         "#{?client_prefix,> ,}#S")
                        self.assertEqual(run("show", "-gv", "status-right"),
                                         "#{pane_current_path}")
                        self.assertEqual(run("display-message", "-p", "-t", "theme-test",
                                             "#{E:status-left}"), "theme-test")
            finally:
                subprocess.run(command + ["kill-server"], capture_output=True, timeout=10)

    def test_app_themes_parse_for_every_palette(self):
        for theme in generator.load_themes():
            with self.subTest(theme=theme["name"]):
                spotify = tomllib.loads(generator.spotify_theme(theme))["themes"][0]
                self.assertEqual(spotify["palette"]["background"], theme["background"])
                self.assertEqual(spotify["palette"]["foreground"], theme["foreground"])
                bpytop = generator.bpytop_theme(theme)
                self.assertIn(f'theme[main_fg]="{theme["foreground"]}"', bpytop)
                self.assertIn(f'theme[main_bg]="{theme["background"]}"', bpytop)

    def test_installed_bat_loads_generated_theme_by_filename(self):
        bat = shutil.which("batcat") or shutil.which("bat")
        if not bat:
            self.skipTest("bat is not installed")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            themes = root / "themes"
            themes.mkdir()
            environment = {**os.environ, "BAT_CONFIG_DIR": str(root),
                           "BAT_CACHE_PATH": str(root / "cache")}
            for name in ["github-light", "tokyo-night"]:
                palette = generator.find_theme(name, generator.load_themes())
                (themes / "dotfiles-current.tmTheme").write_text(
                    generator.textmate_theme(palette, generator.BAT_THEME_NAME), encoding="utf-8"
                )
                subprocess.run([bat, "cache", "--build"], env=environment,
                               check=True, capture_output=True, text=True)
                result = subprocess.run(
                    [bat, "--theme", generator.BAT_THEME_NAME, "--color=always",
                     "--paging=never", "--language=python"], input="print(42)\n",
                    env=environment, check=True, capture_output=True, text=True,
                )
                self.assertNotIn("Unknown theme", result.stderr)
                self.assertIn("42", result.stdout)


if __name__ == "__main__":
    unittest.main()
