#!/bin/bash

# libevent build script
# This script downloads, compiles, and installs libevent from source

set -e  # Exit on any error

# Configuration
LIBEVENT_VERSION="2.1.12-stable"
INSTALL_PREFIX="$HOME/local"  # Change this to wherever you want to install
BUILD_DIR="/tmp/libevent-build-$$"  # Unique build directory

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for required tools
print_status "Checking for required build tools..."
MISSING_TOOLS=""

for tool in wget tar gcc make; do
    if ! command_exists "$tool"; then
        MISSING_TOOLS="$MISSING_TOOLS $tool"
    fi
done

if [ -n "$MISSING_TOOLS" ]; then
    print_error "Missing required tools:$MISSING_TOOLS"
    print_error "Please install them first. On most systems:"
    print_error "  Ubuntu/Debian: sudo apt-get install build-essential wget"
    print_error "  CentOS/RHEL:   sudo yum install gcc make wget tar"
    exit 1
fi

print_status "All required tools found."

# Create install directory
print_status "Creating install directory: $INSTALL_PREFIX"
mkdir -p "$INSTALL_PREFIX"

# Create temporary build directory
print_status "Creating build directory: $BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Download libevent
print_status "Downloading libevent $LIBEVENT_VERSION..."
DOWNLOAD_URL="https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}/libevent-${LIBEVENT_VERSION}.tar.gz"
wget "$DOWNLOAD_URL" -O "libevent-${LIBEVENT_VERSION}.tar.gz"

# Extract
print_status "Extracting source code..."
tar -xzf "libevent-${LIBEVENT_VERSION}.tar.gz"
cd "libevent-${LIBEVENT_VERSION}"

# Configure, compile, and install
print_status "Configuring build..."
./configure --prefix="$INSTALL_PREFIX" --enable-shared --enable-static

print_status "Compiling (this may take a few minutes)..."
make -j$(nproc 2>/dev/null || echo 4)  # Use all cores, fallback to 4

print_status "Installing to $INSTALL_PREFIX..."
make install

# Clean up
print_status "Cleaning up build directory..."
cd /
rm -rf "$BUILD_DIR"

print_status "libevent installation completed successfully!"
echo
print_status "Installation location: $INSTALL_PREFIX"
print_status "Library files: $INSTALL_PREFIX/lib"
print_status "Header files: $INSTALL_PREFIX/include"
echo

# Generate environment setup
ENV_SETUP_FILE="$INSTALL_PREFIX/setup_libevent_env.sh"
print_status "Creating environment setup script: $ENV_SETUP_FILE"

cat > "$ENV_SETUP_FILE" << 'EOF'
#!/bin/bash
# Source this file to set up libevent environment
# Usage: source setup_libevent_env.sh

LIBEVENT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export PATH="$LIBEVENT_ROOT/bin:$PATH"
export LD_LIBRARY_PATH="$LIBEVENT_ROOT/lib:$LD_LIBRARY_PATH"
export LIBRARY_PATH="$LIBEVENT_ROOT/lib:$LIBRARY_PATH"
export CPATH="$LIBEVENT_ROOT/include:$CPATH"
export PKG_CONFIG_PATH="$LIBEVENT_ROOT/lib/pkgconfig:$PKG_CONFIG_PATH"

# For cmake
export CMAKE_PREFIX_PATH="$LIBEVENT_ROOT:$CMAKE_PREFIX_PATH"

# For autotools
export LDFLAGS="-L$LIBEVENT_ROOT/lib $LDFLAGS"
export CPPFLAGS="-I$LIBEVENT_ROOT/include $CPPFLAGS"

echo "libevent environment loaded from: $LIBEVENT_ROOT"
EOF

chmod +x "$ENV_SETUP_FILE"

echo
print_status "To use libevent in your projects:"
echo "1. Source the environment file:"
echo "   source $ENV_SETUP_FILE"
echo
echo "2. Or manually set environment variables:"
echo "   export LD_LIBRARY_PATH=\"$INSTALL_PREFIX/lib:\$LD_LIBRARY_PATH\""
echo "   export CPATH=\"$INSTALL_PREFIX/include:\$CPATH\""
echo "   export PKG_CONFIG_PATH=\"$INSTALL_PREFIX/lib/pkgconfig:\$PKG_CONFIG_PATH\""
echo
echo "3. For autotools projects, use:"
echo "   ./configure --with-libevent=$INSTALL_PREFIX"
echo
echo "4. For cmake projects, use:"
echo "   cmake -DCMAKE_PREFIX_PATH=$INSTALL_PREFIX ..."
echo

# Test installation
print_status "Testing installation..."
if [ -f "$INSTALL_PREFIX/lib/libevent.so" ] && [ -f "$INSTALL_PREFIX/include/event.h" ]; then
    print_status "Installation verified successfully!"
    
    # Show version
    if [ -f "$INSTALL_PREFIX/bin/event_rpcgen.py" ]; then
        VERSION_INFO=$("$INSTALL_PREFIX/lib/libevent.so" 2>/dev/null | head -1 || echo "Version check failed")
        print_status "Installed version info available in library"
    fi
else
    print_warning "Installation may have issues - some files not found"
fi

print_status "Build script completed!"
