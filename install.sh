#!/usr/bin/env bash

set -e

# install stow, make, cmake, gettext
# # download and install zimfw (modules will be loaded from .zimrc)
./scripts/installs/core-dependency.sh

# Setup tmux
# ask for confirmation
read -p "Do you want to install tmux plugins? This will remove the current tmux configuration [y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Skipping tmux plugin installation"
else
    echo "Installing tmux plugins..."
    rm -rf $HOME/.config/tmux/plugins
    mkdir -p $HOME/.config/tmux/plugins
    git clone --depth=1 https://github.com/tmux-plugins/tpm $HOME/.config/tmux/plugins/tpm
fi

stow zsh \
    tmux \
    nvim

XDG_CONFIG_HOME=$HOME/.config
XDG_DATA_HOME=$HOME/.local/share
ZSH_HOME=$HOME/.zsh
    
# starship
if command -v starship > /dev/null; then
    echo "Starship is already installed"
else
    echo "Installing Starship..."
    echo "Attempting to install Starship in /usr/bin..."

    if curl -sS https://starship.rs/install.sh | sh -s -- --yes; then
        echo "Starship installed successfully in /usr/bin."
    else
        echo "Installation in /usr/bin failed. Trying to install in ~/.local/bin..."
        # If the installation to /usr/bin fails, try installing to ~/.local/bin
        if curl -sS https://starship.rs/install.sh | sh -s -- --bin-dir ~/.local/bin --yes; then
            echo "Starship installed successfully in ~/.local/bin."
            echo 'Make sure ~/.local/bin is in your PATH.'
        else
            echo "Installation in ~/.local/bin failed as well."
            exit 1
        fi
    fi
fi

# prezto
if [[ -d ${ZDOTDIR:-$HOME}/.zprezto ]]; then
    echo "Prezto is already installed"
else
    git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"
    # # add prompt_starship_setup function to Prezto (was unable to make it work), load starship in .zshrc after prezto
    # ZPREZTODIR=${ZPREZTODIR:-${ZDOTDIR:-$HOME}/.zprezto}
    # echo 'eval "$(starship init zsh)"' >! $ZPREZTODIR/modules/prompt/functions/prompt_starship_setup
fi

# Setup nvim
NVIM=$HOME/.local/
mkdir -p $NVIM

# AppImage in case the computer does not have a fallback nvim (appimage does not self update)
if command -v nvim > /dev/null; then
    echo "NVIM appears to be installed"
else
    mkdir -p $NVIM/bin
    cd $NVIM/bin
    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
    chmod u+x nvim.appimage
    mv nvim.appimage nvim
    cd -
fi


# Create separate Python3 environment for neovim
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

# Create node env
NODE_ENV=$XDG_DATA_HOME/node
if [[ ! -d $NODE_ENV ]]; then
    mkdir -p $NODE_ENV
    NODE_SCRIPT=$NODE_ENV/install-node.sh
    if command -v curl > /dev/null; then
        curl -sL install-node.now.sh/lts -o $NODE_SCRIPT
    else
        echo "ERROR: curl is not installed"
        exit 1
    fi
    chmod +x $NODE_SCRIPT
    PREFIX=$NODE_ENV $NODE_SCRIPT -y # install node in $NODE_ENV
    export PATH=$NODE_ENV/bin:$PATH
    npm install -g neovim
fi

# Finish setting up tmux
tmux source-file $HOME/.config/tmux/tmux.conf
chmod +x $HOME/.config/tmux/plugins/tpm/scripts/install_plugins.sh
$HOME/.config/tmux/plugins/tpm/scripts/install_plugins.sh

# Setup zsh
# also need an alternative where exec zsh is added to .bashrc
chsh -s $(which zsh)

exit 0

