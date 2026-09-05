#!/usr/bin/env python3
"""Regression checks for the explicit dotfiles deployment phases."""

import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
INSTALL = ROOT / "install.sh"
DEPENDENCIES = ROOT / "scripts" / "installs" / "core-dependency.sh"


class DeploymentTest(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.home = Path(self.tempdir.name) / "home"
        self.home.mkdir()
        self.env = os.environ.copy()
        self.env.update(
            {
                "HOME": str(self.home),
                "XDG_CONFIG_HOME": str(self.home / "custom-config"),
                "XDG_DATA_HOME": str(self.home / "custom-data"),
                "TERM": "dumb",
            }
        )

    def tearDown(self):
        self.tempdir.cleanup()

    def run_install(self, *args, env=None):
        return subprocess.run(
            [str(INSTALL), *args],
            cwd=ROOT,
            env=env or self.env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )

    @unittest.skipUnless(shutil.which("stow"), "GNU Stow is not installed")
    def test_clean_and_repeat_sync(self):
        first = self.run_install("sync", "nvim")
        self.assertEqual(first.returncode, 0, first.stdout)
        link = self.home / "custom-config" / "nvim" / "init.lua"
        self.assertTrue(link.is_symlink(), first.stdout)
        first_target = os.readlink(link)

        second = self.run_install("sync", "nvim")
        self.assertEqual(second.returncode, 0, second.stdout)
        self.assertEqual(os.readlink(link), first_target)

    @unittest.skipUnless(shutil.which("stow"), "GNU Stow is not installed")
    def test_dry_run_does_not_create_targets(self):
        result = self.run_install("sync", "--dry-run", "nvim")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertFalse((self.home / "custom-config").exists())
        self.assertIn("dry-run", result.stdout.lower())

    @unittest.skipUnless(shutil.which("stow"), "GNU Stow is not installed")
    def test_conflict_refuses_before_mutation(self):
        sentinel = self.home / ".tmux.conf"
        sentinel.write_text("keep this file\n")
        result = self.run_install("sync", "tmux", "nvim")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertEqual(sentinel.read_text(), "keep this file\n")
        self.assertFalse((self.home / "custom-config" / "nvim").exists())
        self.assertIn("conflict", result.stdout.lower())

    @unittest.skipUnless(shutil.which("stow"), "GNU Stow is not installed")
    def test_custom_xdg_config_target(self):
        result = self.run_install("sync", "nvim")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertTrue(
            (self.home / "custom-config" / "nvim" / "init.lua").is_symlink()
        )
        self.assertFalse((self.home / ".config" / "nvim").exists())

    @unittest.skipUnless(shutil.which("stow"), "GNU Stow is not installed")
    def test_package_selection_does_not_link_unselected_packages(self):
        result = self.run_install("sync", "git")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertTrue((self.home / "custom-config" / "git" / "config").is_symlink())
        self.assertFalse((self.home / "custom-config" / "nvim").exists())

    @unittest.skipUnless(shutil.which("stow"), "GNU Stow is not installed")
    def test_macos_vscode_target_plan(self):
        fake_bin = Path(self.tempdir.name) / "fake-bin"
        fake_bin.mkdir()
        uname = fake_bin / "uname"
        uname.write_text("#!/bin/sh\nprintf '%s\\n' Darwin\n")
        uname.chmod(uname.stat().st_mode | stat.S_IXUSR)
        env = self.env.copy()
        env["PATH"] = f"{fake_bin}{os.pathsep}{env['PATH']}"

        result = self.run_install("sync", "vscode", env=env)
        self.assertEqual(result.returncode, 0, result.stdout)
        app_support = self.home / "Library" / "Application Support"
        self.assertTrue((app_support / "Code" / "User" / "settings.json").is_symlink())
        self.assertFalse((app_support / ".config").exists())

    def test_missing_stow_fails_before_mutation(self):
        fake_bin = Path(self.tempdir.name) / "minimal-bin"
        fake_bin.mkdir()
        # Keep the script's shebang and inspection utilities available, while
        # deliberately omitting stow from PATH.
        for command in (
            "bash",
            "env",
            "uname",
            "find",
            "mkdir",
            "readlink",
            "pwd",
            "basename",
            "dirname",
        ):
            source = shutil.which(command)
            if source:
                (fake_bin / command).symlink_to(source)
        env = self.env.copy()
        env["PATH"] = str(fake_bin)
        sentinel = self.home / ".tmux.conf"
        sentinel.write_text("untouched\n")

        result = self.run_install("sync", "nvim", env=env)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertEqual(sentinel.read_text(), "untouched\n")
        self.assertIn("GNU Stow", result.stdout)


class DependencyAdapterTest(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)
        self.fake_bin = self.root / "bin"
        self.fake_bin.mkdir()
        self.log = self.root / "calls.log"
        self.env = os.environ.copy()
        self.env.update(
            {
                "HOME": str(self.root / "home"),
                "XDG_DATA_HOME": str(self.root / "data"),
                "PATH": str(self.fake_bin),
                "DOTFILES_OS": "Linux",
                "DOTFILES_DISTRO": "arch",
                "AUTO_YES": "1",
            }
        )
        # Keep the installer shell and the local-build failure path usable
        # without allowing ambient dependency commands to satisfy requests.
        for command in ("bash", "chmod", "make", "mkdir", "mktemp", "rm", "touch"):
            source = shutil.which(command)
            if source is None:
                self.fail(f"required test utility is unavailable: {command}")
            (self.fake_bin / command).symlink_to(source)
        Path(self.env["HOME"]).mkdir()

    def tearDown(self):
        self.tempdir.cleanup()

    def write_executable(self, name, content):
        path = self.fake_bin / name
        path.write_text(content)
        path.chmod(path.stat().st_mode | stat.S_IXUSR)
        return path

    def run_deps(self, *args):
        return subprocess.run(
            [str(DEPENDENCIES), *args],
            cwd=ROOT,
            env=self.env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )

    def test_manager_receives_separate_canonical_arguments(self):
        self.write_executable(
            "sudo",
            '#!/bin/sh\nprintf \'sudo\' >> "$CALL_LOG"\nfor arg in "$@"; do printf \'<%s>\' "$arg" >> "$CALL_LOG"; done; printf \'\\n\' >> "$CALL_LOG"\nexec "$@"\n',
        )
        self.write_executable(
            "pacman",
            '#!/bin/sh\nprintf \'pacman\' >> "$CALL_LOG"\nfor arg in "$@"; do printf \'<%s>\' "$arg" >> "$CALL_LOG"; done; printf \'\\n\' >> "$CALL_LOG"\ntouch "$FAKE_BIN/git-lfs" "$FAKE_BIN/node"\nchmod +x "$FAKE_BIN/git-lfs" "$FAKE_BIN/node"\n',
        )
        self.env.update({"CALL_LOG": str(self.log), "FAKE_BIN": str(self.fake_bin)})

        result = self.run_deps("--auto-yes", "git-lfs", "node")
        self.assertEqual(result.returncode, 0, result.stdout)
        calls = self.log.read_text()
        self.assertIn("<git-lfs><nodejs>", calls)
        self.assertNotIn("<git-lfs nodejs>", calls)

    def test_no_sudo_never_invokes_sudo_and_reports_unsupported(self):
        self.write_executable(
            "sudo", '#!/bin/sh\necho invoked >> "$CALL_LOG"\nexit 99\n'
        )
        self.env["CALL_LOG"] = str(self.log)
        result = self.run_deps("--no-sudo", "--auto-yes", "git-lfs")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertFalse(self.log.exists())
        self.assertIn("no supported deterministic local recipe", result.stdout.lower())

    def test_package_manager_failure_propagates_status(self):
        self.write_executable("sudo", '#!/bin/sh\nexec "$@"\n')
        self.write_executable("pacman", "#!/bin/sh\nexit 23\n")
        result = self.run_deps("--auto-yes", "git-lfs")
        self.assertEqual(result.returncode, 23, result.stdout)
        self.assertIn("status 23", result.stdout)

    def test_local_build_failure_propagates_status(self):
        self.write_executable(
            "sudo", '#!/bin/sh\necho invoked >> "$CALL_LOG"\nexit 99\n'
        )
        self.write_executable("git", "#!/bin/sh\nexit 17\n")
        self.env["CALL_LOG"] = str(self.log)
        result = self.run_deps("--no-sudo", "--auto-yes", "blesh")
        self.assertEqual(result.returncode, 17, result.stdout)
        self.assertNotIn("Package manager", result.stdout)
        self.assertFalse(self.log.exists())


if __name__ == "__main__":
    unittest.main()
