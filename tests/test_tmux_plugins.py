"""Contracts for plugin bootstrap, preservation, and phase orchestration."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "scripts/installs/tmux-plugins.sh"
TPM_REVISION = "e261deb1b47614eed3400089ce7197dc68acc4eb"


class TmuxPluginsTest(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)
        self.home = self.root / "home"
        self.config = self.root / "config with spaces"
        self.plugins = self.config / "tmux/plugins"
        self.fake_bin = self.root / "bin"
        self.fake_bin.mkdir()
        self.home.mkdir()
        self.config.joinpath("tmux").mkdir(parents=True)
        self.config.joinpath("tmux/tmux.conf").write_text("set -g @plugin 'owner/example'\n")
        self.log = self.root / "calls"
        self.env = dict(
            os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.config),
            PATH=f"{self.fake_bin}{os.pathsep}{os.environ['PATH']}",
            CALL_LOG=str(self.log), EXPECTED_REVISION=TPM_REVISION,
            TMUX="/tmp/existing-tmux,123,0", INSTALL_STATUS="0", GIT_STATUS="0",
        )
        self.tpm_installer = self.root / "fake-install-plugins"
        self.tpm_installer.write_text(
            '#!/bin/sh\nprintf "install:%s\\n" "$TMUX" >> "$CALL_LOG"\nexit "$INSTALL_STATUS"\n'
        )
        self.tpm_installer.chmod(0o755)
        self.env["FAKE_TPM_INSTALLER"] = str(self.tpm_installer)
        self.write_command("git", '''#!/bin/sh
printf 'git:%s\n' "$*" >> "$CALL_LOG"
[ "$GIT_STATUS" = 0 ] || exit "$GIT_STATUS"
case "$1" in
    clone)
        for arg in "$@"; do destination=$arg; done
        mkdir -p "$destination/bin"
        cp "$FAKE_TPM_INSTALLER" "$destination/bin/install_plugins"
        cp "$FAKE_TPM_INSTALLER" "$destination/tpm"
        ;;
    -C)
        if [ "$3" = rev-parse ]; then printf '%s\n' "$EXPECTED_REVISION"; fi
        ;;
    *) exit 99 ;;
esac
''')
        self.write_command("tmux", '''#!/bin/sh
printf 'tmux:%s\n' "$*" >> "$CALL_LOG"
case "$*" in *display-message*) echo 456 ;; esac
''')

    def tearDown(self):
        self.tempdir.cleanup()

    def write_command(self, name, content):
        path = self.fake_bin / name
        path.write_text(content)
        path.chmod(0o755)

    def run_plugins(self):
        return subprocess.run(
            [str(INSTALLER)], env=self.env, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        )

    def existing_tpm(self):
        tpm = self.plugins / "tpm"
        tpm.joinpath("bin").mkdir(parents=True)
        shutil.copy2(self.tpm_installer, tpm / "tpm")
        shutil.copy2(self.tpm_installer, tpm / "bin/install_plugins")

    def test_bootstrap_is_pinned_and_uses_private_server_and_xdg_path(self):
        result = self.run_plugins()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertTrue((self.plugins / "tpm/bin/install_plugins").is_file())
        calls = self.log.read_text()
        self.assertIn(f"checkout --quiet --detach {TPM_REVISION}", calls)
        self.assertIn("-f /dev/null new-session", calls)
        self.assertIn(f"TMUX_PLUGIN_MANAGER_PATH {self.plugins}/", calls)
        self.assertNotIn("existing-tmux", calls)
        self.assertNotIn("source-file", calls)
        socket = next(line.split(":", 1)[1].split(",")[0]
                      for line in calls.splitlines() if line.startswith("install:"))
        self.assertIn(f"tmux:-S {socket} kill-server", calls)
        self.assertFalse(Path(socket).parent.exists())

    def test_repeat_preserves_existing_tpm_and_other_plugins(self):
        self.existing_tpm()
        sentinel = self.plugins / "custom-plugin/local-changes"
        sentinel.parent.mkdir()
        sentinel.write_text("preserve me\n")
        for _ in range(2):
            result = self.run_plugins()
            self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(sentinel.read_text(), "preserve me\n")
        self.assertNotIn("git:", self.log.read_text())
        self.assertEqual(self.log.read_text().count("install:"), 2)

    def test_incomplete_tpm_refuses_without_replacing_contents(self):
        sentinel = self.plugins / "tpm/local-changes"
        sentinel.parent.mkdir(parents=True)
        sentinel.write_text("preserve me\n")
        result = self.run_plugins()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertEqual(sentinel.read_text(), "preserve me\n")
        self.assertFalse(self.log.exists())

    def test_clone_failure_propagates_without_partial_tpm_install(self):
        self.env["GIT_STATUS"] = "17"
        result = self.run_plugins()
        self.assertEqual(result.returncode, 17, result.stdout)
        self.assertFalse((self.plugins / "tpm").exists())

    def test_revision_mismatch_refuses_before_install(self):
        self.env["EXPECTED_REVISION"] = "wrong-revision"
        result = self.run_plugins()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertFalse((self.plugins / "tpm").exists())

    def test_plugin_failure_propagates_and_cleans_private_server(self):
        self.existing_tpm()
        self.env["INSTALL_STATUS"] = "23"
        result = self.run_plugins()
        self.assertEqual(result.returncode, 23, result.stdout)
        self.assertIn("kill-server", self.log.read_text())
        self.assertNotIn("[OK]", result.stdout)

    def test_missing_synced_config_fails_without_network(self):
        self.config.joinpath("tmux/tmux.conf").unlink()
        result = self.run_plugins()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("sync tmux", result.stdout)
        self.assertFalse(self.log.exists())


class PluginPhaseTest(unittest.TestCase):
    @unittest.skipUnless(shutil.which("stow"), "GNU Stow is not installed")
    def test_sync_preserves_plugins_and_does_not_bootstrap_tpm(self):
        with tempfile.TemporaryDirectory() as tempdir:
            home = Path(tempdir)
            config = home / "config"
            env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(config))
            for _ in range(2):
                result = subprocess.run(
                    [str(ROOT / "install.sh"), "sync", "tmux"], env=env,
                    text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                )
                self.assertEqual(result.returncode, 0, result.stdout)
                self.assertFalse((config / "tmux/plugins/tpm").exists())
                sentinel = config / "tmux/plugins/custom/keep"
                if sentinel.exists():
                    self.assertEqual(sentinel.read_text(), "preserve me\n")
                else:
                    sentinel.parent.mkdir(parents=True)
                    sentinel.write_text("preserve me\n")

    def test_all_orders_phases_and_propagates_plugin_failure(self):
        with tempfile.TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            project = root / "dotfiles"
            scripts = project / "scripts/installs"
            scripts.mkdir(parents=True)
            shutil.copy2(ROOT / "install.sh", project / "install.sh")
            for package in "bash zsh tmux nvim git python vscode shell linux rofi ghostty".split():
                (project / package).mkdir()
            for name, content in {
                "core-dependency.sh": '#!/bin/sh\necho deps >> "$CALL_LOG"\n',
                "tmux-plugins.sh": '#!/bin/sh\necho plugins >> "$CALL_LOG"\nexit 23\n',
            }.items():
                path = scripts / name
                path.write_text(content)
                path.chmod(0o755)
            fake_bin = root / "bin"
            fake_bin.mkdir()
            stow = fake_bin / "stow"
            stow.write_text('#!/bin/sh\necho sync >> "$CALL_LOG"\n')
            stow.chmod(0o755)
            home = root / "home"
            home.mkdir()
            log = root / "calls"
            env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / ".config"),
                       PATH=f"{fake_bin}{os.pathsep}{os.environ['PATH']}", CALL_LOG=str(log))
            result = subprocess.run(
                [str(project / "install.sh"), "all", "--auto-yes"], env=env,
                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            )
            self.assertEqual(result.returncode, 23, result.stdout)
            calls = log.read_text().splitlines()
            self.assertEqual(calls[0], "deps")
            self.assertEqual(calls[-1], "plugins")
            self.assertIn("sync", calls[1:-1])

    def test_plugins_rejects_sync_and_dependency_flags_without_network(self):
        for arg in ("--dry-run", "--with-omarchy", "--no-sudo", "--auto-yes", "tmux"):
            with self.subTest(arg=arg):
                result = subprocess.run(
                    [str(ROOT / "install.sh"), "plugins", arg],
                    text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                )
                self.assertEqual(result.returncode, 2, result.stdout)


if __name__ == "__main__":
    unittest.main()
