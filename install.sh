#!/usr/bin/env bash

# Heavily copied https://github.com/Lissy93/dotfiles/blob/master/install.sh

set -e

DOTFILES_DIR="${DOTFILES_DIR:-${SRC_DIR:-$HOME/dotfiles}}"

# Initialize variables
STOW_ONLY=false
CORE_DEPENDENCY_ARGS=()

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
    --stow-only)
        STOW_ONLY=true
        shift
        ;;
    --no-sudo)
        CORE_DEPENDENCY_ARGS+=("--no-sudo")
        shift
        ;;
    --auto-yes)
        CORE_DEPENDENCY_ARGS+=("--auto-yes")
        shift
        ;;
    -h | --help)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --stow-only     Only apply 'stow' to the folders, skip dependencies installation."
        echo "  --no-sudo       Install packages from source without using sudo."
        echo "  --auto-yes      Automatically agree to prompts."
        echo "  -h, --help      Show this help message and exit."
        exit 0
        ;;
    *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
done

# Apply stow to the folders
stow zsh \
    tmux \
    nvim \
    git \
    python

if [ "$STOW_ONLY" = true ]; then
    echo "Running stow only, skipping dependencies installation."
    exit 0
fi

# Install core dependencies, passing the arguments
./scripts/installs/core-dependency.sh "${CORE_DEPENDENCY_ARGS[@]}"

# Setup tmux
read -p "Do you want to install tmux plugins? This will remove the current tmux configuration [y/n] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Installing tmux plugins..."
    rm -rf $HOME/.config/tmux/plugins
    mkdir -p $HOME/.config/tmux/plugins
    git clone --depth=1 https://github.com/tmux-plugins/tpm $HOME/.config/tmux/plugins/tpm
else
    echo "Skipping tmux plugin installation"
fi

XDG_CONFIG_HOME=$HOME/.config
XDG_DATA_HOME=$HOME/.local/share
ZSH_HOME=$HOME/.zsh

# Install Starship prompt
if command -v starship >/dev/null; then
    echo "Starship is already installed"
else
    echo "Installing Starship..."
    echo "Attempting to install Starship in /usr/bin..."

    if curl -sS https://starship.rs/install.sh | sh -s -- --yes; then
        echo "Starship installed successfully in /usr/bin."
    else
        echo "Installation in /usr/bin failed. Trying to install in ~/.local/bin..."
        if curl -sS https://starship.rs/install.sh | sh -s -- --bin-dir ~/.local/bin --yes; then
            echo "Starship installed successfully in ~/.local/bin."
            echo 'Make sure ~/.local/bin is in your PATH.'
        else
            echo "Installation in ~/.local/bin failed as well."
            exit 1
        fi
    fi
fi

# Install Prezto
if [[ -d ${ZDOTDIR:-$HOME}/.zprezto ]]; then
    echo "Prezto is already installed"
else
    git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"
fi

# Setup Neovim
NVIM=$HOME/.local/
mkdir -p $NVIM

if command -v nvim >/dev/null; then
    echo "NVIM appears to be installed"
else
    mkdir -p $NVIM/bin
    cd $NVIM/bin
    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
    chmod u+x nvim.appimage
    mv nvim.appimage nvim
    cd -
fi

# Create Python3 environment for Neovim
NVIM_VENVS=$XDG_DATA_HOME/nvim
if [[ ! -d $NVIM_VENVS/py3 ]]; then
    python3 -m venv $NVIM_VENVS/py3
    PIP=$NVIM_VENVS/py3/bin/pip
    $PIP install --upgrade pip
    $PIP install neovim
    $PIP install 'python-language-server[all]'
    $PIP install pylint isort jedi flake8 pyright
    $PIP install black yapf
fi

# Create Node.js environment
NODE_ENV=$XDG_DATA_HOME/node
if [[ ! -d $NODE_ENV ]]; then
    mkdir -p $NODE_ENV
    NODE_SCRIPT=$NODE_ENV/install-node.sh
    if command -v curl >/dev/null; then
        curl -sL install-node.now.sh/lts -o $NODE_SCRIPT
    else
        echo "ERROR: curl is not installed"
        exit 1
    fi
    chmod +x $NODE_SCRIPT
    PREFIX=$NODE_ENV $NODE_SCRIPT -y
    export PATH=$NODE_ENV/bin:$PATH
    npm install -g neovim
    npm install -g tree-sitter-cli
fi

# Finalize tmux setup
tmux source-file $HOME/.config/tmux/tmux.conf
chmod +x $HOME/.config/tmux/plugins/tpm/scripts/install_plugins.sh
$HOME/.config/tmux/plugins/tpm/scripts/install_plugins.sh

# Set default shell to zsh
chsh -s $(which zsh)

exit 0
