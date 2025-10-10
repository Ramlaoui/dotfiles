#!/bin/bash

# GNU Stow build script
# This script downloads, compiles, and installs GNU Stow from source

set -e  # Exit on any error

# Configuration
STOW_VERSION="2.4.0"
INSTALL_PREFIX="$HOME/local"  # Change this to wherever you want to install
BUILD_DIR="/tmp/stow-build-$$"  # Unique build directory

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_tip() {
    echo -e "${BLUE}[TIP]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for required tools
print_status "Checking for required build tools..."
MISSING_TOOLS=""

for tool in wget tar perl make; do
    if ! command_exists "$tool"; then
        MISSING_TOOLS="$MISSING_TOOLS $tool"
    fi
done

# Check for gcc or clang
if ! command_exists gcc && ! command_exists clang; then
    MISSING_TOOLS="$MISSING_TOOLS gcc"
fi

if [ -n "$MISSING_TOOLS" ]; then
    print_error "Missing required tools:$MISSING_TOOLS"
    print_error "Please install them first. On most systems:"
    print_error "  Ubuntu/Debian: sudo apt-get install build-essential wget perl"
    print_error "  CentOS/RHEL:   sudo yum install gcc make wget tar perl"
    print_error "  macOS:         Install Xcode command line tools"
    exit 1
fi

print_status "All required tools found."

# Check Perl version (Stow requires Perl 5.6.1 or later)
PERL_VERSION=$(perl -e 'print $]')
print_status "Found Perl version: $PERL_VERSION"

# Create install directory
print_status "Creating install directory: $INSTALL_PREFIX"
mkdir -p "$INSTALL_PREFIX"

# Create temporary build directory
print_status "Creating build directory: $BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Download GNU Stow
print_status "Downloading GNU Stow $STOW_VERSION..."
DOWNLOAD_URL="https://ftp.gnu.org/gnu/stow/stow-${STOW_VERSION}.tar.gz"
wget "$DOWNLOAD_URL" -O "stow-${STOW_VERSION}.tar.gz"

# Extract
print_status "Extracting source code..."
tar -xzf "stow-${STOW_VERSION}.tar.gz"
cd "stow-${STOW_VERSION}"

# Configure, compile, and install
print_status "Configuring build..."
./configure --prefix="$INSTALL_PREFIX"

print_status "Compiling..."
make

print_status "Running tests..."
make check || print_warning "Some tests failed, but continuing with installation"

print_status "Installing to $INSTALL_PREFIX..."
make install

# Clean up
print_status "Cleaning up build directory..."
cd /
rm -rf "$BUILD_DIR"

print_status "GNU Stow installation completed successfully!"
echo

# Create stow directories
STOW_DIR="$HOME/stow"
print_status "Creating stow directory structure at $STOW_DIR"
mkdir -p "$STOW_DIR"

# Generate environment setup and usage script
ENV_SETUP_FILE="$INSTALL_PREFIX/setup_stow_env.sh"
print_status "Creating environment setup script: $ENV_SETUP_FILE"

cat > "$ENV_SETUP_FILE" << EOF
#!/bin/bash
# Source this file to set up stow environment
# Usage: source setup_stow_env.sh

STOW_ROOT="$INSTALL_PREFIX"
export PATH="\$STOW_ROOT/bin:\$PATH"

# Set up stow directory
export STOW_DIR="$STOW_DIR"

# Useful aliases
alias stow-list='stow -v -n -t \$HOME -d \$STOW_DIR'
alias stow-install='stow -v -t \$HOME -d \$STOW_DIR'
alias stow-remove='stow -D -v -t \$HOME -d \$STOW_DIR'

echo "GNU Stow environment loaded!"
echo "Stow binary: \$(which stow)"
echo "Stow directory: \$STOW_DIR"
echo "Available aliases: stow-list, stow-install, stow-remove"
EOF

chmod +x "$ENV_SETUP_FILE"

# Create usage examples script
USAGE_SCRIPT="$INSTALL_PREFIX/stow_examples.sh"
print_status "Creating usage examples script: $USAGE_SCRIPT"

cat > "$USAGE_SCRIPT" << 'EOF'
#!/bin/bash
# GNU Stow usage examples

echo "=== GNU Stow Usage Examples ==="
echo
echo "1. BASIC SETUP:"
echo "   mkdir -p ~/stow"
echo "   cd ~/stow"
echo
echo "2. INSTALL A PACKAGE (like libevent):"
echo "   # Move your compiled software to stow directory"
echo "   mv ~/local ~/stow/libevent"
echo "   # Use stow to create symlinks"
echo "   stow -t $HOME libevent"
echo
echo "3. LIST WHAT WOULD BE INSTALLED (dry run):"
echo "   stow -n -v -t $HOME libevent"
echo
echo "4. REMOVE A PACKAGE:"
echo "   stow -D -t $HOME libevent"
echo
echo "5. RE-INSTALL AFTER UPDATES:"
echo "   stow -R -t $HOME libevent"
echo
echo "6. INSTALL TO CUSTOM TARGET:"
echo "   stow -t /usr/local libevent"
echo
echo "=== PRACTICAL WORKFLOW ==="
echo "Instead of installing to ~/local, install each package to ~/stow/PACKAGE_NAME"
echo "Then use stow to manage symlinks to your home directory"
echo
echo "Example for libevent:"
echo "  ./configure --prefix=$HOME/stow/libevent"
echo "  make && make install"
echo "  cd ~/stow"
echo "  stow libevent  # Creates symlinks in ~/bin, ~/lib, ~/include"
echo
echo "Benefits:"
echo "- Easy to remove packages completely"
echo "- No conflicts between different versions"
echo "- Clean separation of installed software"
echo "- Easy to see what's installed: ls ~/stow"
EOF

chmod +x "$USAGE_SCRIPT"

# Test installation
print_status "Testing installation..."
if command_exists "$INSTALL_PREFIX/bin/stow"; then
    STOW_VERSION_INSTALLED=$("$INSTALL_PREFIX/bin/stow" --version | head -1)
    print_status "Installation verified: $STOW_VERSION_INSTALLED"
else
    print_warning "Installation may have issues - stow binary not found"
fi

echo
print_status "=== SETUP COMPLETE ==="
print_status "Stow installed to: $INSTALL_PREFIX/bin/stow"
print_status "Stow directory: $STOW_DIR"
echo

print_tip "TO GET STARTED:"
echo "1. Load the environment:"
echo "   source $ENV_SETUP_FILE"
echo
echo "2. View usage examples:"
echo "   bash $USAGE_SCRIPT"
echo
echo "3. Quick test:"
echo "   stow --version"
echo

print_tip "INTEGRATION WITH LIBEVENT:"
echo "Instead of building libevent to ~/local, build it to ~/stow/libevent:"
echo "  # In your libevent build script, change:"
echo "  INSTALL_PREFIX=\"\$HOME/stow/libevent\""
echo "  # Then after building:"
echo "  cd ~/stow && stow libevent"
echo

print_tip "MAKE IT PERMANENT:"
echo "Add to ~/.bashrc:"
echo "  echo 'source $ENV_SETUP_FILE' >> ~/.bashrc"
echo

print_status "GNU Stow build script completed!"
