#!/usr/bin/env bash

# Credits to https://raw.githubusercontent.com/Lissy93/dotfiles/HEAD/scripts/installs/prerequisites.sh

# TODO: Separate core packages from optional packages

core_packages=(
    "git" # Manage dependencies and dotfiles
    "python3-venv" # Python virtual environments
    "curl" # Download files
    "neovim" # Text editor
    "zsh" # Shell
    "htop" # System monitor
    "fzf" # Fuzzy finder
    "tmux" # Terminal multiplexer
    "stow" # Dotfile manager (symlinks)
)

# Color variables
PURPLE='\033[0;35m'
YELLOW='\033[0;93m'
LIGHT='\x1b[2m'
RESET='\033[0m'

# Shows help menu / introduction
function print_usage () {
  echo -e "${PURPLE}Prerequisite Dependency Installation Script${LIGHT}\n"\
  "There's a few packages that are needed in order to continue with setting up dotfiles.\n"\
  "This script will detect distro and use appropriate package manager to install apps.\n"\
  "Elavated permissions may be required. Ensure you've read the script before proceeding."\
  "\n${RESET}"
}

function install_debian () {
  echo -e "${PURPLE}Installing ${1} via apt-get${RESET}"
  sudo apt install $1 -y
  sudo apt upgrade $1 -y
}
function install_arch () {
  echo -e "${PURPLE}Installing ${1} via Pacman${RESET}"
  sudo pacman -S $1 --noconfirm
  sudo pacman -Syu $1 --noconfirm
}
function install_mac () {
  echo -e "${PURPLE}Installing ${1} via Homebrew${RESET}"
  brew install $1 -y
  brew upgrade $1 -y
}
function get_homebrew () {
  echo -e "${PURPLE}Setting up Homebrew${RESET}"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  export PATH=/opt/homebrew/bin:$PATH
}

# Detect OS type, then triggers install using appropriate package manager
function multi_system_install () {
  app=$1
  if [ "$(uname -s)" = "Darwin" ]; then
    if ! hash brew 2> /dev/null; then get_homebrew; fi
    install_mac $app # MacOS via Homebrew
elif [ "$(uname -s)" = "Linux" ] && hash pacman 2> /dev/null; then
    install_arch $app # Arch Linux via Pacman
elif [ "$(uname -s)" = "Linux" ] && hash apt 2> /dev/null; then
    install_debian $app # Debian via apt-get
  else
    echo -e "${YELLOW}Skipping ${app}, as couldn't detect system type ${RESET}"
  fi
}

# Show usage instructions, help menu
print_usage
if [[ $* == *"--help"* ]]; then exit; fi

# Ask user if they'd like to proceed
if [[ ! $* == *"--auto-yes"* ]] ; then
  echo -e "${PURPLE}Are you happy to continue? (y/N)${RESET}"
  read -t 15 -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Proceeding was rejected by user, exiting...${RESET}"
    exit 0
  fi
fi

# For each app, check if not present and install
for app in ${core_packages[@]}; do
  if ! hash "${app}" 2> /dev/null; then
    multi_system_install $app
  else
    echo -e "${YELLOW}${app} is already installed, skipping${RESET}"
  fi
done

# check if tmux is available
if ! command -v tmux &> /dev/null
then
    echo "installing tmux from source"

    # necessary packages are libevent-dev and ncurses-dev https://github.com/tmux/tmux/wiki/Installing
    
    git clone https://github.com/tmux/tmux.git $HOME/.local/src/tmux
    cd $HOME/.local/src/tmux
    # requires autotools-dev and automake and clang
    sh autogen.sh
    ./configure && make && make install

    # move tmux to $HOME/.local/bin if not already done

    # add tmux to PATH (this should be in exports)
    export PATH=$HOME/.local/bin:$PATH
fi

# check if nvim is available
if ! command -v nvim &> /dev/null; then
    echo "nvim is not installed"

    echo "Installing from source"

    # Define the target directory
    TARGET_DIR="$HOME/.local/src/neovim"

    # Check if the repository is already cloned
    if [ -d "$TARGET_DIR/.git" ]; then
        echo "Repository already cloned at $TARGET_DIR"
    else
        # Clone the repository since it's not present
        git clone https://github.com/neovim/neovim.git -b stable "$TARGET_DIR"
    fi

    cd $HOME/.local/src/neovim
    make CMAKE_BUILD_TYPE=Release
    make CMAKE_INSTALL_PREFIX=$HOME/.local install

fi



# check if fzf is available
if [! command -v fzf &> /dev/null]; then
    echo "fzf is not installed"

    echo "Installing from source"

    # Define the target directory
    TARGET_DIR="$HOME/.fzf"

    # Check if the repository is already cloned
    if [ -d "$TARGET_DIR/.git" ]; then
        echo "Repository already cloned at $TARGET_DIR"
    else
        # Clone the repository since it's not present
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install
    fi

fi

# All done
echo -e "\n${PURPLE}Jobs complete, exiting${RESET}"
exit 0

