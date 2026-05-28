## Zen Browser dotfiles

This directory tracks only sanitized, reproducible Zen Browser helper config.
It intentionally does not track the live Zen profile, extension storage, cookies,
sync data, extension UUIDs, or site-specific private exclusions.

### Split shortcuts

This package is not applied by the main install script. To link it into
`~/.config/zen`, run this explicitly from the dotfiles repo:

```bash
stow -S --no-folding -t "$HOME" zen
```

The split shortcut patch sets the Zen split commands to:

| Action | Shortcut |
| --- | --- |
| Split horizontal | `Ctrl+Cmd+H` |
| Split vertical | `Ctrl+Cmd+V` |
| Split grid | `Ctrl+Cmd+G` |
| Unsplit | `Ctrl+Cmd+U` |
| New empty split | `Ctrl+Cmd+S` |

Apply it with:

```bash
uv run --python 3.13 --no-sync python ~/.config/zen/apply-zen-profile.py
```

Use `--dry-run` first to preview the exact shortcut entries that would change:

```bash
uv run --python 3.13 --no-sync python ~/.config/zen/apply-zen-profile.py --dry-run
```

The script locates the active/default Zen profile from `profiles.ini`, backs up
the existing `zen-keyboard-shortcuts.json`, and patches only these shortcut IDs.

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
