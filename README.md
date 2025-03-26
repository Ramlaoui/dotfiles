## Dotfiles

This repository contains my dotfiles. I use [GNU Stow](https://www.gnu.org/software/stow/) to manage them.
The goal is to keep the structure as simple as possible with only the necessary config files.
It tries to achieve two main goals separately:

- Import and sync the dotfiles easily on any machine.
- Install the necessary packages and dependencies to make the dotfiles work.
  This has to take into account:
  - The operating system and the package manager available.
  - The rights available to install packages and dependencies.

### Installation

To install the dotfiles, clone the repository and run the `install.sh` script.
The script will install the necessary packages and dependencies and then use GNU Stow to symlink the dotfiles.

```bash
cd ~
git clone
cd dotfiles
./install.sh
```

### Structure

The structure of the repository is as follows:

Tree structure of the repository:

```bash
.
├── git/                  # Git configuration
├── install.sh            # Main installation script
├── macos/                # macOS specific configurations
├── nvim/                 # Neovim configuration
│   └── .config/
│       └── nvim/
├── python/               # Python environment setup
├── README.md             # This documentation
├── scripts/              # Installation and setup scripts
│   ├── installs/         # Dependency installation scripts
│   ├── linux/            # Linux-specific scripts
│   └── macos/            # macOS-specific scripts
├── tmux/                 # Tmux configuration
├── todo.md               # Planned improvements
└── zsh/                  # Zsh shell configuration
    ├── .config/
    ├── .inputrc
    ├── .zpreztorc
    ├── .zshrc
    └── .zshrc.local
```
