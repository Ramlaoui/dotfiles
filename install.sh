#!/usr/bin/env bash

# Dotfiles installation script with improved reliability and error handling

# Exit immediately if a command exits with a non-zero status
set -e

# Set DOTFILES_DIR to the location of this script
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

# Log functions for better output
log_info() { printf "\033[0;34m➜ %s\033[0m\n" "$1"; }
log_success() { printf "\033[0;32m✓ %s\033[0m\n" "$1"; }
log_error() { printf "\033[0;31m✗ %s\033[0m\n" "$1" >&2; }
log_warning() { printf "\033[0;33m⚠ %s\033[0m\n" "$1"; }

# Initialize variables
STOW_ONLY=false
CORE_DEPENDENCY_ARGS=()
INSTALL_TMUX_PLUGINS=false
SKIP_SHELL_CHANGE=false
VERBOSE=false
SPECIFIC_PACKAGES=()

# Function to display usage help
show_help() {
    cat << EOF
Usage: $0 [options] [package1 package2 ...]

Options:
  --stow-only       Only apply 'stow' to the folders, skip dependencies installation
  --no-sudo         Install packages from source without using sudo
  --auto-yes        Automatically agree to prompts
  --skip-shell      Skip changing the default shell to zsh
  --verbose         Show verbose output
  -h, --help        Show this help message and exit

You can specify specific packages to install after all options.
Available packages: git curl python3-venv nvim fd-find git-delta lazygit bat eza tldr zsh htop fzf tmux stow ripgrep
EOF
}

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
        INSTALL_TMUX_PLUGINS=true
        shift
        ;;
    --skip-shell)
        SKIP_SHELL_CHANGE=true
        shift
        ;;
    --verbose)
        VERBOSE=true
        set -x # Enable bash debugging if verbose
        shift
        ;;
    -h | --help)
        show_help
        exit 0
        ;;
    --*)
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
    *)
        # Collect non-option arguments as specific packages to install
        SPECIFIC_PACKAGES+=("$1")
        shift
        ;;
    esac
done

# Check for essential commands before proceeding
check_required_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 is not installed. This is required for the installation."
        if [ "$2" != "optional" ]; then
            exit 1
        fi
        return 1
    fi
    return 0
}

# Verify essential commands
log_info "Checking for required commands..."
check_required_command "git" || {
    log_error "Git must be installed to proceed."
    log_info "Please install git and try again."
    exit 1
}

# Check for stow, but allow installation to continue as it may be installed by the script
check_required_command "stow" "optional" || {
    log_warning "GNU Stow is not installed. It will be installed by the script."
}

# Setup directories
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
ZSH_HOME="${ZSH_HOME:-$HOME/.zsh}"

# Ensure directories exist
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$ZSH_HOME"

# Detect operating system
detect_os() {
    case "$(uname -s)" in
        Darwin*) echo "macos" ;;
        Linux*)  echo "linux" ;;
        *)       echo "unknown" ;;
    esac
}

OS_TYPE=$(detect_os)

# Apply stow to the folders with backup capability
stow_config() {
    local pkg=$1
    
    if [ ! -d "$pkg" ]; then
        log_warning "Directory $pkg does not exist, skipping"
        return
    fi
    
    # Stow with sane options: --no-folding prevents weird deep directory behavior
    if stow --no-folding -v -t "$HOME" -R "$pkg" 2>/dev/null; then
        log_success "Stowed $pkg"
    else
        log_error "Failed to stow $pkg even after backing up. Please check manually."
    fi
}

# Apply stow to dotfiles
log_info "Applying stow to dotfiles..."
for pkg in zsh tmux nvim git python bash rofi kanata linux vscode; do
    if [ "$pkg" = "vscode" ]; then
        if [ "$OS_TYPE" = "macos" ]; then
            log_info "Stowing VS Code for macOS"
            stow --no-folding -v -t "$HOME/Library/Application Support" -R "$pkg" 2>/dev/null || log_warning "Failed to stow $pkg"
        else
            log_info "Stowing VS Code for Linux"
            stow_config "$pkg"
        fi
    elif [ "$pkg" = "linux" ]; then
        if [ "$OS_TYPE" = "linux" ]; then
            log_info "Stowing Linux configuration"
            stow_config "$pkg"
        fi
    else
        stow_config "$pkg"
    fi
done

if [ "$STOW_ONLY" = true ]; then
    log_success "Running stow only, skipping dependencies installation."
    exit 0
fi

# Install core dependencies with better error handling
log_info "Installing core dependencies..."
if [ -f "./scripts/installs/core-dependency.sh" ]; then
    # If specific packages were specified, add them to the command
    if [ ${#SPECIFIC_PACKAGES[@]} -gt 0 ]; then
        log_info "Installing specific packages: ${SPECIFIC_PACKAGES[*]}"
        ./scripts/installs/core-dependency.sh "${CORE_DEPENDENCY_ARGS[@]}" "${SPECIFIC_PACKAGES[@]}" || {
            log_error "Failed to install core dependencies."
            log_warning "You can still use your dotfiles, but some features may not work."
        }
    else
        ./scripts/installs/core-dependency.sh "${CORE_DEPENDENCY_ARGS[@]}" || {
            log_error "Failed to install core dependencies."
            log_warning "You can still use your dotfiles, but some features may not work."
        }
    fi
else
    log_error "Core dependency script not found at ./scripts/installs/core-dependency.sh"
    log_warning "Skipping dependency installation. Some features may not work."
fi

# Setup tmux with better prompting and error handling
if [ "$INSTALL_TMUX_PLUGINS" != true ]; then
    read -p "Do you want to install tmux plugins? This will remove the current tmux configuration [y/n] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] && INSTALL_TMUX_PLUGINS=true
fi

if [ "$INSTALL_TMUX_PLUGINS" = true ]; then
    log_info "Installing tmux plugins..."
    rm -rf "$HOME/.config/tmux/plugins"
    mkdir -p "$HOME/.config/tmux/plugins"
    
    if git clone --depth=1 https://github.com/tmux-plugins/tpm "$HOME/.config/tmux/plugins/tpm"; then
        log_success "tmux plugin manager installed successfully"
    else
        log_error "Failed to clone tmux plugin manager"
    fi
else
    log_info "Skipping tmux plugin installation"
fi

# Install Starship prompt with better path handling and error recovery
install_starship() {
    if command -v starship >/dev/null; then
        log_success "Starship is already installed"
    else
        log_info "Installing Starship..."
        
        # First try to install to /usr/bin
        if curl -sS https://starship.rs/install.sh | sh -s -- --yes; then
            log_success "Starship installed successfully in /usr/bin"
            return 0
        fi
        
        log_warning "Installation in /usr/bin failed. Trying ~/.local/bin..."
        
        # Try to install to ~/.local/bin
        mkdir -p "$HOME/.local/bin"
        if curl -sS https://starship.rs/install.sh | sh -s -- --bin-dir "$HOME/.local/bin" --yes; then
            log_success "Starship installed successfully in ~/.local/bin"
            log_info "Make sure ~/.local/bin is in your PATH"
            return 0
        fi
        
        log_error "Failed to install Starship"
        return 1
    fi
}

install_starship || log_warning "Starship installation failed, you can install it manually later"

# Install Prezto with better error handling
install_prezto() {
    local prezto_dir="${ZDOTDIR:-$HOME}/.zprezto"
    
    if [[ -d "$prezto_dir" ]]; then
        log_success "Prezto is already installed"
        
        # Update prezto if already installed
        if [ -d "$prezto_dir/.git" ]; then
            log_info "Updating Prezto..."
            (cd "$prezto_dir" && git pull && git submodule update --init --recursive)
        fi
    else
        log_info "Installing Prezto..."
        if git clone --recursive https://github.com/sorin-ionescu/prezto.git "$prezto_dir"; then
            log_success "Prezto installed successfully"
        else
            log_error "Failed to install Prezto"
            return 1
        fi
    fi
}

install_prezto || log_warning "Prezto installation failed, you can install it manually later"

# Setup Neovim with better path handling
setup_neovim() {
    log_info "Setting up Neovim environments..."
    
    # Validate Neovim installation
    if ! command -v nvim >/dev/null; then
        log_warning "Neovim is not installed. Please install it first using core-dependency.sh."
        return 1
    fi
    
    log_success "Using Neovim: $(which nvim) ($(nvim --version | head -n1))"
    return 0
}

setup_neovim || log_warning "Neovim validation failed, but continuing with environment setup..."

# Create Python3 environment for Neovim with better error recovery
setup_nvim_python() {
    log_info "Setting up Python environment for Neovim..."
    
    local nvim_venvs="$XDG_DATA_HOME/nvim"
    
    if [[ ! -d "$nvim_venvs/py3" ]]; then
        mkdir -p "$nvim_venvs"
        
        if python3 -m venv "$nvim_venvs/py3"; then
            local pip="$nvim_venvs/py3/bin/pip"
            
            "$pip" install --upgrade pip || log_warning "Failed to upgrade pip"
            
            # Install Python packages for Neovim
            packages=("neovim" "python-language-server[all]" "pylint" "isort" "jedi" "flake8" "pyright" "black" "yapf")
            
            for package in "${packages[@]}"; do
                log_info "Installing $package..."
                if ! "$pip" install "$package"; then
                    log_warning "Failed to install $package"
                fi
            done
            
            log_success "Python environment setup complete"
        else
            log_error "Failed to create Python venv for Neovim"
            return 1
        fi
    else
        log_success "Python environment for Neovim already exists"
    fi
}

setup_nvim_python || log_warning "Neovim Python setup failed, you can set it up manually later"

# Create Node.js environment with better error handling
setup_node() {
    log_info "Setting up Node.js environment..."
    
    local node_env="$XDG_DATA_HOME/node"
    
    if command -v node >/dev/null; then
        log_success "Node.js is already installed"
    else
        mkdir -p "$node_env"
        local node_script="$node_env/install-node.sh"
        
        if curl -sL install-node.now.sh/lts -o "$node_script"; then
            chmod +x "$node_script"
            
            if PREFIX="$node_env" "$node_script" -y; then
                export PATH="$node_env/bin:$PATH"
                log_success "Node.js installed successfully"
            else
                log_error "Failed to install Node.js"
                return 1
            fi
        else
            log_error "Failed to download Node.js installation script"
            return 1
        fi
    fi
    
    # Install global npm packages
    if command -v npm >/dev/null; then
        log_info "Installing Neovim Node.js support..."
        npm install -g neovim || log_warning "Failed to install Neovim Node.js package"
        
        log_info "Installing tree-sitter CLI..."
        npm install -g tree-sitter-cli || log_warning "Failed to install tree-sitter CLI"
    else
        log_error "npm not found, can't install Node.js packages"
        return 1
    fi
}

setup_node || log_warning "Node.js setup failed, you can set it up manually later"

# Finalize tmux setup
if command -v tmux >/dev/null && [ -f "$HOME/.config/tmux/tmux.conf" ]; then
    log_info "Finalizing tmux setup..."
    
    tmux source-file "$HOME/.config/tmux/tmux.conf" || log_warning "Failed to source tmux.conf"
    
    if [ -f "$HOME/.config/tmux/plugins/tpm/scripts/install_plugins.sh" ]; then
        chmod +x "$HOME/.config/tmux/plugins/tpm/scripts/install_plugins.sh"
        "$HOME/.config/tmux/plugins/tpm/scripts/install_plugins.sh" || log_warning "Failed to install tmux plugins"
    else
        log_warning "TPM install script not found"
    fi
else
    log_warning "tmux or tmux.conf not found, skipping tmux finalization"
fi

# Set default shell to zsh
if [ "$SKIP_SHELL_CHANGE" != true ]; then
    if command -v zsh >/dev/null; then
        log_info "Setting default shell to zsh..."
        
        # Check if zsh is already the default shell
        if [ "$SHELL" = "$(which zsh)" ]; then
            log_success "zsh is already the default shell"
        else
            # Get zsh path and check if it's in /etc/shells
            ZSH_PATH=$(command -v zsh)
            
            if ! grep -q "$ZSH_PATH" /etc/shells; then
                log_warning "$ZSH_PATH not found in /etc/shells"
                
                # Try to add zsh to /etc/shells if we have permission
                if [ -w /etc/shells ]; then
                    echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
                else
                    log_warning "Cannot add zsh to /etc/shells, please do this manually"
                fi
            fi
            
            # Change the shell
            if chsh -s "$ZSH_PATH"; then
                log_success "Default shell changed to zsh"
                log_info "Please log out and log back in for the change to take effect"
            else
                log_error "Failed to change default shell to zsh"
                log_info "You can change it manually with: chsh -s $(which zsh)"
            fi
        fi
    else
        log_error "zsh is not installed, cannot set as default shell"
    fi
else
    log_info "Skipping shell change as requested"
fi

log_success "Installation complete! Restart your terminal or run 'exec zsh' to apply all changes."

exit 0
