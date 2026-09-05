import json
import os
import stat
import subprocess
import tempfile
import textwrap
import time
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HELPERS = ROOT / "tmux" / ".config" / "tmux" / "scripts"
SIDEBAR = HELPERS / "codex-sidebar"
HOOK = HELPERS / "codex-tmux-sidebar-hook"
LOCK = HELPERS / "codex-tmux-sidebar-lock"


class SidebarStateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.state = self.root / "state with spaces"
        self.worktree = self.root / "work tree with spaces"
        self.worktree.mkdir()
        self.log = self.root / "events.log"
        self._write_executable(
            "codex",
            """#!/usr/bin/env bash
            printf 'codex %s\\n' "$*" >> "$SIDEBAR_TEST_LOG"
            if [[ -n "${SIDEBAR_CODEX_SLEEP:-}" ]]; then sleep "$SIDEBAR_CODEX_SLEEP"; fi
            """,
        )
        self._write_executable(
            "tmux",
            """#!/usr/bin/env python3
            import os, sys
            args = sys.argv[1:]
            panes = set(filter(None, os.environ.get('TMUX_FAKE_PANES', '').split(',')))
            target = ''
            if '-t' in args:
                target = args[args.index('-t') + 1]
            if args[:1] == ['display-message']:
                if target and target not in panes:
                    raise SystemExit(1)
                if '-p' in args:
                    fmt = args[-1]
                    if fmt == '#{pane_id}': print(target)
                    elif fmt == '#{session_name}': print('test-session')
                raise SystemExit(0)
            if args[:1] == ['show-options']:
                option = args[-1]
                if option == '@pane_agent': print(os.environ.get('TMUX_FAKE_AGENT', ''))
                elif option == '@pane_session_id': print(os.environ.get('TMUX_FAKE_SESSION', ''))
                raise SystemExit(0)
            raise SystemExit(0)
            """,
        )
        self.plugin = self.root / "plugin hook.sh"
        self._write_executable(
            self.plugin.name,
            """#!/usr/bin/env bash
            printf 'pane=%s event=%s agent=%s\\n' "${TMUX_PANE:-}" "$2" "$1" >> "$SIDEBAR_TEST_LOG"
            cat >> "$SIDEBAR_TEST_LOG"
            """,
            directory=self.plugin.parent,
        )
        self.env = os.environ.copy()
        self.env.update(
            {
                "PATH": f"{self.bin}:{self.env['PATH']}",
                "HOME": str(self.root / "home"),
                "XDG_STATE_HOME": str(self.root / "xdg-state"),
                "CODEX_TMUX_SIDEBAR_STATE_DIR": str(self.state),
                "SIDEBAR_TEST_LOG": str(self.log),
                "TMUX": "fake",
                "TMUX_PANE": "%1",
                "TMUX_FAKE_PANES": "%1",
                "TMUX_AGENT_SIDEBAR_HOOK": str(self.plugin),
            }
        )
        (self.root / "home").mkdir()

    def tearDown(self):
        self.tmp.cleanup()

    def _write_executable(self, name, body, directory=None):
        directory = directory or self.bin
        path = directory / name
        content = textwrap.dedent(body)
        if content.startswith("#!\n") or content.startswith("#!"):
            shebang, _, rest = content.partition("\n")
            content = shebang + "\n" + textwrap.dedent(rest)
        path.write_text(content)
        path.chmod(path.stat().st_mode | stat.S_IXUSR)
        return path

    def _run(self, path, *args, env=None, cwd=None):
        return subprocess.run(
            [str(path), *args],
            cwd=cwd,
            env=env or self.env,
            text=True,
            capture_output=True,
        )

    def _state(self, name):
        return json.loads((self.state / name).read_text())

    def test_concurrent_first_writers_preserve_both_panes_and_spaces(self):
        first = subprocess.Popen(
            [str(SIDEBAR), "--first"], cwd=self.worktree, env=self.env
        )
        second = subprocess.Popen(
            [str(SIDEBAR), "--second"], cwd=self.worktree, env=self.env
        )
        self.assertEqual(first.wait(timeout=10), 0)
        self.assertEqual(second.wait(timeout=10), 0)
        pending = self._state("pending.json")
        self.assertEqual(len(pending), 2)
        self.assertTrue(all(row["cwd"] == str(self.worktree.resolve()) for row in pending))
        self.assertEqual(self._state("sessions.json"), {})

    def test_interrupted_owner_is_recovered(self):
        command = (
            f"state_dir={self._quote(str(self.state))}; "
            f"lock_dir=$state_dir/lock.d; . {self._quote(str(LOCK))}; "
            "codex_tmux_sidebar_acquire_lock; kill -STOP $$"
        )
        owner = subprocess.Popen(["bash", "-c", command], env=self.env)
        for _ in range(100):
            if (self.state / "lock.d" / "owner").exists():
                break
            time.sleep(0.01)
        self.assertTrue((self.state / "lock.d" / "owner").exists())
        owner.kill()
        owner.wait(timeout=5)
        recovered = self._run(SIDEBAR, "after-interruption", cwd=self.worktree)
        self.assertEqual(recovered.returncode, 0, recovered.stderr)
        self.assertFalse((self.state / "lock.d").exists())

    def test_stale_lock_with_dead_pid_is_recovered(self):
        lock = self.state / "lock.d"
        lock.mkdir(parents=True)
        (lock / "owner").write_text(
            "pid=999999999\nhost=%s\nstart=unknown\ntoken=stale\n" % self._hostname()
        )
        result = self._run(SIDEBAR, "stale", cwd=self.worktree)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(lock.exists())

    def test_malformed_state_is_refused_without_launching_codex(self):
        self.state.mkdir(parents=True)
        (self.state / "pending.json").write_text("{not json\n")
        (self.state / "sessions.json").write_text("{}\n")
        result = self._run(SIDEBAR, "must-fail", cwd=self.worktree)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("malformed pending state", result.stderr)
        self.assertFalse(self.log.exists())
        self.assertEqual((self.state / "pending.json").read_text(), "{not json\n")

    def test_hook_cleans_dead_session_and_preserves_live_association(self):
        self.state.mkdir(parents=True)
        (self.state / "pending.json").write_text("[]\n")
        (self.state / "sessions.json").write_text(
            json.dumps(
                {"dead": {"pane": "%dead", "cwd": str(self.worktree), "updated_at": 1}}
            )
            + "\n"
        )
        result = subprocess.run(
            [str(HOOK), "codex", "session-start"],
            input=json.dumps({"session_id": "dead", "cwd": str(self.worktree)}),
            text=True,
            env=self.env,
            capture_output=True,
            cwd=self.worktree,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self._state("sessions.json"), {})
        self.assertIn("pane=%1 event=session-start", self.log.read_text())

    def test_hook_claims_pending_pane_for_same_cwd_with_spaces(self):
        launch = self._run(SIDEBAR, "launch", cwd=self.worktree)
        self.assertEqual(launch.returncode, 0, launch.stderr)
        hook_input = json.dumps({"session_id": "session-1", "cwd": str(self.worktree)})
        result = subprocess.run(
            [str(HOOK), "codex", "session-start"],
            input=hook_input,
            text=True,
            env=self.env,
            capture_output=True,
            cwd=self.worktree,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self._state("pending.json"), [])
        self.assertEqual(self._state("sessions.json")["session-1"]["pane"], "%1")
        self.assertIn("pane=%1 event=session-start", self.log.read_text())

    def test_hook_matches_physical_launcher_cwd_through_symlink(self):
        alias = self.root / "logical work tree alias"
        alias.symlink_to(self.worktree, target_is_directory=True)
        launch = self._run(SIDEBAR, "launch", cwd=alias)
        self.assertEqual(launch.returncode, 0, launch.stderr)
        pending = self._state("pending.json")
        self.assertEqual(pending[0]["cwd"], str(self.worktree.resolve()))

        result = subprocess.run(
            [str(HOOK), "codex", "session-start"],
            input=json.dumps({"session_id": "session-alias", "cwd": str(alias)}),
            text=True,
            env=self.env,
            capture_output=True,
            cwd=alias,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self._state("pending.json"), [])
        self.assertEqual(
            self._state("sessions.json")["session-alias"]["cwd"],
            str(self.worktree.resolve()),
        )
        self.assertEqual(self._state("sessions.json")["session-alias"]["pane"], "%1")
        self.assertIn("pane=%1 event=session-start", self.log.read_text())

    def test_hook_skips_inaccessible_event_cwd_without_consuming_pending(self):
        launch = self._run(SIDEBAR, "launch", cwd=self.worktree)
        self.assertEqual(launch.returncode, 0, launch.stderr)
        inaccessible = self.root / "missing event cwd"
        result = subprocess.run(
            [str(HOOK), "codex", "session-start"],
            input=json.dumps({"session_id": "session-missing", "cwd": str(inaccessible)}),
            text=True,
            env=self.env,
            capture_output=True,
            cwd=self.worktree,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self._state("pending.json")[0]["cwd"], str(self.worktree.resolve())
        )
        self.assertEqual(self._state("sessions.json"), {})
        self.assertIn("ignoring inaccessible event cwd", result.stderr)

    @staticmethod
    def _quote(value):
        return "'" + value.replace("'", "'\\''") + "'"

    @staticmethod
    def _hostname():
        return subprocess.run(
            ["hostname"], check=True, capture_output=True, text=True
        ).stdout.strip()


if __name__ == "__main__":
    unittest.main()
