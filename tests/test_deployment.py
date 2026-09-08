#!/usr/bin/env python3
"""Regression checks for the explicit dotfiles deployment phases."""

import hashlib
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tarfile
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
INSTALL = ROOT / "install.sh"
DEPENDENCIES = ROOT / "scripts" / "installs" / "core-dependency.sh"
GO_INSTALLER = ROOT / "scripts" / "misc" / "install_go.sh"


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



class GoInstallerTest(unittest.TestCase):
    def test_checksum_failure_preserves_existing_install(self):
        with tempfile.TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            home = root / "home"
            prefix = home / ".local"
            fake_bin = root / "bin"
            payload = root / "payload" / "go" / "bin"
            fake_bin.mkdir()
            payload.mkdir(parents=True)
            for name in ("go", "gofmt"):
                path = payload / name
                path.write_text("not a real Go binary\n")
                path.chmod(0o755)

            archive = root / "go1.99.1.linux-amd64.tar.gz"
            with tarfile.open(archive, "w:gz") as tar:
                tar.add(payload.parent, arcname="go")
            checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
            corrupt_archive = root / "corrupt.tar.gz"
            corrupt_archive.write_bytes(archive.read_bytes() + b"corrupted\n")

            old_root = prefix / "lib" / "go1.98.0" / "bin"
            old_root.mkdir(parents=True)
            for name in ("go", "gofmt"):
                path = old_root / name
                path.write_text("old installation\n")
                path.chmod(0o755)
            (prefix / "bin").mkdir(parents=True)
            old_go_link = "../lib/go1.98.0/bin/go"
            old_gofmt_link = "../lib/go1.98.0/bin/gofmt"
            (prefix / "bin" / "go").symlink_to(old_go_link)
            (prefix / "bin" / "gofmt").symlink_to(old_gofmt_link)

            for command in (
                "bash",
                "cp",
                "env",
                "gzip",
                "ln",
                "mkdir",
                "mktemp",
                "mv",
                "readlink",
                "rm",
                "sed",
                "tar",
                "tr",
            ):
                source = shutil.which(command)
                if source is None:
                    self.fail(f"required test utility is unavailable: {command}")
                (fake_bin / command).symlink_to(source)
            for command in ("sha256sum", "shasum"):
                source = shutil.which(command)
                if source:
                    (fake_bin / command).symlink_to(source)
                    break
            uname = fake_bin / "uname"
            uname.write_text('#!/bin/sh\ncase "$1" in -s) echo Linux ;; -m) echo x86_64 ;; esac\n')
            uname.chmod(0o755)
            curl = fake_bin / "curl"
            curl.write_text(
                """#!/bin/sh
set -eu
output=
url=
while [ "$#" -gt 0 ]; do
    case "$1" in
        --output) output=$2; shift ;;
        *) url=$1 ;;
    esac
    shift
done
case "$url" in
    https://go.dev/VERSION?m=text)
        printf '%s\\n' go1.99.1 > "$output"
        ;;
    'https://go.dev/dl/?mode=json&include=all')
        printf '{"filename":"go1.99.1.linux-amd64.tar.gz","sha256":"%s"}\\n' "$GO_CHECKSUM" > "$output"
        ;;
    https://go.dev/dl/go1.99.1.linux-amd64.tar.gz)
        cp "$CORRUPT_ARCHIVE" "$output"
        ;;
    *) exit 1 ;;
esac
"""
            )
            curl.chmod(0o755)

            env = os.environ.copy()
            env.update(
                {
                    "HOME": str(home),
                    "PATH": str(fake_bin),
                    "GO_CHECKSUM": checksum,
                    "CORRUPT_ARCHIVE": str(corrupt_archive),
                }
            )
            result = subprocess.run(
                [str(GO_INSTALLER)],
                cwd=ROOT,
                env=env,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
            )

            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertEqual((prefix / "bin" / "go").readlink(), Path(old_go_link))
            self.assertEqual((prefix / "bin" / "gofmt").readlink(), Path(old_gofmt_link))
            self.assertEqual((old_root / "go").read_text(), "old installation\n")
            self.assertFalse((prefix / "lib" / "go1.99.1").exists())
            # The same upgrade must succeed with the authentic archive, so an
            # earlier parser/preflight failure cannot masquerade as protection.
            env["CORRUPT_ARCHIVE"] = str(archive)
            accepted = subprocess.run(
                [str(GO_INSTALLER)], cwd=ROOT, env=env,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
            )
            self.assertEqual(accepted.returncode, 0, accepted.stdout)
            self.assertEqual((prefix / "bin" / "go").read_text(), "not a real Go binary\n")
            self.assertEqual((old_root / "go").read_text(), "old installation\n")


class NeovimInstallerTest(unittest.TestCase):
    def test_corrupt_upgrade_preserves_existing_install_then_accepts_valid_archive(self):
        with tempfile.TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            prefix = root / "prefix"
            home = root / "home"
            fake_bin = root / "bin"
            fake_bin.mkdir()
            home.mkdir()

            version = "v0.12.5"
            archive_root_name = "nvim-linux-x86_64"
            payload = root / "payload" / archive_root_name
            (payload / "bin").mkdir(parents=True)
            (payload / "lib").mkdir()
            (payload / "share").mkdir()
            nvim = payload / "bin" / "nvim"
            nvim.write_text("#!/bin/sh\nprintf '%s\\n' new-neovim\n")
            nvim.chmod(0o755)
            archive = root / "nvim-linux-x86_64.tar.gz"
            with tarfile.open(archive, "w:gz") as tar:
                tar.add(payload, arcname=archive_root_name)
            checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
            corrupt_archive = root / "corrupt.tar.gz"
            corrupt_archive.write_bytes(archive.read_bytes() + b"corrupted\n")

            old_root = prefix / "lib" / "nvim-v0.12.4"
            old_nvim = old_root / "bin" / "nvim"
            old_nvim.parent.mkdir(parents=True)
            old_nvim.write_text("#!/bin/sh\nprintf '%s\\n' old-neovim\n")
            old_nvim.chmod(0o755)
            (old_root / "lib").mkdir()
            (old_root / "share").mkdir()
            (prefix / "bin").mkdir(parents=True)
            old_link = "../lib/nvim-v0.12.4/bin/nvim"
            (prefix / "bin" / "nvim").symlink_to(old_link)

            for command in (
                "awk",
                "bash",
                "cp",
                "env",
                "gzip",
                "ln",
                "mkdir",
                "mktemp",
                "mv",
                "readlink",
                "rm",
                "sed",
                "tar",
                "tr",
            ):
                source = shutil.which(command)
                if source is None:
                    self.fail(f"required test utility is unavailable: {command}")
                (fake_bin / command).symlink_to(source)

            for command in ("sha256sum", "shasum"):
                source = shutil.which(command)
                if source:
                    (fake_bin / command).symlink_to(source)
                    break
            else:
                self.fail("required checksum utility is unavailable")

            uname = fake_bin / "uname"
            uname.write_text(
                '#!/bin/sh\ncase "$1" in -s) echo Linux ;; -m) echo x86_64 ;; esac\n'
            )
            uname.chmod(0o755)
            curl = fake_bin / "curl"
            curl.write_text(
                """#!/bin/sh
set -eu
output=
url=
while [ "$#" -gt 0 ]; do
    case "$1" in
        --output) output=$2; shift ;;
        *) url=$1 ;;
    esac
    shift
done
case "$url" in
    https://github.com/neovim/neovim/releases/expanded_assets/v0.12.5)
        printf '%s\n' \
            '<li><a href="/neovim/neovim/releases/download/v0.12.5/nvim-linux-arm64.tar.gz">' \
            '<span>nvim-linux-arm64.tar.gz</span>' \
            '<span>sha256:0000000000000000000000000000000000000000000000000000000000000000</span>' \
            '<li><a href="/neovim/neovim/releases/download/v0.12.5/nvim-linux-x86_64.tar.gz">' \
            '<span>nvim-linux-x86_64.tar.gz</span>' \
            "<span>sha256:$NEOVIM_CHECKSUM</span>" \
            '<li><a href="/neovim/neovim/releases/download/v0.12.5/nvim-linux-x86_64.appimage">' \
            '<span>nvim-linux-x86_64.appimage</span>' \
            '<span>sha256:1111111111111111111111111111111111111111111111111111111111111111</span>' \
            > "$output"
        ;;
    https://github.com/neovim/neovim/releases/download/v0.12.5/nvim-linux-x86_64.tar.gz)
        cp "$ARCHIVE_TO_SERVE" "$output"
        ;;
    *) exit 1 ;;
esac
"""
            )
            curl.chmod(0o755)

            env = os.environ.copy()
            env.update(
                {
                    "HOME": str(home),
                    "PATH": str(fake_bin),
                    "NEOVIM_CHECKSUM": checksum,
                    "ARCHIVE_TO_SERVE": str(corrupt_archive),
                }
            )
            installer = ROOT / "scripts" / "misc" / "install_neovim.sh"
            result = subprocess.run(
                [str(installer), "--prefix", str(prefix), "--version", version],
                cwd=ROOT,
                env=env,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
            )

            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertEqual((prefix / "bin" / "nvim").readlink(), Path(old_link))
            old_consumer = subprocess.run(
                [str(prefix / "bin" / "nvim"), "--version"],
                text=True,
                stdout=subprocess.PIPE,
                check=False,
            )
            self.assertEqual(old_consumer.returncode, 0, old_consumer.stdout)
            self.assertEqual(old_consumer.stdout, "old-neovim\n")
            self.assertFalse((prefix / "lib" / f"nvim-{version}").exists())
            collision_root = prefix / "lib" / f"nvim-{version}"
            collision_sentinel = collision_root / "sentinel"
            collision_root.mkdir(parents=True)
            collision_sentinel.write_text("do not overwrite\n")
            env["ARCHIVE_TO_SERVE"] = str(archive)
            collision = subprocess.run(
                [str(installer), "--prefix", str(prefix), "--version", version],
                cwd=ROOT,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
            )
            self.assertNotEqual(collision.returncode, 0, collision.stdout)
            self.assertEqual(collision_sentinel.read_text(), "do not overwrite\n")
            self.assertEqual((prefix / "bin" / "nvim").readlink(), Path(old_link))
            shutil.rmtree(collision_root)



            env["ARCHIVE_TO_SERVE"] = str(archive)
            accepted = subprocess.run(
                [str(installer), "--prefix", str(prefix), "--version", version],
                cwd=ROOT,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
            )
            self.assertEqual(accepted.returncode, 0, accepted.stdout)
            new_root = prefix / "lib" / f"nvim-{version}"
            self.assertTrue((new_root / "bin" / "nvim").is_file())
            self.assertTrue((new_root / "lib").is_dir())
            self.assertTrue((new_root / "share").is_dir())
            self.assertEqual(
                (prefix / "bin" / "nvim").readlink(),
                Path(f"../lib/nvim-{version}/bin/nvim"),
            )
            consumer = subprocess.run(
                [str(prefix / "bin" / "nvim"), "--version"],
                text=True,
                stdout=subprocess.PIPE,
                check=False,
            )
            self.assertEqual(consumer.returncode, 0, consumer.stdout)
            self.assertEqual(consumer.stdout, "new-neovim\n")
            self.assertEqual(old_nvim.read_text(), "#!/bin/sh\nprintf '%s\\n' old-neovim\n")

            repeated = subprocess.run(
                [str(installer), "--prefix", str(prefix), "--version", version],
                cwd=ROOT,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
            )
            self.assertEqual(repeated.returncode, 0, repeated.stdout)
            self.assertEqual(
                (prefix / "bin" / "nvim").readlink(),
                Path(f"../lib/nvim-{version}/bin/nvim"),
            )

class UvInstallerTest(unittest.TestCase):
    def test_corrupt_upgrade_preserves_existing_install_then_accepts_valid_archive(self):
        with tempfile.TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            prefix = root / "prefix"
            home = root / "home"
            fake_bin = root / "bin"
            fake_bin.mkdir()
            home.mkdir()

            version = "0.8.17"
            archive_root_name = "uv-x86_64-unknown-linux-gnu"
            payload = root / "payload" / archive_root_name
            payload.mkdir(parents=True)
            for name, output in (("uv", "new-uv"), ("uvx", "new-uvx")):
                path = payload / name
                path.write_text(f"#!/bin/sh\nprintf '%s\\n' {output}\n")
                path.chmod(0o755)
            archive_name = f"{archive_root_name}.tar.gz"
            archive = root / archive_name
            with tarfile.open(archive, "w:gz") as tar:
                tar.add(payload, arcname=archive_root_name)
            checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
            corrupt_archive = root / "corrupt.tar.gz"
            corrupt_archive.write_bytes(archive.read_bytes() + b"corrupted\n")

            old_root = prefix / "lib" / "uv-0.8.16"
            old_root.mkdir(parents=True)
            for name in ("uv", "uvx"):
                path = old_root / name
                path.write_text(f"#!/bin/sh\nprintf '%s\\n' old-{name}\n")
                path.chmod(0o755)
            (prefix / "bin").mkdir(parents=True)
            old_links = {
                name: f"../lib/uv-0.8.16/{name}" for name in ("uv", "uvx")
            }
            for name, target in old_links.items():
                (prefix / "bin" / name).symlink_to(target)

            for command in (
                "bash",
                "chmod",
                "cp",
                "env",
                "gzip",
                "ln",
                "mkdir",
                "mktemp",
                "mv",
                "readlink",
                "rm",
                "sed",
                "tar",
                "tr",
            ):
                source = shutil.which(command)
                if source is None:
                    self.fail(f"required test utility is unavailable: {command}")
                (fake_bin / command).symlink_to(source)

            for command in ("sha256sum", "shasum"):
                source = shutil.which(command)
                if source:
                    (fake_bin / command).symlink_to(source)
                    break
            else:
                self.fail("required checksum utility is unavailable")

            uname = fake_bin / "uname"
            uname.write_text(
                '#!/bin/sh\ncase "$1" in -s) echo Linux ;; -m) echo x86_64 ;; esac\n'
            )
            uname.chmod(0o755)
            curl = fake_bin / "curl"
            curl.write_text(
                f"""#!/bin/sh
set -eu
output=
url=
while [ "$#" -gt 0 ]; do
    case "$1" in
        --output) output=$2; shift ;;
        *) url=$1 ;;
    esac
    shift
done
case "$url" in
    https://releases.astral.sh/github/uv/releases/download/{version}/{archive_name}.sha256)
        printf '%s  %s\\n' "$UV_CHECKSUM" "{archive_name}" > "$output"
        ;;
    https://releases.astral.sh/github/uv/releases/download/{version}/{archive_name})
        cp "$ARCHIVE_TO_SERVE" "$output"
        ;;
    *) exit 1 ;;
esac
"""
            )
            curl.chmod(0o755)

            env = os.environ.copy()
            env.update(
                {
                    "HOME": str(home),
                    "PATH": str(fake_bin),
                    "UV_CHECKSUM": checksum,
                    "ARCHIVE_TO_SERVE": str(corrupt_archive),
                }
            )
            installer = ROOT / "scripts" / "misc" / "install_uv.sh"
            result = subprocess.run(
                [str(installer), "--prefix", str(prefix), "--version", version],
                cwd=ROOT,
                env=env,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
            )

            self.assertNotEqual(result.returncode, 0, result.stdout)
            for name, target in old_links.items():
                link = prefix / "bin" / name
                self.assertEqual(link.readlink(), Path(target))
                old_consumer = subprocess.run(
                    [str(link), "--version"],
                    text=True,
                    stdout=subprocess.PIPE,
                    check=False,
                )
                self.assertEqual(old_consumer.returncode, 0, old_consumer.stdout)
                self.assertEqual(old_consumer.stdout, f"old-{name}\n")
            self.assertFalse((prefix / "lib" / f"uv-{version}").exists())
            collision_root = prefix / "lib" / f"uv-{version}"
            collision_sentinel = collision_root / "sentinel"
            collision_root.mkdir(parents=True)
            collision_sentinel.write_text("do not overwrite\n")
            env["ARCHIVE_TO_SERVE"] = str(archive)
            collision = subprocess.run(
                [str(installer), "--prefix", str(prefix), "--version", version],
                cwd=ROOT,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
            )
            self.assertNotEqual(collision.returncode, 0, collision.stdout)
            self.assertEqual(collision_sentinel.read_text(), "do not overwrite\n")
            for name, target in old_links.items():
                self.assertEqual((prefix / "bin" / name).readlink(), Path(target))
            shutil.rmtree(collision_root)


            env["ARCHIVE_TO_SERVE"] = str(archive)
            accepted = subprocess.run(
                [str(installer), "--prefix", str(prefix), "--version", version],
                cwd=ROOT,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
            )
            self.assertEqual(accepted.returncode, 0, accepted.stdout)
            new_root = prefix / "lib" / f"uv-{version}"
            self.assertTrue((new_root / "uv").is_file())
            self.assertTrue((new_root / "uvx").is_file())
            for name in ("uv", "uvx"):
                self.assertEqual(
                    (prefix / "bin" / name).readlink(),
                    Path(f"../lib/uv-{version}/{name}"),
                )
            consumer = subprocess.run(
                [str(prefix / "bin" / "uv"), "--version"],
                text=True,
                stdout=subprocess.PIPE,
                check=False,
            )
            self.assertEqual(consumer.returncode, 0, consumer.stdout)
            self.assertEqual(consumer.stdout, "new-uv\n")
            for name in ("uv", "uvx"):
                self.assertEqual(
                    (old_root / name).read_text(),
                    f"#!/bin/sh\nprintf '%s\\n' old-{name}\n",
                )

            repeated = subprocess.run(
                [str(installer), "--prefix", str(prefix), "--version", version],
                cwd=ROOT,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
            )
            self.assertEqual(repeated.returncode, 0, repeated.stdout)
            for name in ("uv", "uvx"):
                self.assertEqual(
                    (prefix / "bin" / name).readlink(),
                    Path(f"../lib/uv-{version}/{name}"),
                )




class TreeSitterInstallerTest(unittest.TestCase):
    def test_existing_release_requires_managed_link_without_deleting_content(self):
        with tempfile.TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            prefix = root / "prefix"
            release = prefix / "lib" / "tree-sitter-v0.27.0"
            release.mkdir(parents=True)
            sentinel = release / "keep"
            sentinel.write_text("existing content\n")
            fake_bin = root / "bin"
            fake_bin.mkdir()
            curl = fake_bin / "curl"
            curl.write_text("#!/bin/sh\nexit 99\n")
            curl.chmod(0o755)
            env = dict(os.environ, HOME=str(root), PATH=f"{fake_bin}{os.pathsep}{os.environ['PATH']}")
            argv = [
                str(ROOT / "scripts" / "misc" / "install_tree_sitter.sh"),
                "--prefix", str(prefix), "--version", "0.27.0",
            ]
            rejected = subprocess.run(
                argv, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            )
            self.assertNotEqual(rejected.returncode, 0, rejected.stdout)
            self.assertEqual(sentinel.read_text(), "existing content\n")

            (release / "bin").mkdir()
            binary = release / "bin" / "tree-sitter"
            binary.write_text("#!/bin/sh\necho 'tree-sitter 0.26.0'\n")
            binary.chmod(0o755)
            (prefix / "bin").mkdir()
            link = prefix / "bin" / "tree-sitter"
            target = "../lib/tree-sitter-v0.27.0/bin/tree-sitter"
            link.symlink_to(target)
            mismatched = subprocess.run(
                argv, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            )
            self.assertNotEqual(mismatched.returncode, 0, mismatched.stdout)
            self.assertEqual(sentinel.read_text(), "existing content\n")
            binary.write_text("#!/bin/sh\necho 'tree-sitter 0.27.0'\n")
            repeated = subprocess.run(
                argv, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            )
            self.assertEqual(repeated.returncode, 0, repeated.stdout)
            self.assertEqual(link.readlink(), Path(target))
            self.assertEqual(sentinel.read_text(), "existing content\n")


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

    def test_editor_request_requires_compatible_editor_and_parser_cli(self):
        for editor, parser, supported in (
            ("0.12.0", "0.26.1", True),
            ("0.11.9", "0.26.1", False),
            ("0.12.0", "0.26.0", False),
        ):
            with self.subTest(editor=editor, parser=parser):
                self.write_executable("nvim", f"#!/bin/sh\necho 'NVIM v{editor}'\n")
                self.write_executable("tree-sitter", f"#!/bin/sh\necho 'tree-sitter {parser}'\n")
                result = self.run_deps("--auto-yes", "neovim")
                if supported:
                    self.assertEqual(result.returncode, 0, result.stdout)
                else:
                    # This minimal host cannot install replacements. It must
                    # not report success for an editor/CLI below the floor.
                    self.assertNotEqual(result.returncode, 0, result.stdout)

    def test_no_sudo_never_invokes_sudo_and_reports_unsupported(self):
        self.write_executable(
            "sudo", '#!/bin/sh\necho invoked >> "$CALL_LOG"\nexit 99\n'
        )
        self.env["CALL_LOG"] = str(self.log)
        result = self.run_deps("--no-sudo", "--auto-yes", "git-lfs")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertFalse(self.log.exists())
        self.assertIn("no supported deterministic local recipe", result.stdout.lower())

    def test_missing_native_manager_refuses_before_local_install(self):
        result = self.run_deps("--auto-yes", "uv", "git-lfs")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertFalse((Path(self.env["HOME"]) / ".local").exists())

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

    def test_stale_managed_fzf_refuses_repair_without_build_prerequisite(self):
        managed_bin = Path(self.env["HOME"]) / ".local" / "bin" / "fzf"
        managed_bin.parent.mkdir(parents=True)
        old_binary = "#!/bin/sh\nprintf '0.74.0 (6765f464)\\n'\n"
        managed_bin.write_text(old_binary)
        managed_bin.chmod(0o755)
        old_mode = stat.S_IMODE(managed_bin.stat().st_mode)

        result = self.run_deps("--no-sudo", "--auto-yes", "fzf")

        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertEqual(managed_bin.read_text(), old_binary)
        self.assertEqual(stat.S_IMODE(managed_bin.stat().st_mode), old_mode)
        self.assertFalse(
            (Path(self.env["HOME"]) / ".local" / "share" / "fzf" / "shell").exists()
        )

    def test_external_fzf_without_integration_scripts_remains_accepted(self):
        self.write_executable("fzf", "#!/bin/sh\nprintf 'external fzf\\n'\n")

        result = self.run_deps("--no-sudo", "--auto-yes", "fzf")

        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertFalse((Path(self.env["HOME"]) / ".local" / "bin" / "fzf").exists())


if __name__ == "__main__":
    unittest.main()
