## Zen Browser dotfiles

This directory tracks only sanitized, reproducible Zen Browser helper config.
It intentionally does not track the live Zen profile, extension storage, cookies,
sync data, extension UUIDs, or site-specific private exclusions.

### Split shortcuts

Zen is an optional package. Preview and link it from the repository:

```bash
./install.sh sync --dry-run zen
./install.sh sync zen
```

The split shortcut patch sets the Zen split commands to:

| Action | Shortcut |
| --- | --- |
| Split horizontal | `Ctrl+Cmd+H` |
| Split vertical | `Ctrl+Cmd+V` |
| Split grid | `Ctrl+Cmd+G` |
| Unsplit | `Ctrl+Cmd+U` |
| New empty split | `Ctrl+Cmd+S` |

Preview changes first (Python 3, no additional Python packages required):

```bash
python3 "${XDG_CONFIG_HOME:-$HOME/.config}/zen/apply-zen-profile.py" --dry-run
```

Close Zen before applying:

```bash
python3 "${XDG_CONFIG_HOME:-$HOME/.config}/zen/apply-zen-profile.py"
```

The script reads installation/profile defaults from `profiles.ini`. If discovery
is ambiguous, pass `--profile "/absolute/path/to/profile"` rather than allowing
the script to guess. macOS discovery uses `~/Library/Application Support/zen`;
Linux checks `$XDG_CONFIG_HOME/zen` (default `~/.config/zen`) and `~/.zen`.

Applying holds the same POSIX record lock on `.parentlock` that Firefox/Zen uses
on Linux and macOS. An active browser or another patcher causes a nonzero exit
without changing the shortcuts. Legacy symlink locks are refused, not removed.
Resolve a stale legacy lock only after confirming that no browser uses the profile.

Each changed version gets a uniquely named, private
`zen-keyboard-shortcuts.json.backup-before-dotfiles-*` backup. The new JSON is
written through a unique temporary file and atomically replaces the original,
preserving its permissions and unrelated fields. An unchanged patch creates no
backup and does not rewrite the JSON; `--dry-run` creates no profile or lock files.

To restore, close Zen and copy the desired backup over
`zen-keyboard-shortcuts.json` in that profile. Backups are retained until you
choose to remove them.

### Tridactyl

The Tridactyl config keeps the useful custom bindings separate from browser
profile storage:

```tridactyl
source ~/.config/zen/tridactylrc
```

If Tridactyl cannot read local files yet, install its native messenger from
Tridactyl command mode first:

```tridactyl
nativeinstall
```

Then run the `source` command again.

### Extensions

See `extensions.md` for the curated extension list. Install extensions manually
from official sources instead of committing Zen's live `extensions.json`.
