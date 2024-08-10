#!/usr/bin/env bash

set -e

if [ -e .stow-debian ]
then
    sudo apt-get install stow
    exit 0;
fi

PATH=$HOME/.local/bin:$PATH
source perl/.perlenv

cd build
cpanm --local-lib=$PERL_LOCAL_LIB_ROOT local::lib Module::Build IO::Scalar
cpanm --installdeps .


# Install script
# Pull repo

 

# Install tmux



# Install zsh



# Install nvim
git clone git@github.com:neovim/neovim.git -b stable $HOME/.local/src/neovim
cd $HOME/.local/src/neovim
make CMAKE_BUILD_TYPE=Release
make CMAKE_INSTALL_PREFIX=$HOME/.local install
# put it in separate script

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

# Create Python3 environment
if [[ ! -d $NVIM/py3 ]]; then
    python3 -m venv $NVIM/py3
    PIP=$NVIM/py3/bin/pip
    $PIP install --upgrade pip
    $PIP install neovim
    $PIP install 'python-language-server[all]'
    $PIP install pylint isort jedi flake8
    $PIP install black yapf
fi

# Create node env
if [[ ! -d $NVIM/node ]]; then
    mkdir -p $NVIM/node
    NODE_SCRIPT=/tmp/install-node.sh
    curl -sL install-node.now.sh/lts -o $NODE_SCRIPT
    chmod +x $NODE_SCRIPT
    PREFIX=$NVIM/node $NODE_SCRIPT -y
    PATH="$NVIM/node/bin:$PATH"
    npm install -g neovim
fi

# Setup tmux
if [[ ! -d $HOME/.tmux/plugins/tpm ]]; then
    mkdir -p $HOME/.tmux/plugins
    git clone https://github.com/tmux-plugins/tpm $HOME/.tmux/plugins/tpm
fi
pull_repo $HOME/.tmux/plugins/tpm


# Setup zsh
# setup zsh as main shell
chsh -s $(which zsh)

# download and install zimfw (modules will be loaded from .zimrc)
curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh | zsh


# setup env
SELF=$(basename $0)
SELFDIR=$(readlink -f $(dirname $0))

source perl/.perlenv
PATH=$HOME/.local/bin:$PATH

set +e

# Cleanup all old legacy stuf first
for i in $(find $HOME -maxdepth 1 -type l);
do
    found=$(readlink -e $i)
    if [ -z $found ]
    then
        echo "Unable to find $i"
        rm $i
    fi
done

set -e

for i in .profile .bashrc .zshrc .xscreensaverrc
do
    [ -f "$HOME/$i" ] && rm "$HOME/$i"
done

stow stow \
  # x11 \
  zsh \
  nvim \
  # scripts \
  apps \
  # perl \
  git

# On install time determine if this is debian
# then stow, otherwise stow -D debian
stow debian

if [ ! -e $HOME/.env.local ] ; then
    cp $SELFDIR/env.local $HOME/.env.local
fi

exit 0

