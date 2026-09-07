# Bash Configuration

This directory contains the Bash startup entrypoints and Bash-only helpers. Portable environment, aliases, and functions live in the dedicated `shell` package so Bash and Zsh share one implementation.

## Structure

- `.bashrc`: Main interactive and non-interactive Bash entrypoint
- `.bash_profile`: Sources `.bashrc` for login shells
- `.config/bash/.bash_aliases`: Bash-specific aliases
- `.config/bash/.bash_functions`: Bash-specific functions
- `../shell/.config/shell/`: Shared environment, aliases, and safe utility functions

## Features

- Optional ble.sh and fzf integrations when already installed
- Starship prompt when the command is available; no startup installation
- Shared XDG-aware environment and utility functions
- Optional host-local settings from `~/.bashrc.local` and `$XDG_CONFIG_HOME/shell/local`

## Usage

The deployment script stows the `shell` package with the selected shell packages. For manual installation:

```bash
stow -t "$HOME" shell bash
```

### ble.sh on macOS

Install the build prerequisite, then use the dotfiles dependency installer:

```bash
brew install gawk
./install.sh deps --no-sudo --auto-yes blesh
./install.sh sync --dry-run bash
./install.sh sync bash
```

The installer builds the existing pinned ble.sh revision and its pinned contrib
submodule without sudo. It installs to
`${XDG_DATA_HOME:-$HOME/.local/share}/blesh`, matching the Bash startup lookup.
Git, GNU Make, and GNU awk must already be available. Apple's command-line tools
provide Git and GNU Make; Homebrew provides GNU awk as `gawk`.
On macOS, an explicit `blesh` request uses this source recipe with or without
`--no-sudo`; other requested tools continue to use their normal installation route.

This uses upstream's supported source installation rather than a moving nightly
tarball or an additional Homebrew tap. The build assembles shell scripts; no C/C++
compiler is needed for ble.sh itself. See the
[upstream installation instructions](https://github.com/akinomyoga/ble.sh#quick-instructions).

Before syncing an existing setup, back up real `~/.bashrc` and `~/.bash_profile`
files and preserve their host-specific initialization in `~/.bashrc.local`.
Remove duplicate fzf startup from that override: the managed `.bashrc` selects
the ble.sh-compatible integration. Stow refuses conflicting files rather than
adopting or overwriting them.

Open a new interactive Bash session to activate ble.sh. On macOS, use Homebrew's
`bash` if installed; upstream recommends Bash 4 or newer. This does not change
your login shell. Installing dependencies alone does not modify startup files,
and syncing alone does not install ble.sh.

## Customization

Host-specific settings stay outside the repository:

- `~/.bashrc.local`: Bash-only machine settings
- `$XDG_CONFIG_HOME/shell/local`: Shared machine settings
- `~/.config/bash/.bash_aliases`: Additional Bash aliases
- `~/.config/bash/.bash_functions`: Additional Bash functions
