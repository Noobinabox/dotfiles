#!/usr/bin/env python3
"""Exercise backup/restore with disposable homes and real GPG encryption."""

import io
import os
import pathlib
import shutil
import subprocess
import tarfile
import tempfile
import unittest


REPO = pathlib.Path(__file__).resolve().parent.parent
GPG = shutil.which("gpg")


class SecretsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        self.repo = self.root / "repo"
        shutil.copytree(REPO / "scripts", self.repo / "scripts")
        (self.repo / "secrets").mkdir()
        self.home = self.root / "home"
        self.config = self.home / "custom-config"
        self.ssh = self.home / ".ssh"
        self.mud = self.config / "mud-client"
        self.ssh.mkdir(parents=True)
        self.mud.mkdir(parents=True)
        (self.ssh / "key").write_text("fixture SSH key\n")
        (self.root / "linked config").write_text("fixture MUD config\n")
        (self.mud / "config.toml").symlink_to(self.root / "linked config")
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        wrapper = bin_dir / "gpg"
        wrapper.write_text(
            '#!/usr/bin/env bash\n'
            'if [[ ${TEST_GPG_FAIL:-0} == 1 ]]; then exit 1; fi\n'
            'exec "$TEST_REAL_GPG" --batch --pinentry-mode loopback '
            '--passphrase fixture-only "$@"\n'
        )
        wrapper.chmod(0o700)
        gnupg = self.root / "gnupg"
        gnupg.mkdir(mode=0o700)
        self.addCleanup(self.stop_agent, gnupg)
        self.env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.config),
                        GNUPGHOME=str(gnupg), GPG_SYMMETRIC="1", TEST_REAL_GPG=GPG,
                        PATH=f"{bin_dir}:{os.environ['PATH']}")
        self.env.pop("GPG_RECIPIENT", None)

    def stop_agent(self, gnupg):
        subprocess.run(["gpgconf", "--homedir", str(gnupg), "--kill", "gpg-agent"],
                       capture_output=True)

    def run_script(self, script, *names, success=True):
        result = subprocess.run(
            ["bash", str(self.repo / "scripts" / script), *names],
            env=self.env, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode == 0, success, result.stderr)
        return result

    def encrypt(self, *names):
        self.run_script("encrypt-secrets.sh", *(names or ("ssh", "mud-client")))

    def test_roundtrip_backups_modes_and_symlink_contents(self):
        self.encrypt()
        (self.ssh / "key").write_text("changed\n")
        self.run_script("decrypt-secrets.sh", "ssh", "mud-client")
        self.assertEqual((self.ssh / "key").read_text(), "fixture SSH key\n")
        self.assertEqual((self.mud / "config.toml").read_text(), "fixture MUD config\n")
        self.assertFalse((self.mud / "config.toml").is_symlink())
        self.assertEqual(self.ssh.stat().st_mode & 0o777, 0o700)
        self.assertEqual((self.ssh / "key").stat().st_mode & 0o777, 0o600)
        backup = next(self.home.glob(".ssh.backup.*/original/key"))
        self.assertEqual(backup.read_text(), "changed\n")

    def test_failed_gpg_preserves_ciphertext_and_live_files(self):
        self.encrypt("ssh")
        encrypted = self.repo / "secrets/ssh.tar.gz.gpg"
        original = encrypted.read_bytes()
        self.env["TEST_GPG_FAIL"] = "1"
        self.run_script("encrypt-secrets.sh", "ssh", success=False)
        self.assertEqual(encrypted.read_bytes(), original)
        self.run_script("decrypt-secrets.sh", "ssh", success=False)
        self.assertEqual((self.ssh / "key").read_text(), "fixture SSH key\n")
        self.assertFalse(list(self.home.glob(".decrypt.*")))
        self.assertFalse(list((self.repo / "secrets").glob(".encrypt.*")))

    def test_missing_and_invalid_selections(self):
        self.run_script("encrypt-secrets.sh", "shell.env")
        self.run_script("decrypt-secrets.sh", "ssh")
        self.run_script("encrypt-secrets.sh", "../bad", success=False)
        self.run_script("decrypt-secrets.sh", "../bad", success=False)

    def test_special_file_does_not_replace_backup(self):
        self.encrypt("ssh")
        encrypted = self.repo / "secrets/ssh.tar.gz.gpg"
        original = encrypted.read_bytes()
        os.mkfifo(self.ssh / "fifo")
        self.run_script("encrypt-secrets.sh", "ssh", success=False)
        self.assertEqual(encrypted.read_bytes(), original)

    def test_recipient_encryption_and_new_destination(self):
        subprocess.run([str(self.root / "bin/gpg"), "--quick-generate-key",
                        "Dotfiles Fixture <fixture@example.invalid>", "future-default",
                        "default", "0"], env=self.env, check=True, capture_output=True)
        self.env["GPG_RECIPIENT"] = "fixture@example.invalid"
        self.encrypt("ssh")
        shutil.rmtree(self.ssh)
        self.run_script("decrypt-secrets.sh", "ssh")
        self.assertEqual((self.ssh / "key").read_text(), "fixture SSH key\n")

    def test_env_roundtrip_and_destination_symlink_refusal(self):
        runtime = self.config / "secrets"
        runtime.mkdir()
        (runtime / "shell.env").write_text("fixture=value\n")
        self.encrypt("shell.env")
        self.run_script("decrypt-secrets.sh", "shell.env")
        self.assertEqual((runtime / "shell.env").read_text(), "fixture=value\n")
        self.encrypt("ssh")
        self.ssh.rename(self.home / "real-ssh")
        self.ssh.symlink_to(self.home / "real-ssh")
        self.run_script("decrypt-secrets.sh", "ssh", success=False)

    def test_hostile_archives_preserve_destination(self):
        for kind in ("traversal", "absolute", "symlink", "hardlink", "fifo", "corrupt"):
            with self.subTest(kind=kind):
                archive_path = self.root / "hostile.tar.gz"
                with tarfile.open(archive_path, "w:gz") as archive:
                    member = tarfile.TarInfo("safe")
                    if kind == "traversal":
                        member.name = "../escaped"
                    elif kind == "absolute":
                        member.name = str(self.root / "escaped")
                    elif kind in ("symlink", "hardlink"):
                        member.type = tarfile.SYMTYPE if kind == "symlink" else tarfile.LNKTYPE
                        member.linkname = "../escaped"
                    elif kind == "fifo":
                        member.type = tarfile.FIFOTYPE
                    archive.addfile(member, io.BytesIO())
                if kind == "corrupt":
                    archive_path.write_bytes(b"invalid archive")
                subprocess.run([str(self.root / "bin/gpg"), "--yes", "--symmetric",
                                "--output", str(self.repo / "secrets/ssh.tar.gz.gpg"),
                                str(archive_path)], env=self.env, check=True, capture_output=True)
                self.run_script("decrypt-secrets.sh", "ssh", success=False)
                self.assertEqual((self.ssh / "key").read_text(), "fixture SSH key\n")
                self.assertFalse((self.root / "escaped").exists())


if __name__ == "__main__":
    unittest.main()
