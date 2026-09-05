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

## Customization

Host-specific settings stay outside the repository:

- `~/.bashrc.local`: Bash-only machine settings
- `$XDG_CONFIG_HOME/shell/local`: Shared machine settings
- `~/.config/bash/.bash_aliases`: Additional Bash aliases
- `~/.config/bash/.bash_functions`: Additional Bash functions
