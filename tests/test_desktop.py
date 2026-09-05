from __future__ import annotations

import base64
import concurrent.futures
import json
import os
import stat
import subprocess
import shutil
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ROFI = ROOT / "rofi/.config/rofi/scripts"


class DesktopScriptTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.tmp = Path(self.tempdir.name)
        self.bin = self.tmp / "bin"
        self.bin.mkdir()

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def executable(self, name: str, body: str) -> Path:
        path = self.bin / name
        content = textwrap.dedent(body)
        if not content.startswith("#!"):
            content = f"#!{sys.executable}\n" + content
        path.write_text(content, encoding="utf-8")
        path.chmod(0o700)
        return path

    def env(self, **extra: str) -> dict[str, str]:
        runtime_bin = Path(sys.executable).parent
        result = {
            "PATH": f"{self.bin}:{runtime_bin}:/usr/bin:/bin",
            "HOME": str(self.tmp),
            "USER": "desktop-test",
            "LC_ALL": "C",
        }
        result.update(extra)
        return result

    @staticmethod
    def bash_path() -> str:
        candidates = [
            "/opt/homebrew/bin/bash",
            "/usr/local/bin/bash",
            "/usr/bin/bash",
            shutil.which("bash"),
        ]
        for candidate in candidates:
            if (
                candidate
                and os.path.isfile(candidate)
                and os.access(candidate, os.X_OK)
            ):
                return candidate
        raise RuntimeError(
            "a modern bash executable is required for desktop script tests"
        )

    def run_script(
        self, path: Path, *, env: dict[str, str], args: list[str] | None = None
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [self.bash_path(), str(path), *(args or [])],
            cwd=ROOT,
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )

    @unittest.skipUnless(
        sys.platform.startswith("linux"), "requires Linux /proc process identity"
    )
    def test_process_menu_uses_selected_pid_and_targeted_signal(self) -> None:
        pid = os.getpid()
        log = self.tmp / "signals"
        self.executable(
            "ps",
            f"""
            # The real test process has a stable /proc start-time identity.
            print({pid!r}, 'safe-target', '1.0', '2.0')
            """,
        )
        self.executable(
            "kill",
            f"""
            from pathlib import Path
            Path({str(log)!r}).write_text(' '.join(__import__('sys').argv[1:]), encoding='utf-8')
            """,
        )
        self.executable(
            "rofi",
            """
            import sys
            if '-e' in sys.argv:
                raise SystemExit(0)
            choices = sys.stdin.read().splitlines()
            if any(line == 'Yes' for line in choices):
                print('Yes')
            else:
                print(next(line for line in choices if line.startswith('🔧 ')))
            """,
        )

        result = self.run_script(
            ROFI / "system-monitor.sh",
            env=self.env(),
            args=["processes"],
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(log.read_text(encoding="utf-8"), f"-TERM -- {pid}")

    def test_unavailable_lock_does_not_suspend(self) -> None:

        calls = self.tmp / "calls"
        self.executable(
            "rofi",
            """
            import sys
            if '-dmenu' in sys.argv:
                print('🔒 Lock')
            else:
                open(%r, 'a', encoding='utf-8').write('rofi-error\\n')
            """
            % str(calls),
        )
        self.executable(
            "systemctl",
            f"""
            from pathlib import Path
            Path({str(calls)!r}).open('a', encoding='utf-8').write('systemctl ' + ' '.join(__import__('sys').argv[1:]) + '\\n')
            raise SystemExit(0)
            """,
        )

        # PATH contains only the stubs, so no desktop locker/loginctl adapter is
        # visible.  A lock failure must not fall through to systemctl suspend.
        result = self.run_script(
            ROFI / "power-menu.sh",
            env={"PATH": str(self.bin), "HOME": str(self.tmp)},
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("suspend", calls.read_text(encoding="utf-8"))

    def test_hyprland_lock_uses_native_omarchy_adapter(self) -> None:
        log = self.tmp / "lock"
        self.executable(
            "rofi",
            """
            import sys
            if '-dmenu' in sys.argv:
                print('🔒 Lock')
            """,
        )
        self.executable(
            "omarchy",
            f"""
            from pathlib import Path
            import sys
            Path({str(log)!r}).write_text(' '.join(sys.argv[1:]), encoding='utf-8')
            """,
        )
        result = self.run_script(
            ROFI / "power-menu.sh",
            env={
                "PATH": str(self.bin),
                "HOME": str(self.tmp),
                "XDG_CURRENT_DESKTOP": "Hyprland",
                "HYPRLAND_INSTANCE_SIGNATURE": "desktop-test",
            },
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(log.read_text(encoding="utf-8"), "system lock")

    def test_logout_targets_current_session_only(self) -> None:
        log = self.tmp / "session"
        self.executable(
            "rofi",
            """
            import sys
            if '-dmenu' in sys.argv:
                print('🚪 Logout')
            """,
        )
        self.executable(
            "loginctl",
            f"""
            import sys
            from pathlib import Path
            Path({str(log)!r}).write_text(' '.join(sys.argv[1:]), encoding='utf-8')
            """,
        )
        result = self.run_script(
            ROFI / "power-menu.sh",
            env={
                "PATH": str(self.bin),
                "HOME": str(self.tmp),
                "XDG_SESSION_ID": "session-7",
            },
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(log.read_text(encoding="utf-8"), "terminate-session session-7")

    def test_clipboard_multiline_private_and_opt_in(self) -> None:
        history = self.tmp / "cache" / "history.json"
        copied = self.tmp / "copied"
        value = "first line\nsecond line\n"
        self.executable(
            "xclip",
            f"""
            import sys
            from pathlib import Path
            if '-o' in sys.argv:
                sys.stdout.write({value!r})
            else:
                Path({str(copied)!r}).write_bytes(sys.stdin.buffer.read())
            """,
        )
        self.executable(
            "rofi",
            """
            import sys
            rows = sys.stdin.read().splitlines()
            if '-dmenu' in sys.argv:
                print(next((row for row in rows if row.startswith('📋 ')), rows[0]))
            """,
        )
        env = self.env(
            ROFI_CLIPBOARD_HISTORY="1",
            ROFI_CLIPBOARD_HISTORY_FILE=str(history),
        )
        result = self.run_script(ROFI / "clipboard.sh", env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(copied.read_text(encoding="utf-8"), value)
        self.assertEqual(stat.S_IMODE(history.stat().st_mode), 0o600)
        entries = json.loads(history.read_text(encoding="utf-8"))
        self.assertEqual(base64.b64decode(entries[0]), value.encode())

        wayland_copied = self.tmp / "wayland-copied"
        self.executable(
            "wl-paste",
            f"""
            import sys
            sys.stdout.write({value!r})
            """,
        )
        self.executable(
            "wl-copy",
            f"""
            from pathlib import Path
            Path({str(wayland_copied)!r}).write_bytes(__import__('sys').stdin.buffer.read())
            """,
        )
        wayland_env = self.env(
            ROFI_CLIPBOARD_HISTORY="1",
            ROFI_CLIPBOARD_HISTORY_FILE=str(history),
            WAYLAND_DISPLAY="wayland-test",
        )
        result = self.run_script(ROFI / "clipboard.sh", env=wayland_env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(wayland_copied.read_text(encoding="utf-8"), value)

        self.executable(
            "wl-copy",
            """
            raise SystemExit(23)
            """,
        )
        result = self.run_script(ROFI / "clipboard.sh", env=wayland_env)
        self.assertNotEqual(result.returncode, 0)

        # Opening the UI without explicit retention does not read the clipboard.
        marker = self.tmp / "read-marker"
        self.executable(
            "xclip",
            f"""
            from pathlib import Path
            Path({str(marker)!r}).write_text('read', encoding='utf-8')
            """,
        )
        no_opt_in = self.tmp / "no-opt-in.json"
        result = self.run_script(
            ROFI / "clipboard.sh",
            env=self.env(ROFI_CLIPBOARD_HISTORY_FILE=str(no_opt_in)),
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(marker.exists())
        self.assertFalse(no_opt_in.exists())

    def test_clipboard_concurrent_writes_are_lossless(self) -> None:
        history = self.tmp / "cache" / "history.json"
        helper = ROFI / "clipboard-history.py"
        values = [f"entry-{index}\nline-{index}".encode() for index in range(12)]

        def add(value: bytes) -> None:
            subprocess.run(
                [sys.executable, str(helper), "add", str(history)],
                input=value,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=True,
            )

        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
            list(pool.map(add, values))

        encoded = json.loads(history.read_text(encoding="utf-8"))
        self.assertEqual({base64.b64decode(item) for item in encoded}, set(values))
        self.assertEqual(stat.S_IMODE(history.stat().st_mode), 0o600)

    def test_clipboard_rejects_symlink_history(self) -> None:
        helper = ROFI / "clipboard-history.py"
        target = self.tmp / "target.json"
        target.write_text("[]", encoding="utf-8")
        history = self.tmp / "history.json"
        history.symlink_to(target)
        result = subprocess.run(
            [sys.executable, str(helper), "add", str(history)],
            input=b"secret",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(target.read_text(encoding="utf-8"), "[]")

    def test_wifi_literal_ssid_and_secret_not_in_argv(self) -> None:
        log = self.tmp / "nmcli"
        ssid = "Cafe:5G"
        password = "correct horse battery staple"
        self.executable(
            "nmcli",
            f"""
            import sys
            from pathlib import Path
            args = sys.argv[1:]
            if 'list' in args:
                print(r'Cafe\\:5G:WPA2:80')
                raise SystemExit(0)
            secret = sys.stdin.read()
            Path({str(log)!r}).write_text('ARGS=' + repr(args) + '\\nSECRET=' + repr(secret), encoding='utf-8')
            """,
        )
        self.executable(
            "rofi",
            f"""
            import sys
            rows = sys.stdin.read().splitlines()
            if '-password' in sys.argv:
                print({password!r})
            elif '-dmenu' in sys.argv:
                print(next(row for row in rows if row.startswith('🔒 ')))
            """,
        )

        result = self.run_script(ROFI / "wifi-menu.sh", env=self.env())
        self.assertEqual(result.returncode, 0, result.stderr)
        invocation = log.read_text(encoding="utf-8")
        self.assertIn(repr(ssid), invocation)
        self.assertNotIn(password, invocation.split("ARGS=", 1)[1].split("\n", 1)[0])
        self.assertIn(repr(password + "\n"), invocation)


if __name__ == "__main__":
    unittest.main()
