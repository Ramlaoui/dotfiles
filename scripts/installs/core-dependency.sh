#!/usr/bin/env bash

# Prerequisite Dependency Installation Script
# This script installs necessary packages, detecting the OS and using the appropriate package manager.
# If sudo permissions are not available or the --no-sudo flag is used, it installs packages from source.

# Color variables
PURPLE='\033[0;35m'
YELLOW='\033[0;93m'
LIGHT='\x1b[2m'
RESET='\033[0m'

# Package lists
core_packages=(
    "git"
    "curl"
    "python3-venv"
    "nvim"
    "fd-find"
    "git-delta"
    "lazygit"
    "bat"
    "eza"
    "tldr"
    "zsh"
    "htop"
    "fzf"
    "tmux"
    "stow"
    "ripgrep"
)

# Packages that should always be built from source
always_build_from_source=(
    "tmux"
    "fzf"
)

# Additional dependencies for specific packages
declare -A package_deps
package_deps=(
    ["tmux"]="libevent-dev ncurses-dev build-essential bison pkg-config"
)

declare -A git_packages
git_packages=(
    ["git"]="https://github.com/git/git make"
    ["curl"]="https://github.com/curl/curl autotools"
    ["nvim"]="https://github.com/neovim/neovim nvim"
    ["fd"]="https://github.com/sharkdp/fd rust"
    ["delta"]="https://github.com/dandavison/delta rust"
    ["bat"]="https://github.com/sharkdp/bat rust"
    ["zsh"]="https://github.com/zsh-users/zsh autotools"
    ["htop"]="https://github.com/htop-dev/htop autotools"
    ["fzf"]="https://github.com/junegunn/fzf fzf"
    ["tmux"]="https://github.com/tmux/tmux autotools"
    ["stow"]="https://git.savannah.gnu.org/git/stow.git perl"
    ["ripgrep"]="https://github.com/BurntSushi/ripgrep rust"
)

# Parse command-line options
USE_SUDO=true
AUTO_YES=false
SHOW_HELP=false
SPECIFIC_PACKAGES=()

for arg in "$@"; do
    case $arg in
    --no-sudo)
        USE_SUDO=false
        ;;
    --auto-yes)
        AUTO_YES=true
        ;;
    --help)
        SHOW_HELP=true
        ;;
    --*)
        # Skip other options
        ;;
    *)
        # Collect non-option arguments as specific packages to install
        SPECIFIC_PACKAGES+=("$arg")
        ;;
    esac
done

# Help menu
function print_usage() {
    echo -e "${PURPLE}Prerequisite Dependency Installation Script${LIGHT}\n" \
        "This script installs necessary packages for setting up dotfiles.\n" \
        "It detects the OS and uses the appropriate package manager or installs from source.\n" \
        "Usage:\n" \
        "  ./core-dependency.sh [options] [package1 package2 ...]\n" \
        "Options:\n" \
        "  --no-sudo    Install packages from source without using sudo.\n" \
        "  --auto-yes   Automatically agree to prompts.\n" \
        "  --help       Show this help message and exit.\n" \
        "If no packages are specified, all core packages will be installed.\n" \
        "Available packages: ${core_packages[*]}\n${RESET}"
}

# Show help menu if requested
if [ "$SHOW_HELP" = true ]; then
    print_usage
    exit 0
fi

# If SPECIFIC_PACKAGES is empty, use all core_packages
if [ ${#SPECIFIC_PACKAGES[@]} -eq 0 ]; then
    SPECIFIC_PACKAGES=("${core_packages[@]}")
fi

# Prompt user to continue
if [ "$AUTO_YES" = false ]; then
    echo -e "${PURPLE}Installing the following packages: ${SPECIFIC_PACKAGES[*]}\nAre you happy to continue? (y/N)${RESET}"
    read -r -n 1 -t 15 REPLY
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Proceeding was rejected by user. Exiting...${RESET}"
        exit 0
    fi
fi

# Check if sudo is available
if ! command -v sudo &>/dev/null; then
    USE_SUDO=false
fi

# Update PATH for local installations
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:$PATH"

# Installation functions
function install_debian() {
    echo -e "${PURPLE}Installing ${1} via apt-get${RESET}"
    sudo apt-get update -y
    sudo apt-get install -y "$1"
}

function install_arch() {
    echo -e "${PURPLE}Installing ${1} via pacman${RESET}"
    sudo pacman -Sy --noconfirm "$1"
}

function install_mac() {
    echo -e "${PURPLE}Installing ${1} via Homebrew${RESET}"
    brew install "$1"
}

function get_homebrew() {
    echo -e "${PURPLE}Setting up Homebrew${RESET}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    export PATH="/opt/homebrew/bin:$PATH"
}

# Detect OS and install package
function multi_system_install() {
    local app="$1"
    if [ "$(uname -s)" = "Darwin" ]; then
        if ! command -v brew &>/dev/null; then
            get_homebrew
        fi
        install_mac "$app"
    elif [ -f "/etc/arch-release" ]; then
        install_arch "$app"
    elif [ -f "/etc/debian_version" ]; then
        install_debian "$app"
    else
        echo -e "${YELLOW}Skipping ${app}, could not detect system type.${RESET}"
    fi
}

function install_go() {
    if ! command -v go &>/dev/null; then
        echo -e "${PURPLE}Installing Go${RESET}"
        GO_VERSION="1.21.1"
        wget "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
        tar -C "$HOME" -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
        mv $HOME/go/bin/** "$HOME/.local/bin"
        rm -rf "$HOME/go"
    fi
}

# Function to install packages from Git repositories
function install_from_git() {
    local package_name="$1"
    local repo_url="$2"
    local build_type="$3"

    echo -e "${PURPLE}Installing ${package_name} from source${RESET}"

    # Create build directory
    BUILD_DIR="$HOME/build/${package_name}"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR" || exit 1

    # Clone repository
    if [ ! -d "${BUILD_DIR}/$(basename "$repo_url" .git)" ]; then
        echo -e "${PURPLE}Cloning ${repo_url}${RESET}"
        git clone "$repo_url"
    else
        echo -e "${YELLOW}${package_name} source already exists. Pulling latest changes.${RESET}"
        cd "$(basename "$repo_url" .git)" || exit 1
        git pull
        cd ..
    fi

    cd "$(basename "$repo_url" .git)" || exit 1

    # Set environment variables
    export CFLAGS="-I$HOME/.local/include $CFLAGS"
    export LDFLAGS="-L$HOME/.local/lib $LDFLAGS"
    export PKG_CONFIG_PATH="$HOME/.local/lib/pkgconfig:$PKG_CONFIG_PATH"
    export LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"

    # Build and install
    case "$build_type" in
    autotools)
        ./autogen.sh 2>/dev/null || true
        ./configure --prefix="$HOME/.local"
        make -j"$(nproc)"
        make install
        ;;
    cmake)
        mkdir -p build && cd build || exit 1
        cmake .. -DCMAKE_INSTALL_PREFIX="$HOME/.local"
        make -j"$(nproc)"
        make install
        ;;
    rust)
        if ! command -v cargo &>/dev/null; then
            echo -e "${PURPLE}Installing Rust${RESET}"
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            export PATH="$HOME/.cargo/bin:$PATH"
        fi
        cargo install --path . --root "$HOME/.local"
        ;;
    go)
        install_go
        mkdir -p "$HOME/.local/bin"
        go build -o "$HOME/.local/bin/$package_name"
        ;;
    fzf)
        install_go
        echo -e "${PURPLE}Building fzf${RESET}"
        make
        make install
        echo -e "${PURPLE}Installing fzf into $HOME/.local/bin${RESET}"
        mkdir -p "$HOME/.local/bin"
        cp bin/* "$HOME/.local/bin/"
        ;;
    lazygit)
        LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
        curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
        tar xf lazygit.tar.gz lazygit
        sudo install lazygit "$HOME/.local/bin"
        ;;
    make)
        #curl -O https://ftp.gnu.org/pub/gnu/gettext/gettext-0.22.5.tar.gz
        #tar xvf gettext-0.22.5.tar.gz
        #cd gettext-0.22.5/
        #./configure --prefix="$HOME/.local"
        #make
        #make install
        make prefix="$HOME/.local" -j"$(nproc)"
        make install prefix="$HOME/.local"
        ;;
    nvim)
        make CMAKE_INSTALL_PREFIX=$XDG_DATA_HOME/nvim install
        ;;
    perl)
        if ! command -v cpanm &>/dev/null; then
            echo -e "${PURPLE}Installing cpanminus${RESET}"
            curl -L https://cpanmin.us -o "$HOME/.local/bin/cpanm"
            chmod +x "$HOME/.local/bin/cpanm"
        fi
        export PERL5LIB="$HOME/.local/lib/perl5:$PERL5LIB"
        cpanm -l "$HOME/.local" --installdeps .
        perl Makefile.PL PREFIX="$HOME/.local"
        make -j"$(nproc)"
        make install
        ;;
    ripgrep)
        curl -LO https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep_14.1.0-1_amd64.deb
        dpkg -i ripgrep_14.1.0-1_amd64.deb
        ;;
    *)
        echo -e "${YELLOW}Unknown build type: $build_type${RESET}"
        ;;
    esac

    # Return to initial directory
    cd "$HOME" || exit 1
}

# Function to install package dependencies
function install_package_deps() {
    local package="$1"
    if [ -n "${package_deps[$package]}" ]; then
        echo -e "${PURPLE}Installing dependencies for ${package}${RESET}"
        if [ "$(uname -s)" = "Darwin" ]; then
            brew install "${package_deps[$package]}"
        elif [ -f "/etc/arch-release" ]; then
            sudo pacman -S --noconfirm "${package_deps[$package]}"
        elif [ -f "/etc/debian_version" ]; then
            sudo apt-get install -y "${package_deps[$package]}"
        fi
    fi
}

# Function to check if package is in the core_packages list
function is_valid_package() {
    local package="$1"
    for core_package in "${core_packages[@]}"; do
        if [ "$package" = "$core_package" ]; then
            return 0
        fi
    done
    return 1
}

# Validate the specified packages
for package in "${SPECIFIC_PACKAGES[@]}"; do
    if ! is_valid_package "$package"; then
        echo -e "${YELLOW}Warning: '$package' is not in the list of core packages. It might not install correctly.${RESET}"
    fi
done

# Main installation logic
for app in "${SPECIFIC_PACKAGES[@]}"; do
    if ! command -v "$app" &>/dev/null; then
        # Check if package should always be built from source
        should_build_from_source=false
        for build_pkg in "${always_build_from_source[@]}"; do
            if [ "$app" = "$build_pkg" ]; then
                should_build_from_source=true
                break
            fi
        done

        if [ "$should_build_from_source" = true ] || [ "$USE_SUDO" = false ]; then
            if [ -n "${git_packages[$app]}" ]; then
                IFS=' ' read -r repo_url build_type <<<"${git_packages[$app]}"
                install_from_git "$app" "$repo_url" "$build_type"
            else
                echo -e "${YELLOW}No installation method for $app without sudo. Skipping.${RESET}"
            fi
        else
            install_package_deps "$app"
            multi_system_install "$app"
        fi
    else
        # Check version for specific packages
        if [ "$app" = "tmux" ]; then
            current_version=$(tmux -V | cut -d' ' -f2)
            if [ "$(printf '%s\n' "3.5" "$current_version" | sort -V | head -n1)" != "3.5" ]; then
                echo -e "${YELLOW}${app} version $current_version is older than 3.5. Upgrading...${RESET}"
                install_package_deps "$app"
                if [ -n "${git_packages[$app]}" ]; then
                    IFS=' ' read -r repo_url build_type <<<"${git_packages[$app]}"
                    install_from_git "$app" "$repo_url" "$build_type"
                else
                    multi_system_install "$app"
                fi
            else
                echo -e "${YELLOW}${app} version $current_version is sufficient. Skipping.${RESET}"
            fi
        else
            echo -e "${YELLOW}${app} is already installed. Skipping.${RESET}"
        fi
    fi
done

# All done
echo -e "\n${PURPLE}All tasks completed successfully.${RESET}"
exit 0
