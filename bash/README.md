# Bash Configuration

This directory contains configuration files for Bash that share common elements with the ZSH configuration.

## Structure

- `.bashrc`: Main configuration file that sources all other files
- `.bash_profile`: Sources `.bashrc` for login shells
- `.bashrc.local`: Local machine-specific configuration
- `.config/bash/.bash_aliases`: Bash-specific aliases
- `.config/bash/.bash_functions`: Bash-specific functions

## Features

- Shares common configuration (aliases, exports, functions) with ZSH
- Uses Starship prompt if available
- Supports FZF integration
- Includes common utility functions and aliases
- Properly sources Google Cloud SDK and conda if available

## Usage

The installation script will automatically stow these files to your home directory. If you want to manually install them, use:

```bash
stow -t "$HOME" bash
```

## Customization

You can customize your bash environment by editing the following files:

- `~/.bashrc.local`: For machine-specific configuration
- `~/.config/bash/.bash_aliases`: For additional bash-specific aliases
- `~/.config/bash/.bash_functions`: For additional bash-specific functions 
