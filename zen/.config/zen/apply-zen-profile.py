#!/usr/bin/env python3
"""Apply sanitized Zen Browser profile patches from dotfiles."""

from __future__ import annotations

import argparse
import configparser
import errno
import fcntl
import json
import os
import shutil
import sys
import stat
import tempfile
from contextlib import contextmanager, nullcontext
from pathlib import Path
from typing import Any, Iterator


KEYBOARD_SHORTCUTS_FILE = "zen-keyboard-shortcuts.json"
PATCH_FILE = "zen-keyboard-shortcuts.patch.json"


def load_json(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
    except FileNotFoundError as exc:
        raise SystemExit(f"Missing file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in {path}: {exc}") from exc

    if not isinstance(data, dict):
        raise SystemExit(f"Expected a JSON object in {path}")
    return data


def zen_roots() -> list[Path]:
    if sys.platform == "darwin":
        return [Path.home() / "Library/Application Support/zen"]
    xdg_config_home = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    return [xdg_config_home / "zen", Path.home() / ".zen"]


def find_profile_root() -> Path:
    roots = zen_roots()
    found = list(
        dict.fromkeys(
            root.resolve() for root in roots if (root / "profiles.ini").is_file()
        )
    )
    if len(found) == 1:
        return found[0]
    if found:
        choices = "\n".join(f"  - {root}" for root in found)
        raise SystemExit(
            f"Multiple Zen installations found; pass --profile:\n{choices}"
        )
    searched = "\n".join(f"  - {root}" for root in roots)
    raise SystemExit(f"Could not find Zen profiles.ini. Searched:\n{searched}")


def resolve_profile_path(
    root: Path, profile_path: str, is_relative: bool = True
) -> Path:
    path = Path(profile_path).expanduser()
    if is_relative and not path.is_absolute():
        return root / path
    return path


def has_shortcuts(profile: Path) -> bool:
    return (profile / KEYBOARD_SHORTCUTS_FILE).is_file()


def profiles_with_shortcuts(root: Path) -> list[Path]:
    return sorted(
        {
            path.parent
            for pattern in (
                f"*/{KEYBOARD_SHORTCUTS_FILE}",
                f"Profiles/*/{KEYBOARD_SHORTCUTS_FILE}",
            )
            for path in root.glob(pattern)
        }
    )


def resolve_default_profile(root: Path) -> Path:
    profiles_ini = root / "profiles.ini"
    parser = configparser.RawConfigParser()
    parser.read(profiles_ini)

    install_defaults: list[Path] = []
    profile_defaults: list[Path] = []
    profiles: list[Path] = []
    for section in parser.sections():
        if section.startswith("Install"):
            path = parser.get(section, "Default", fallback="")
            if path:
                install_defaults.append(resolve_profile_path(root, path))
        elif section.startswith("Profile"):
            path = parser.get(section, "Path", fallback="")
            if path:
                profile = resolve_profile_path(
                    root, path, parser.get(section, "IsRelative", fallback="1") == "1"
                )
                profiles.append(profile)
                if parser.get(section, "Default", fallback="0") == "1":
                    profile_defaults.append(profile)

    # Installation defaults take precedence, but never guess between peers.
    for group in (
        install_defaults,
        profile_defaults,
        profiles,
        profiles_with_shortcuts(root),
    ):
        candidates = sorted(
            {profile.resolve() for profile in group if has_shortcuts(profile)}
        )
        if len(candidates) == 1:
            return candidates[0]
        if candidates:
            choices = "\n".join(f"  - {profile}" for profile in candidates)
            raise SystemExit(
                f"Multiple Zen profiles contain {KEYBOARD_SHORTCUTS_FILE}; pass --profile:\n{choices}"
            )
    raise SystemExit(
        f"No Zen profile with {KEYBOARD_SHORTCUTS_FILE} found under {root}"
    )


def selected_fields(shortcut: dict[str, Any]) -> dict[str, Any]:
    return {
        field: shortcut[field]
        for field in ("key", "keycode", "modifiers", "disabled")
        if field in shortcut
    }


def patch_shortcuts(
    config: dict[str, Any], patch: dict[str, Any]
) -> list[tuple[str, str, dict[str, Any], dict[str, Any]]]:
    shortcuts = config.get("shortcuts")
    if not isinstance(shortcuts, list):
        raise SystemExit(
            "Expected 'shortcuts' to be a list in Zen keyboard shortcuts JSON"
        )

    by_id = {
        shortcut.get("id"): shortcut
        for shortcut in shortcuts
        if isinstance(shortcut, dict) and isinstance(shortcut.get("id"), str)
    }

    requested = patch.get("shortcuts")
    if not isinstance(requested, list):
        raise SystemExit(f"Expected 'shortcuts' to be a list in {PATCH_FILE}")

    missing = [entry.get("id") for entry in requested if entry.get("id") not in by_id]
    if missing:
        missing_text = "\n".join(f"  - {item}" for item in missing)
        raise SystemExit(f"Zen shortcut IDs were not found:\n{missing_text}")

    changes: list[tuple[str, str, dict[str, Any], dict[str, Any]]] = []
    patchable_fields = ("key", "keycode", "modifiers", "disabled")

    for entry in requested:
        shortcut_id = entry["id"]
        shortcut = by_id[shortcut_id]
        before = selected_fields(shortcut)

        for field in patchable_fields:
            if field in entry:
                shortcut[field] = entry[field]

        after = selected_fields(shortcut)
        action = str(shortcut.get("action") or "")
        changes.append((shortcut_id, action, before, after))

    return changes


@contextmanager
def profile_lock(profile: Path) -> Iterator[None]:
    # Firefox/Zen uses a POSIX whole-file record lock on Unix, not flock().
    # Holding the same lock excludes both the browser and another patcher.
    lock_path = profile / ".parentlock"
    if any(
        (profile / name).is_symlink() for name in (".parentlock", "lock", "parent.lock")
    ):
        raise SystemExit(
            "Close Zen and resolve the existing legacy profile lock before applying patches."
        )
    fd = os.open(lock_path, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    try:
        try:
            fcntl.lockf(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as exc:
            if exc.errno in (errno.EACCES, errno.EAGAIN):
                raise SystemExit(
                    "Zen or another patcher is using this profile; close it before applying."
                ) from exc
            raise SystemExit(f"Cannot safely lock the Zen profile: {exc}") from exc
        yield
    finally:
        os.close(fd)


def backup_file(path: Path) -> Path:
    fd, name = tempfile.mkstemp(
        prefix=f"{path.name}.backup-before-dotfiles-", dir=path.parent
    )
    backup_path = Path(name)
    try:
        with os.fdopen(fd, "wb") as target, path.open("rb") as source:
            shutil.copyfileobj(source, target)
            target.flush()
            os.fsync(target.fileno())
    except BaseException:
        backup_path.unlink(missing_ok=True)
        raise
    return backup_path


def write_json(path: Path, data: dict[str, Any]) -> None:
    mode = stat.S_IMODE(path.stat().st_mode)
    fd, name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    tmp_path = Path(name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            os.fchmod(handle.fileno(), mode)
            json.dump(data, handle, indent=2, ensure_ascii=False)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp_path, path)
    finally:
        tmp_path.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--profile", type=Path, help="Explicit Zen profile directory to patch"
    )
    parser.add_argument("--patch", type=Path, help="Shortcut patch file")
    parser.add_argument(
        "--dry-run", action="store_true", help="Preview changes without writing"
    )
    args = parser.parse_args()

    dotfiles_dir = Path(__file__).resolve().parent
    patch_path = (args.patch or dotfiles_dir / PATCH_FILE).expanduser()
    profile = (
        args.profile.expanduser()
        if args.profile
        else resolve_default_profile(find_profile_root())
    )
    shortcuts_path = profile / KEYBOARD_SHORTCUTS_FILE

    patch = load_json(patch_path)
    with nullcontext() if args.dry_run else profile_lock(profile):
        config = load_json(shortcuts_path)
        changes = patch_shortcuts(config, patch)

        print(f"Zen profile: {profile}")
        print(f"Patch file: {patch_path}")
        for shortcut_id, action, before, after in changes:
            status = "unchanged" if before == after else "update"
            print(f"{status}: {shortcut_id} ({action})")
            print(f"  before: {json.dumps(before, sort_keys=True)}")
            print(f"  after:  {json.dumps(after, sort_keys=True)}")

        if args.dry_run:
            print("Dry run only; no files changed.")
            return 0
        if all(before == after for _, _, before, after in changes):
            print("Shortcuts already match; no files changed.")
            return 0

        backup_path = backup_file(shortcuts_path)
        write_json(shortcuts_path, config)

    print(f"Backup written: {backup_path}")
    print("Shortcuts updated. You can now start Zen.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
