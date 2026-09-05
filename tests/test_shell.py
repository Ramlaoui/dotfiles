import os
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SHELL_FUNCTIONS = ROOT / "shell/.config/shell/functions"
SHELL_ENV = ROOT / "shell/.config/shell/env"
SHELL_ALIASES = ROOT / "shell/.config/shell/aliases"


def run_shell(script, *args, env=None, shell="/bin/bash"):
    return subprocess.run(
        [shell, "--noprofile", "--norc", "-c", script, "shell", *map(str, args)],
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )


class ShellSafetyTests(unittest.TestCase):
    def test_tmpclean_refuses_unsafe_targets_and_cleans_private_target(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            home = root / "home"
            public = root / "public"
            private = root / "private"
            newline_target = root / "private-target\n"
            newline_sibling = root / "private-target"
            home.mkdir(mode=0o700)
            public.mkdir(mode=0o755)
            private.mkdir(mode=0o700)
            newline_target.mkdir(mode=0o700)
            newline_sibling.mkdir(mode=0o700)
            (home / "sentinel").write_text("keep", encoding="utf-8")
            (public / "sentinel").write_text("keep", encoding="utf-8")
            (private / "sentinel").write_text("remove", encoding="utf-8")
            (newline_target / "sentinel").write_text("remove", encoding="utf-8")
            (newline_sibling / "sentinel").write_text("keep", encoding="utf-8")
            env = os.environ | {
                "HOME": str(home),
                "PATH": os.environ["PATH"],
                "TMPDIR": "",
                "DOTFILES_TMPDIR": "",
            }
            result = run_shell(
                f"source {SHELL_FUNCTIONS!s}; "
                'tmpclean; test $? -ne 0; test -f "$HOME/sentinel"; '
                'tmpclean /; test $? -ne 0; test -f "$HOME/sentinel"; '
                'tmpclean "$1"; test $? -ne 0; test -f "$HOME/sentinel"; '
                'tmpclean "$2"; test $? -ne 0; test -f "$HOME/sentinel"; '
                'tmpclean "$3"; test $? -ne 0; test -f "$3/sentinel"; '
                'tmpclean "$4"; test $? -eq 0; test ! -e "$4/sentinel"; '
                'tmpclean "$5"; test $? -eq 0; test ! -e "$5/sentinel"; test -f "$6/sentinel"',
                root / "missing",
                home,
                public,
                private,
                newline_target,
                newline_sibling,
                env=env,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((home / "sentinel").exists())
            self.assertTrue((public / "sentinel").exists())
            self.assertFalse((private / "sentinel").exists())
            self.assertFalse((newline_target / "sentinel").exists())
            self.assertTrue((newline_sibling / "sentinel").exists())

    def test_archive_names_are_literal_and_output_format_is_explicit(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            source = root / "name [literal];$(touch SHOULD_NOT_EXIST).txt"
            source.write_text("archive payload\n", encoding="utf-8")
            archive = root / "output [literal];$(touch SHOULD_NOT_EXIST).tar.gz"
            output = root / "extract dir [literal];$(touch SHOULD_NOT_EXIST)"
            result = run_shell(
                f'source {SHELL_FUNCTIONS!s}; compress "$1" "$2" && extract "$2" "$3"',
                source,
                archive,
                output,
                env=os.environ.copy(),
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(
                (output / source.name).read_text(encoding="utf-8"), "archive payload\n"
            )
            self.assertFalse((root / "SHOULD_NOT_EXIST").exists())

            protected = root / "protected"
            alias = root / "protected.gz"
            protected.write_text("must remain", encoding="utf-8")
            os.link(protected, alias)
            refused = run_shell(
                f'source {SHELL_FUNCTIONS!s}; compress "$1" "$2"',
                protected,
                alias,
                env=os.environ.copy(),
            )
            self.assertNotEqual(refused.returncode, 0)
            self.assertEqual(protected.read_text(encoding="utf-8"), "must remain")

    def test_startup_is_quiet_without_optional_files_and_respects_xdg(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            home = root / "home"
            xdg = root / "config"
            data = root / "data"
            home.mkdir()
            (xdg / "shell").mkdir(parents=True)
            for source, target in (
                (SHELL_ENV, xdg / "shell/env"),
                (SHELL_ALIASES, xdg / "shell/aliases"),
                (SHELL_FUNCTIONS, xdg / "shell/functions"),
            ):
                shutil.copy2(source, target)
            shutil.copy2(ROOT / "bash/.bashrc", home / ".bashrc")
            network_marker = root / "network-called"
            fake_bin = root / "bin"
            fake_bin.mkdir()
            curl = fake_bin / "curl"
            curl.write_text(
                f"#!/bin/sh\nprintf called > {network_marker}\n", encoding="utf-8"
            )
            curl.chmod(curl.stat().st_mode | stat.S_IXUSR)
            env = {
                "HOME": str(home),
                "XDG_CONFIG_HOME": str(xdg),
                "XDG_DATA_HOME": str(data),
                "PATH": str(fake_bin),
            }
            result = subprocess.run(
                [
                    "/bin/bash",
                    "--noprofile",
                    "-i",
                    "-c",
                    "printf '%s\\n' \"$XDG_CONFIG_HOME|$XDG_DATA_HOME\"",
                ],
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip().splitlines()[-1], f"{xdg}|{data}")
            self.assertNotIn("curl", result.stderr)
            self.assertNotIn("No such file", result.stderr)
            self.assertFalse(network_marker.exists())

        zsh = shutil.which("zsh")
        if zsh:
            with tempfile.TemporaryDirectory() as root:
                root = Path(root)
                home = root / "home"
                xdg = root / "config"
                home.mkdir()
                (xdg / "shell").mkdir(parents=True)
                for source, target in (
                    (SHELL_ENV, xdg / "shell/env"),
                    (SHELL_ALIASES, xdg / "shell/aliases"),
                    (SHELL_FUNCTIONS, xdg / "shell/functions"),
                ):
                    shutil.copy2(source, target)
                shutil.copy2(ROOT / "zsh/.zshrc", home / ".zshrc")
                fake_bin = root / "bin"
                fake_bin.mkdir()
                result = subprocess.run(
                    [
                        zsh,
                        "-d",
                        "-i",
                        "-c",
                        "printf '%s\\n' \"$XDG_CONFIG_HOME|$XDG_DATA_HOME\"",
                    ],
                    env={
                        "HOME": str(home),
                        "XDG_CONFIG_HOME": str(xdg),
                        "XDG_DATA_HOME": str(root / "data"),
                        "PATH": str(fake_bin),
                    },
                    text=True,
                    capture_output=True,
                    check=False,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(
                    result.stdout.strip().splitlines()[-1], f"{xdg}|{root / 'data'}"
                )

    def test_credential_adapter_selects_available_helper_protocol(self):
        adapter = ROOT / "git/.config/git/credential-helper"
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            marker = root / "selected"
            home = root / "home"
            home.mkdir()
            helper = root / "git-credential-libsecret"
            helper.write_text(
                '#!/bin/sh\nprintf \'%s\' "$1" > "$HELPER_MARKER"\n'
                "printf 'protocol=https\\nhost=example.test\\nusername=stub\\n\\n'\n",
                encoding="utf-8",
            )
            helper.chmod(helper.stat().st_mode | stat.S_IXUSR)
            env = {
                "HOME": str(home),
                "PATH": str(root),
                "HELPER_MARKER": str(marker),
            }
            result = subprocess.run(
                [str(adapter), "get"],
                input="protocol=https\nhost=example.test\n\n",
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(marker.read_text(encoding="utf-8"), "get")
            self.assertIn("username=stub", result.stdout)


if __name__ == "__main__":
    unittest.main()
