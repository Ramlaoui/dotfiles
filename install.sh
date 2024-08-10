#!/usr/bin/env bash

set -e

./core-dependency.sh

# install stow, make, cmake, gettext

# # download and install zimfw (modules will be loaded from .zimrc)
# if [[ ! -d $HOME/.zim ]]; then
#     curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh | zsh
# fi

stow zsh \
    tmux \
    nvim
    # git \

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


# # Create separate Python3 environment for neovim
# NVIM_VENVS=$HOME/.local/share/nvim/
# if [[ ! -d $NVIM_VENVS/py3 ]]; then
#     python3 -m venv $NVIM_VENVS/py3
#     PIP=$NVIM_VENVS/py3/bin/pip
#     $PIP install --upgrade pip
#     $PIP install neovim
#     $PIP install 'python-language-server[all]'
#     $PIP install pylint isort jedi flake8
#     $PIP install black yapf
# fi

# # Create Python3 global environment
# python3 -m pip -V
# python3 -m pip install --upgrade pip
# python3 -m pip install --no-wardn-script-location \
#     neovim \ 
#     pylint isort jedi flake8 \
#     black yapf
#
# add this to init.lua
# let g:python3_host_prog = '/path/to/py3nvim/bin/python'


# Create node env
if [[ ! -d $NVIM/node ]]; then
    mkdir -p $NVIM/node
    NODE_SCRIPT=/tmp/install-node.sh
    if command -v curl > /dev/null; then
        $DOWNLOAD_CMD="curl -sL install-node.now.sh/lts -o $NODE_SCRIPT"
    elif command -v wget > /dev/null; then
        $DOWNLOAD_CMD="wget -qO $NODE_SCRIPT install-node.now.sh/lts"
    else
        echo "ERROR: Neither curl nor wget is available"
        exit 1
    fi
    chmod +x $NODE_SCRIPT
    PREFIX=$NVIM/node $NODE_SCRIPT -y
    PATH="$NVIM/node/bin:$PATH"
    npm install -g neovim
fi

# Setup tmux
if [[ ! -d $HOME/.tmux/plugins/tpm ]]; then
    mkdir -p $HOME/.tmux/plugins
    git clone --depth=1 https://github.com/tmux-plugins/tpm $HOME/.config/tmux/plugins/tpm
    ~/.config/tmux/plugins/tpm/scripts/install_plugins.sh &&
	cd ~/.config/tmux/plugins/tmux-thumbs &&
		expect -c "spawn ./tmux-thumbs-install.sh; send \"\r2\r\"; expect complete" 1>/dev/null
fi


# Setup zsh
# Need an alternative where exec zsh is added to .bashrc
chsh -s $(which zsh)

exit 0

