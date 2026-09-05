"""Exercise profile patching without a real browser profile."""

import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
PATCHER = REPO / "zen/.config/zen/apply-zen-profile.py"
SHORTCUTS = "zen-keyboard-shortcuts.json"


class ZenProfileTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.profile = self.root / "profile with spaces"
        self.profile.mkdir()
        self.path = self.profile / SHORTCUTS
        self.original = {
            "unrelated": {"preserve": True},
            "shortcuts": [{"id": "split", "key": "a", "custom": "keep"}],
        }
        self.path.write_text(json.dumps(self.original))
        self.path.chmod(0o600)
        self.patch = self.root / "patch.json"
        self.patch.write_text(json.dumps({"shortcuts": [{"id": "split", "key": "b"}]}))
        self.env = dict(
            os.environ, HOME=str(self.root), XDG_CONFIG_HOME=str(self.root / "config")
        )

    def run_patcher(self, *args, explicit=True):
        command = [sys.executable, str(PATCHER), "--patch", str(self.patch)]
        if explicit:
            command += ["--profile", str(self.profile)]
        return subprocess.run(
            command + list(args),
            env=self.env,
            capture_output=True,
            text=True,
            timeout=10,
        )

    def backups(self):
        return sorted(self.profile.glob(f"{SHORTCUTS}.backup-before-dotfiles-*"))

    def test_dry_run_does_not_write_profile_or_lock(self):
        before = self.path.read_bytes()
        result = self.run_patcher("--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.path.read_bytes(), before)
        self.assertEqual(list(self.profile.iterdir()), [self.path])

    def test_apply_preserves_other_fields_and_original_backup(self):
        original_bytes = self.path.read_bytes()
        result = self.run_patcher()
        self.assertEqual(result.returncode, 0, result.stderr)
        updated = json.loads(self.path.read_text())
        self.assertEqual(
            updated["shortcuts"][0], {"id": "split", "key": "b", "custom": "keep"}
        )
        self.assertEqual(updated["unrelated"], self.original["unrelated"])
        self.assertEqual([p.read_bytes() for p in self.backups()], [original_bytes])
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)
        result = self.run_patcher()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([p.read_bytes() for p in self.backups()], [original_bytes])

    def test_each_distinct_update_preserves_previous_version(self):
        versions = [self.path.read_bytes()]
        for key in ("b", "c", "d"):
            self.patch.write_text(
                json.dumps({"shortcuts": [{"id": "split", "key": key}]})
            )
            result = self.run_patcher()
            self.assertEqual(result.returncode, 0, result.stderr)
            versions.append(self.path.read_bytes())
        self.assertCountEqual([p.read_bytes() for p in self.backups()], versions[:-1])
        self.assertFalse(list(self.profile.glob(f".{SHORTCUTS}.*.tmp")))

    def test_browser_profile_lock_refuses_update(self):
        original_bytes = self.path.read_bytes()
        with (self.profile / ".parentlock").open("w") as lock:
            fcntl.lockf(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            result = self.run_patcher()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.path.read_bytes(), original_bytes)
        self.assertEqual(self.backups(), [])
        result = self.run_patcher()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.path.read_text())["shortcuts"][0]["key"], "b")

    def test_missing_to_null_is_an_update_then_a_noop(self):
        original_bytes = self.path.read_bytes()
        self.patch.write_text(
            json.dumps({"shortcuts": [{"id": "split", "keycode": None}]})
        )
        result = self.run_patcher()
        self.assertEqual(result.returncode, 0, result.stderr)
        shortcut = json.loads(self.path.read_text())["shortcuts"][0]
        self.assertIn("keycode", shortcut)
        self.assertIsNone(shortcut["keycode"])
        result = self.run_patcher()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([p.read_bytes() for p in self.backups()], [original_bytes])

    def test_invalid_patch_does_not_write_or_backup(self):
        original_bytes = self.path.read_bytes()
        self.patch.write_text(
            json.dumps({"shortcuts": [{"id": "missing", "key": "b"}]})
        )
        result = self.run_patcher()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.path.read_bytes(), original_bytes)
        self.assertEqual(self.backups(), [])

    @unittest.skipIf(
        sys.platform == "darwin", "macOS has one supported installation root"
    )
    def test_ambiguous_roots_require_explicit_profile(self):
        roots = [self.root / "config/zen", self.root / ".zen"]
        for root in roots:
            root.mkdir(parents=True)
            (root / "profiles.ini").write_text(
                f"[Profile0]\nName=default\nIsRelative=0\nPath={self.profile}\nDefault=1\n"
            )
        result = self.run_patcher("--dry-run", explicit=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(json.loads(self.path.read_text()), self.original)
        (roots[1] / "profiles.ini").unlink()
        result = self.run_patcher("--dry-run", explicit=False)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_ambiguous_profiles_do_not_choose_first(self):
        root = self.root / (
            "Library/Application Support/zen"
            if sys.platform == "darwin"
            else "config/zen"
        )
        root.mkdir(parents=True)
        other = self.root / "other-profile"
        other.mkdir()
        (other / SHORTCUTS).write_text(json.dumps(self.original))
        (root / "profiles.ini").write_text(
            f"[Profile0]\nIsRelative=0\nPath={self.profile}\n"
            f"[Profile1]\nIsRelative=0\nPath={other}\n"
        )
        result = self.run_patcher("--dry-run", explicit=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(json.loads(self.path.read_text()), self.original)

        (root / "profiles.ini").write_text(
            f"[Profile0]\nIsRelative=0\nPath={self.profile}\nDefault=1\n"
        )
        result = self.run_patcher("--dry-run", explicit=False)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
