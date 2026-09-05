#!/usr/bin/env python3
"""Small, private, concurrency-safe clipboard history store.

The file is a JSON list of base64-encoded byte strings.  Encoding entries keeps
multiline and non-UTF-8 clipboard data lossless while retaining a simple state
format that can be inspected or removed by the owner.
"""

from __future__ import annotations

import base64
import hashlib
import json
import os
import stat
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path

try:
    import fcntl
except ImportError:  # pragma: no cover - supported desktop targets are POSIX
    fcntl = None  # type: ignore[assignment]

MAX_HISTORY = 50


def _die(message: str) -> int:
    print(f"clipboard history: {message}", file=sys.stderr)
    return 1


def _reject_symlink(path: Path) -> None:
    try:
        if stat.S_ISLNK(os.lstat(path).st_mode):
            raise RuntimeError(f"symlink is not allowed: {path}")
    except FileNotFoundError:
        pass


def _private_path(path: Path) -> None:
    parent = path.parent
    if parent.exists():
        if parent.is_symlink() or not parent.is_dir():
            raise RuntimeError(f"history parent is not a directory: {parent}")
    else:
        parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        if parent.is_symlink() or not parent.is_dir():
            raise RuntimeError(f"history parent is not a directory: {parent}")
    _reject_symlink(path)


@contextmanager
def _locked(path: Path):
    _private_path(path)
    lock_path = path.with_name(f".{path.name}.lock")
    _reject_symlink(lock_path)
    fd = os.open(lock_path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        os.fchmod(fd, 0o600)
        if fcntl is None:
            raise RuntimeError("file locking is unavailable on this platform")
        with os.fdopen(fd, "r+") as lock_file:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
            yield
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)
    except BaseException:
        try:
            os.close(fd)
        except OSError:
            pass
        raise


def _read(path: Path) -> list[bytes]:
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    except FileNotFoundError:
        return []
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "rb") as history_file:
            raw = history_file.read().decode("utf-8")
    except UnicodeError as exc:
        raise RuntimeError(f"invalid history file: {path}") from exc
    try:
        values = json.loads(raw)
        if not isinstance(values, list) or not all(isinstance(v, str) for v in values):
            raise ValueError
        return [base64.b64decode(v.encode("ascii"), validate=True) for v in values]
    except (ValueError, UnicodeError, json.JSONDecodeError):
        raise RuntimeError(f"invalid history file: {path}")


def _write(path: Path, entries: list[bytes]) -> None:
    _private_path(path)
    encoded = json.dumps(
        [base64.b64encode(value).decode("ascii") for value in entries],
        ensure_ascii=True,
        separators=(",", ":"),
    ).encode("utf-8")
    fd, temp_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent)
    )
    temp_path = Path(temp_name)
    try:
        os.fchmod(fd, stat.S_IRUSR | stat.S_IWUSR)
        with os.fdopen(fd, "wb") as temp_file:
            temp_file.write(encoded)
            temp_file.flush()
            os.fsync(temp_file.fileno())
        os.replace(temp_path, path)
    finally:
        try:
            temp_path.unlink()
        except FileNotFoundError:
            pass


def _token(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _display(value: bytes) -> str:
    text = value.decode("utf-8", errors="replace")
    text = text.replace("\r", "↵").replace("\n", "↵")
    if len(text) > 60:
        text = text[:60] + "…"
    return text


def add(path: Path) -> int:
    value = sys.stdin.buffer.read()
    if not value:
        return 0
    with _locked(path):
        entries = _read(path)
        entries = [item for item in entries if item != value]
        entries.insert(0, value)
        _write(path, entries[:MAX_HISTORY])
    return 0


def list_entries(path: Path) -> int:
    with _locked(path):
        entries = _read(path)
    for value in entries:
        print(f"{_token(value)}\t{_display(value)}")
    return 0


def get(path: Path, token: str) -> int:
    with _locked(path):
        entries = _read(path)
        for value in entries:
            if _token(value) == token:
                sys.stdout.buffer.write(value)
                return 0
    return _die("the selected entry no longer exists")


def clear(path: Path) -> int:
    with _locked(path):
        _write(path, [])
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        return _die("usage: clipboard-history.py <add|list|get|clear> HISTORY [TOKEN]")
    command, path_text = argv[1], argv[2]
    path = Path(path_text).expanduser()
    try:
        if command == "add":
            return add(path)
        if command == "list":
            return list_entries(path)
        if command == "get" and len(argv) == 4:
            return get(path, argv[3])
        if command == "clear":
            return clear(path)
    except (OSError, RuntimeError) as exc:
        return _die(str(exc))
    return _die("invalid command")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
