#!/usr/bin/env bash

# Credits to https://raw.githubusercontent.com/Lissy93/dotfiles/HEAD/scripts/installs/prerequisites.sh

# TODO: Separate core packages from optional packages

core_packages=(
    "git" # Manage dependencies and dotfiles
    "curl" # Download files
    "python3-venv" # Python virtual environments
    "neovim" # Text editor
    "fd-find" # Find files
    "git-delta" # Git diff viewer
    "bat" # Cat clone with syntax highlighting
    "zsh" # Shell
    "htop" # System monitor
    "fzf" # Fuzzy finder
    "tmux" # Terminal multiplexer
    "stow" # Dotfile manager (symlinks)
)

# List of packages with their repository URLs and build types
declare -a git_packages=(
  "git git https://github.com/git/git make"
  "curl curl https://github.com/curl/curl autotools"
  # "python3-venv https://github.com/python/cpython autotools"
  "neovim https://github.com/neovim/neovim cmake"
  "fd-find fd https://github.com/sharkdp/fd rust"
  "git-delta delta https://github.com/dandavison/delta rust"
  "bat bat https://github.com/sharkdp/bat rust"
  "zsh zsh https://github.com/zsh-users/zsh autotools"
  "htop htop https://github.com/htop-dev/htop autotools"
  "fzf fzf https://github.com/junegunn/fzf go"
  "tmux tmux https://github.com/tmux/tmux autotools"
  "stow stow https://github.com/aspiers/stow stow"
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

# Function to install packages from Git repositories
function install_from_git () {
  local package_name="$1"
  local repo_url="$2"
  local build_type="$3"
  
  echo -e "${PURPLE}Installing ${package_name} from Git${RESET}"
  
  local repo_name=$(basename "$repo_url" .git)
  
  echo -e "${PURPLE}Cloning ${repo_url}${RESET}"
  git clone "$repo_url"
  
  cd "$repo_name" || exit 1
  
  echo -e "${PURPLE}Building and installing ${package_name}${RESET}"
  
  case "$build_type" in
    autotools)
      ./configure --prefix="$HOME/.local"
      make
      make install
      ;;
    cmake)
      cmake . -DCMAKE_INSTALL_PREFIX="$HOME/.local"
      make
      make install
      ;;
    rust)
      if ! hash "cargo" 2> /dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
        export PATH="$HOME/.cargo/bin:$PATH"
      else
          echo -e "rust already installed"
      fi
      cargo install --path . --root "$HOME/.local"
      ;;
    go)
      export PATH="$HOME/go/bin:$PATH"
      if ! hash "go" 2> /dev/null; then
          wget https://go.dev/dl/go1.23.2.linux-amd64.tar.gz
          mkdir -p "$HOME/go"
          tar -C "$HOME/go" --strip-components=1 -xzf go1.23.2.linux-amd64.tar.gzb
          rm -rf go1.23.2.linux-amd64.tar.gzb
      else
          echo -e "rust already installed"
      fi
      go build -o "$HOME/.local/bin/$package_name"
      ;;
    make)
      make prefix="$HOME/.local"
      make install prefix="$HOME/.local"
      ;;
    perl)
      perl Makefile.PL PREFIX="$HOME/.local"
      make
      make install
      ;;
    stow)
        if ! hash "cpanm" 2> /dev/null; then
        # Download the cpanminus script
            curl -L https://cpanmin.us -o cpanm
            chmod +x cpanm

            # Move cpanm to your local bin directory
            mkdir -p "$HOME/.local/bin"
            mv cpanm "$HOME/.local/bin/"

            # Ensure your local bin directory is in your PATH
            export PATH="$HOME/.local/bin:$PATH"
        fi
      cpanm -l "$HOME/.local" Test::Output
      export PERL5LIB="$HOME/.local/lib/perl5:$PERL5LIB"
    if ! hash "makeinfo" 2> /dev/null; then
      wget https://ftp.gnu.org/gnu/texinfo/texinfo-7.1.tar.xz
      tar xf texinfo-7.1.tar.xz
        cd texinfo-7.1
        ./configure --prefix="$HOME/.local" --disable-perl-xs
        make
    make install
    cd ../
    rm -rf texinfo-7.1.tar.xz
    rm -rf texinfo-7.1
    fi
      autoreconf -iv
      ./configure --prefix="$HOME/.local"
      make
      make install
      ;;
    *)
      echo "Unknown build type: $build_type"
      ;;
  esac
  
  # cd ..
  # rm -rf "$repo_name"
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
# for app in ${core_packages[@]}; do
#   if ! hash "${app}" 2> /dev/null; then
#     multi_system_install $app
#   else
#     echo -e "${YELLOW}${app} is already installed, skipping${RESET}"
#   fi
# done

for package_info in "${git_packages[@]}"; do
  read -r package_name package_cmd repo_url build_type <<< "$package_info"
  if ! hash "${package_cmd}" 2> /dev/null; then
      install_from_git "$package_name" "$repo_url" "$build_type"
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

