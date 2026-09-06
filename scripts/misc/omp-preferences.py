#!/usr/bin/env python3
"""Preview or restore the public, privacy-safe OMP preferences template.

The template is intentionally a small closed allowlist.  It is not an export of
an installed OMP configuration: model/provider choices, credentials, rules,
agent definitions, sessions, and other runtime state never enter this path.
"""

from __future__ import annotations

import argparse
import copy
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
from typing import Any, Iterator


TEMPLATE_PATH = Path(__file__).resolve().parents[1] / "installs" / "omp-preferences.yml"
DEFAULT_CONFIG_PATH = Path.home() / ".omp" / "agent" / "config.yml"

# Keep this list explicit and boring.  Only values with stable, closed choices
# are exported; runtime strings (themes, endpoints, model IDs, and prompts) are
# deliberately not part of the public template.
FIELD_SPECS: dict[str, tuple[str, frozenset[str] | None]] = {
    "symbolPreset": ("enum", frozenset({"unicode", "nerd", "ascii"})),
    "composer.shape": (
        "enum",
        frozenset({"box", "claude", "pi", "borderless", "rule", "field", "rail"}),
    ),
    "statusLine.preset": (
        "enum",
        frozenset({"default", "minimal", "compact", "full", "nerd", "ascii", "custom"}),
    ),
    "statusLine.separator": (
        "enum",
        frozenset({"powerline", "powerline-thin", "slash", "pipe", "block", "none", "ascii"}),
    ),
    "statusLine.contextLine": (
        "enum",
        frozenset({"off", "percentage", "annotated", "embedded"}),
    ),
    "tui.resizeScrollback": (
        "enum",
        frozenset({"append", "rebuild", "preserve"}),
    ),
    "display.showTokenUsage": ("boolean", None),
    "display.cacheMissMarker": ("boolean", None),
}
PREFIXES = frozenset(
    ".".join(path.split(".")[:index])
    for path in FIELD_SPECS
    for index in range(1, len(path.split(".")))
)


class ValidationError(Exception):
    """An expected, safe-to-report validation failure."""


def _bun_executable() -> str:
    executable = shutil.which("bun")
    if executable is None:
        raise ValidationError("Bun is required to parse OMP YAML (put bun on PATH).")
    return executable


def _parse_yaml(path: Path, label: str) -> Any:
    """Parse YAML through Bun's YAML implementation, never a line regex."""
    try:
        metadata = path.lstat()
    except FileNotFoundError as exc:
        if label == "template":
            raise ValidationError("The OMP preferences template is unavailable.") from exc
        raise ValidationError("The OMP configuration is unavailable.") from exc
    except OSError as exc:
        raise ValidationError(f"Cannot inspect the {label} file safely.") from exc
    if not stat.S_ISREG(metadata.st_mode):
        raise ValidationError(f"The {label} file must be a regular file.")

    try:
        source = path.read_bytes()
    except OSError as exc:
        raise ValidationError(f"Cannot read the {label} file safely.") from exc

    # Bun's parser is part of the OMP runtime and avoids adding a YAML parser
    # dependency to this small Python utility.  Parse failures are intentionally
    # reduced to a category-only message so malformed input cannot echo values.
    script = (
        "const fs = require('node:fs');"
        "try {"
        "  const value = Bun.YAML.parse(fs.readFileSync(0, 'utf8'));"
        "  process.stdout.write(JSON.stringify(value));"
        "} catch (_) { process.exit(1); }"
    )
    try:
        result = subprocess.run(
            [_bun_executable(), "-e", script],
            input=source,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            check=False,
        )
    except OSError as exc:
        raise ValidationError("Cannot run Bun to parse OMP YAML.") from exc
    if result.returncode != 0:
        raise ValidationError(f"The {label} is not valid YAML.")
    try:
        return json.loads(result.stdout)
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        raise ValidationError(f"The {label} has an unsupported YAML value.") from exc


def _validate_scalar(path: str, value: Any) -> None:
    kind, choices = FIELD_SPECS[path]
    if kind == "boolean":
        if type(value) is not bool:
            raise ValidationError("The template contains an incompatible preference value.")
        return
    if kind == "enum":
        if type(value) is not str or value not in choices:
            raise ValidationError("The template contains an unsupported preference value.")
        return
    raise AssertionError(f"unhandled field kind: {kind}")


def _walk_template(value: Any, prefix: str = "") -> Iterator[tuple[str, Any]]:
    if not isinstance(value, dict):
        raise ValidationError("The template root must be a mapping.")
    for key, child in value.items():
        if not isinstance(key, str):
            raise ValidationError("The template contains an invalid field name.")
        path = f"{prefix}.{key}" if prefix else key
        if path in FIELD_SPECS:
            _validate_scalar(path, child)
            yield path, child
        elif path in PREFIXES:
            if not isinstance(child, dict):
                raise ValidationError("The template contains an unsupported preference shape.")
            yield from _walk_template(child, path)
        else:
            raise ValidationError("The template contains an unapproved field.")


def validate_template(template: Any) -> list[tuple[str, Any]]:
    leaves = list(_walk_template(template))
    if not leaves:
        raise ValidationError("The template must contain at least one approved preference.")
    return leaves


def _value_at(root: dict[str, Any], segments: list[str]) -> tuple[bool, Any]:
    current: Any = root
    for segment in segments:
        if not isinstance(current, dict) or segment not in current:
            return False, None
        current = current[segment]
    return True, current


def validate_target_shape(target: Any, leaves: list[tuple[str, Any]]) -> dict[str, Any]:
    if not isinstance(target, dict):
        raise ValidationError("The OMP configuration root must be a mapping.")

    # Unrelated target fields are intentionally not inspected or rejected.  For
    # each field we restore, however, existing ancestors and values must have a
    # supported shape before any candidate write is prepared.
    for path, _ in leaves:
        segments = path.split(".")
        current: Any = target
        for segment in segments[:-1]:
            if not isinstance(current, dict) or segment not in current:
                current = None
                break
            current = current[segment]
            if not isinstance(current, dict):
                raise ValidationError("The OMP configuration has an unsupported target shape.")
        present, existing = _value_at(target, segments)
        if present:
            _validate_scalar(path, existing)
    return target


def _set_value(root: dict[str, Any], path: str, value: Any) -> None:
    segments = path.split(".")
    current = root
    for segment in segments[:-1]:
        child = current.get(segment)
        if child is None:
            child = {}
            current[segment] = child
        if not isinstance(child, dict):
            raise ValidationError("The OMP configuration has an unsupported target shape.")
        current = child
    current[segments[-1]] = copy.deepcopy(value)


def _merged_config(target: dict[str, Any], leaves: list[tuple[str, Any]]) -> tuple[dict[str, Any], list[str]]:
    merged = copy.deepcopy(target)
    changed: list[str] = []
    for path, value in leaves:
        present, before = _value_at(target, path.split("."))
        if not present or before != value:
            changed.append(path)
        _set_value(merged, path, value)
    return merged, changed


def _stringify_yaml(value: dict[str, Any]) -> bytes:
    script = (
        "const fs = require('node:fs');"
        "try {"
        "  const value = JSON.parse(fs.readFileSync(0, 'utf8'));"
        "  process.stdout.write(Bun.YAML.stringify(value, null, 2));"
        "} catch (_) { process.exit(1); }"
    )
    try:
        result = subprocess.run(
            [_bun_executable(), "-e", script],
            input=json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8"),
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            check=False,
        )
    except OSError as exc:
        raise ValidationError("Cannot run Bun to serialize OMP YAML.") from exc
    if result.returncode != 0:
        raise ValidationError("The merged OMP configuration could not be serialized safely.")
    return result.stdout


def _write_atomically(path: Path, content: bytes, mode: int) -> None:
    try:
        path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        fd, temporary_name = tempfile.mkstemp(
            prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
        )
    except OSError as exc:
        raise ValidationError("Cannot prepare the OMP configuration for writing.") from exc

    temporary = Path(temporary_name)
    try:
        with os.fdopen(fd, "wb") as handle:
            os.fchmod(handle.fileno(), mode)
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        # os.replace replaces a destination symlink itself rather than following
        # it.  The preflight lstat check in main rejects one before this point.
        os.replace(temporary, path)
    except OSError as exc:
        raise ValidationError("Cannot atomically write the OMP configuration.") from exc
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass
        except OSError:
            pass


def _target_metadata(path: Path) -> tuple[bool, int]:
    try:
        metadata = path.lstat()
    except FileNotFoundError:
        return False, 0o600
    except OSError as exc:
        raise ValidationError("Cannot inspect the OMP configuration safely.") from exc
    if stat.S_ISLNK(metadata.st_mode):
        raise ValidationError("The OMP configuration must not be a symlink.")
    if not stat.S_ISREG(metadata.st_mode):
        raise ValidationError("The OMP configuration must be a regular file.")
    return True, stat.S_IMODE(metadata.st_mode)


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Preview or restore the curated, privacy-safe OMP preferences."
    )
    action = parser.add_mutually_exclusive_group()
    action.add_argument(
        "--apply", action="store_true", help="Apply approved preferences atomically."
    )
    action.add_argument(
        "--dry-run", action="store_true", help="Preview only (the default)."
    )
    parser.add_argument(
        "--config", type=Path, help="OMP config.yml target (default: ~/.omp/agent/config.yml)."
    )
    parser.add_argument(
        "--template", type=Path, help="Preference template (default: repository template)."
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    template_path = (args.template or TEMPLATE_PATH).expanduser()
    config_path = (args.config or DEFAULT_CONFIG_PATH).expanduser()

    try:
        # Validate the public source before opening or preparing any destination.
        template = _parse_yaml(template_path, "template")
        leaves = validate_template(template)
        target_exists, target_mode = _target_metadata(config_path)
        target = _parse_yaml(config_path, "configuration") if target_exists else {}
        validate_target_shape(target, leaves)
        merged, changed = _merged_config(target, leaves)
        print(f"Validated {len(leaves)} approved OMP preference(s).")
        print(f"{len(changed)} preference(s) would change.")
        for path in changed:
            print(f"  {path}: update")

        if not args.apply:
            print("Dry run only; no files changed. Use --apply to restore them.")
            return 0
        if not changed:
            print("Preferences already match; no files changed.")
            return 0

        serialized = _stringify_yaml(merged)
        _write_atomically(config_path, serialized, target_mode)
        print(f"Applied {len(changed)} OMP preference(s) atomically.")
        return 0
    except ValidationError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
