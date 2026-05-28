#!/usr/bin/env python3
"""Apply sanitized Zen Browser profile patches from dotfiles."""

from __future__ import annotations

import argparse
import configparser
import json
import os
import shutil
import sys
from datetime import datetime
from pathlib import Path
from typing import Any


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
    roots = [Path.home() / "Library/Application Support/zen"]

    xdg_config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    roots.extend(
        [
            xdg_config_home / "zen",
            Path.home() / ".zen",
        ]
    )
    return roots


def find_profile_root() -> Path:
    for root in zen_roots():
        if (root / "profiles.ini").is_file():
            return root

    searched = "\n".join(f"  - {root}" for root in zen_roots())
    raise SystemExit(f"Could not find Zen profiles.ini. Searched:\n{searched}")


def resolve_profile_path(root: Path, profile_path: str, is_relative: bool = True) -> Path:
    path = Path(profile_path).expanduser()
    if is_relative and not path.is_absolute():
        return root / path
    return path


def has_shortcuts(profile: Path) -> bool:
    return (profile / KEYBOARD_SHORTCUTS_FILE).is_file()


def profiles_with_shortcuts(root: Path) -> list[Path]:
    return sorted({path.parent for path in root.glob(f"Profiles/*/{KEYBOARD_SHORTCUTS_FILE}")})


def resolve_default_profile(root: Path) -> Path:
    profiles_ini = root / "profiles.ini"
    parser = configparser.RawConfigParser()
    parser.read(profiles_ini)

    profiles = [section for section in parser.sections() if section.startswith("Profile")]
    if not profiles:
        raise SystemExit(f"No profiles found in {profiles_ini}")

    preferred: list[Path] = []

    for section in parser.sections():
        if section.startswith("Install"):
            install_default = parser.get(section, "Default", fallback="")
            if install_default:
                preferred.append(resolve_profile_path(root, install_default))

    for section in profiles:
        profile_path = parser.get(section, "Path", fallback="")
        if not profile_path:
            continue

        is_relative = parser.get(section, "IsRelative", fallback="1") == "1"
        profile = resolve_profile_path(root, profile_path, is_relative)
        if parser.get(section, "Default", fallback="0") == "1":
            preferred.append(profile)

    for section in profiles:
        profile_path = parser.get(section, "Path", fallback="")
        if not profile_path:
            continue

        is_relative = parser.get(section, "IsRelative", fallback="1") == "1"
        preferred.append(resolve_profile_path(root, profile_path, is_relative))

    seen: set[Path] = set()
    for profile in preferred:
        if profile in seen:
            continue
        seen.add(profile)
        if has_shortcuts(profile):
            return profile

    candidates = profiles_with_shortcuts(root)
    if len(candidates) == 1:
        return candidates[0]
    if candidates:
        choices = "\n".join(f"  - {path}" for path in candidates)
        raise SystemExit(f"Multiple Zen profiles contain {KEYBOARD_SHORTCUTS_FILE}; pass --profile:\n{choices}")

    raise SystemExit(f"No Zen profile with {KEYBOARD_SHORTCUTS_FILE} found under {root}")


def selected_fields(shortcut: dict[str, Any]) -> dict[str, Any]:
    return {
        "key": shortcut.get("key"),
        "keycode": shortcut.get("keycode"),
        "modifiers": shortcut.get("modifiers"),
        "disabled": shortcut.get("disabled"),
    }


def patch_shortcuts(config: dict[str, Any], patch: dict[str, Any]) -> list[tuple[str, str, dict[str, Any], dict[str, Any]]]:
    shortcuts = config.get("shortcuts")
    if not isinstance(shortcuts, list):
        raise SystemExit("Expected 'shortcuts' to be a list in Zen keyboard shortcuts JSON")

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


def write_json(path: Path, data: dict[str, Any]) -> None:
    tmp_path = path.with_name(f"{path.name}.tmp")
    with tmp_path.open("w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    os.replace(tmp_path, path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", type=Path, help="Explicit Zen profile directory to patch")
    parser.add_argument("--patch", type=Path, help="Shortcut patch file")
    parser.add_argument("--dry-run", action="store_true", help="Preview changes without writing")
    args = parser.parse_args()

    dotfiles_dir = Path(__file__).resolve().parent
    patch_path = (args.patch or dotfiles_dir / PATCH_FILE).expanduser()
    profile = args.profile.expanduser() if args.profile else resolve_default_profile(find_profile_root())
    shortcuts_path = profile / KEYBOARD_SHORTCUTS_FILE

    config = load_json(shortcuts_path)
    patch = load_json(patch_path)
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

    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    backup_path = shortcuts_path.with_name(f"{shortcuts_path.name}.backup-before-dotfiles-{timestamp}")
    shutil.copy2(shortcuts_path, backup_path)
    write_json(shortcuts_path, config)

    print(f"Backup written: {backup_path}")
    print("Zen may need to be restarted before the shortcuts are visible.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
