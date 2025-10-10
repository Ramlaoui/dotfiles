#!/bin/bash

# Build Berkeley Yacc (byacc) from source
# This script downloads, compiles, and installs byacc

set -e  # Exit on any error

# Configuration
YACC_VERSION="20240109"
YACC_URL="https://invisible-mirror.net/archives/byacc/byacc-${YACC_VERSION}.tgz"
BUILD_DIR="/tmp/yacc-build"
INSTALL_PREFIX="$HOME/local"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if running as root for system-wide install
check_permissions() {
    if [[ "$INSTALL_PREFIX" == "/usr/local" ]] && [[ $EUID -ne 0 ]]; then
        warn "Installing to $INSTALL_PREFIX requires root privileges"
        warn "Run with sudo or change INSTALL_PREFIX in the script"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Check for required tools
check_dependencies() {
    log "Checking dependencies..."
    
    for cmd in wget tar gcc make; do
        if ! command -v "$cmd" &> /dev/null; then
            error "Required command '$cmd' not found. Please install it first."
        fi
    done
    
    log "All dependencies found"
}

# Download and extract source
download_source() {
    log "Creating build directory: $BUILD_DIR"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    log "Downloading byacc-${YACC_VERSION}..."
    wget -q --show-progress "$YACC_URL" || error "Failed to download yacc source"
    
    log "Extracting archive..."
    tar -xzf "byacc-${YACC_VERSION}.tgz" || error "Failed to extract archive"
    
    cd "byacc-${YACC_VERSION}"
}

# Configure build
configure_build() {
    log "Configuring build..."
    
    if [[ ! -f "configure" ]]; then
        error "Configure script not found"
    fi
    
    ./configure --prefix="$INSTALL_PREFIX" \
                --program-prefix="" \
                --enable-btyacc \
                || error "Configuration failed"
}

# Compile
compile() {
    log "Compiling yacc..."
    
    # Get number of CPU cores for parallel build
    CORES=$(nproc 2>/dev/null || echo 1)
    
    make -j"$CORES" || error "Compilation failed"
    
    log "Compilation successful"
}

# Install
install_yacc() {
    log "Installing yacc to $INSTALL_PREFIX..."
    
    if [[ "$INSTALL_PREFIX" == "/usr/local" ]] && [[ $EUID -ne 0 ]]; then
        warn "Attempting install without root privileges"
    fi
    
    make install || error "Installation failed"
    
    log "Installation completed"
}

# Verify installation
verify_installation() {
    log "Verifying installation..."
    
    if command -v yacc &> /dev/null; then
        VERSION_OUTPUT=$(yacc -V 2>&1 | head -1 || echo "Unknown version")
        log "yacc installed successfully: $VERSION_OUTPUT"
        log "Location: $(which yacc)"
    else
        error "yacc command not found after installation"
    fi
}

# Cleanup
cleanup() {
    log "Cleaning up build directory..."
    rm -rf "$BUILD_DIR"
    log "Cleanup completed"
}

# Main execution
main() {
    log "Starting yacc build process..."
    
    check_permissions
    check_dependencies
    download_source
    configure_build
    compile
    install_yacc
    verify_installation
    cleanup
    
    log "yacc build and installation completed successfully!"
    log "You can now use 'yacc' command to generate parsers"
}

# Handle script interruption
trap 'error "Script interrupted"' INT TERM

# Run main function
main "$@"
