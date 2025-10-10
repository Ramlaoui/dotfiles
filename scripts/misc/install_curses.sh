#!/bin/bash

# Build ncurses (curses library) from source
# This script downloads, compiles, and installs ncurses

set -e  # Exit on any error

# Configuration
NCURSES_VERSION="6.4"
NCURSES_URL="https://ftp.gnu.org/gnu/ncurses/ncurses-${NCURSES_VERSION}.tar.gz"
BUILD_DIR="/tmp/ncurses-build"
INSTALL_PREFIX="$HOME/local"

# Build options
ENABLE_WIDEC=true      # Enable wide character support
ENABLE_SHARED=true     # Build shared libraries
ENABLE_STATIC=true     # Build static libraries
ENABLE_TERMCAP=true    # Enable termcap compatibility

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

info() {
    echo -e "${BLUE}[DETAIL]${NC} $1"
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
    
    local deps=(wget tar gcc make)
    
    # Optional but recommended
    local optional_deps=(pkg-config)
    
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            error "Required command '$cmd' not found. Please install it first."
        fi
    done
    
    for cmd in "${optional_deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            warn "Optional dependency '$cmd' not found (recommended)"
        fi
    done
    
    log "Dependency check completed"
}

# Download and extract source
download_source() {
    log "Creating build directory: $BUILD_DIR"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    log "Downloading ncurses-${NCURSES_VERSION}..."
    wget -q --show-progress "$NCURSES_URL" || error "Failed to download ncurses source"
    
    log "Extracting archive..."
    tar -xzf "ncurses-${NCURSES_VERSION}.tar.gz" || error "Failed to extract archive"
    
    cd "ncurses-${NCURSES_VERSION}"
}

# Configure build
configure_build() {
    log "Configuring build..."
    
    if [[ ! -f "configure" ]]; then
        error "Configure script not found"
    fi
    
    # Build configure options
    local config_opts=(
        "--prefix=$INSTALL_PREFIX"
        "--enable-pc-files"
        "--with-pkg-config-libdir=$INSTALL_PREFIX/lib/pkgconfig"
        "--with-default-terminfo-dir=$INSTALL_PREFIX/share/terminfo"
        "--with-terminfo-dirs=$INSTALL_PREFIX/share/terminfo:/etc/terminfo:/lib/terminfo:/usr/share/terminfo"
        "--disable-stripping"
        "--enable-const"
        "--enable-ext-colors"
        "--enable-ext-mouse"
        "--enable-symlinks"
    )
    
    # Add optional features
    if [[ "$ENABLE_WIDEC" == true ]]; then
        config_opts+=("--enable-widec")
        info "Enabling wide character support"
    fi
    
    if [[ "$ENABLE_SHARED" == true ]]; then
        config_opts+=("--with-shared")
        info "Enabling shared libraries"
    fi
    
    if [[ "$ENABLE_STATIC" == true ]]; then
        config_opts+=("--with-normal")
        info "Enabling static libraries"
    fi
    
    if [[ "$ENABLE_TERMCAP" == true ]]; then
        config_opts+=("--enable-termcap")
        info "Enabling termcap compatibility"
    fi
    
    # Add development options
    config_opts+=(
        "--with-debug"
        "--enable-assertions"
        "--with-develop"
    )
    
    info "Configure options: ${config_opts[*]}"
    
    ./configure "${config_opts[@]}" || error "Configuration failed"
    
    log "Configuration completed"
}

# Compile
compile() {
    log "Compiling ncurses..."
    
    # Get number of CPU cores for parallel build
    CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1)
    info "Using $CORES parallel jobs"
    
    make -j"$CORES" || error "Compilation failed"
    
    log "Building additional components..."
    
    # Build examples (optional)
    if make -C test &>/dev/null; then
        info "Test programs built successfully"
    else
        warn "Test programs build failed (non-critical)"
    fi
    
    log "Compilation successful"
}

# Run tests (optional)
run_tests() {
    log "Running basic tests..."
    
    # Basic compilation test
    if [[ -f "lib/libncurses.a" ]] || [[ -f "lib/libncurses.so" ]]; then
        info "Library files created successfully"
    else
        warn "Library files not found where expected"
    fi
    
    # Test ncurses-config if built
    if [[ -f "misc/ncurses-config" ]]; then
        info "ncurses-config utility available"
    fi
    
    log "Basic tests completed"
}

# Install
install_ncurses() {
    log "Installing ncurses to $INSTALL_PREFIX..."
    
    if [[ "$INSTALL_PREFIX" == "/usr/local" ]] && [[ $EUID -ne 0 ]]; then
        warn "Attempting install without root privileges"
    fi
    
    make install || error "Installation failed"
    
    # Install additional terminfo entries
    log "Installing terminfo database..."
    make install.data || warn "Terminfo installation had issues (non-critical)"
    
    # Create symlinks for compatibility
    create_compatibility_links
    
    log "Installation completed"
}

# Create compatibility symlinks
create_compatibility_links() {
    log "Creating compatibility symlinks..."
    
    cd "$INSTALL_PREFIX/lib"
    
    # Link libcurses to libncurses for compatibility
    if [[ -f "libncurses.so" ]] && [[ ! -e "libcurses.so" ]]; then
        ln -sf libncurses.so libcurses.so
        info "Created libcurses.so -> libncurses.so"
    fi
    
    if [[ -f "libncurses.a" ]] && [[ ! -e "libcurses.a" ]]; then
        ln -sf libncurses.a libcurses.a  
        info "Created libcurses.a -> libncurses.a"
    fi
    
    # Wide character versions
    if [[ "$ENABLE_WIDEC" == true ]]; then
        if [[ -f "libncursesw.so" ]] && [[ ! -e "libcursesw.so" ]]; then
            ln -sf libncursesw.so libcursesw.so
            info "Created libcursesw.so -> libncursesw.so"
        fi
        
        if [[ -f "libncursesw.a" ]] && [[ ! -e "libcursesw.a" ]]; then
            ln -sf libncursesw.a libcursesw.a
            info "Created libcursesw.a -> libncursesw.a"
        fi
    fi
}

# Update library cache
update_library_cache() {
    log "Updating library cache..."
    
    # Update ld cache if ldconfig exists
    if command -v ldconfig &> /dev/null; then
        if [[ $EUID -eq 0 ]]; then
            ldconfig
            info "Library cache updated"
        else
            warn "Run 'sudo ldconfig' to update library cache"
        fi
    fi
    
    # Update pkg-config cache
    if command -v pkg-config &> /dev/null; then
        export PKG_CONFIG_PATH="$INSTALL_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
        info "Add $INSTALL_PREFIX/lib/pkgconfig to PKG_CONFIG_PATH"
    fi
}

# Verify installation
verify_installation() {
    log "Verifying installation..."
    
    # Check for libraries
    local lib_found=false
    for lib in "$INSTALL_PREFIX/lib/libncurses"*; do
        if [[ -f "$lib" ]]; then
            info "Found: $(basename "$lib")"
            lib_found=true
        fi
    done
    
    if [[ "$lib_found" == false ]]; then
        error "No ncurses libraries found after installation"
    fi
    
    # Check for headers
    if [[ -f "$INSTALL_PREFIX/include/curses.h" ]]; then
        info "Header file: $INSTALL_PREFIX/include/curses.h"
    else
        warn "curses.h header not found"
    fi
    
    # Check ncurses-config
    if [[ -f "$INSTALL_PREFIX/bin/ncurses6-config" ]]; then
        info "Configuration utility: $INSTALL_PREFIX/bin/ncurses6-config"
        "$INSTALL_PREFIX/bin/ncurses6-config" --version
    fi
    
    # Test basic compilation
    test_compilation
    
    log "Verification completed"
}

# Test compilation with installed library
test_compilation() {
    log "Testing compilation with installed ncurses..."
    
    local test_file="/tmp/ncurses_test.c"
    cat > "$test_file" << 'EOF'
#include <curses.h>
#include <stdio.h>

int main() {
    printf("ncurses version: %s\n", curses_version());
    return 0;
}
EOF
    
    if gcc -I"$INSTALL_PREFIX/include" -L"$INSTALL_PREFIX/lib" \
           -o /tmp/ncurses_test "$test_file" -lncurses 2>/dev/null; then
        info "Test compilation successful"
        if /tmp/ncurses_test 2>/dev/null; then
            info "Test execution successful"
        fi
        rm -f /tmp/ncurses_test
    else
        warn "Test compilation failed (may need to update library paths)"
    fi
    
    rm -f "$test_file"
}

# Cleanup
cleanup() {
    log "Cleaning up build directory..."
    rm -rf "$BUILD_DIR"
    log "Cleanup completed"
}

# Display usage information
show_usage_info() {
    log "ncurses installation completed successfully!"
    echo
    info "Usage information:"
    echo "  - Include path: $INSTALL_PREFIX/include"
    echo "  - Library path: $INSTALL_PREFIX/lib"
    echo "  - Compile with: gcc -I$INSTALL_PREFIX/include -L$INSTALL_PREFIX/lib -lncurses"
    echo "  - For wide chars: gcc -I$INSTALL_PREFIX/include -L$INSTALL_PREFIX/lib -lncursesw"
    echo
    if [[ "$INSTALL_PREFIX" != "/usr" ]] && [[ "$INSTALL_PREFIX" != "/usr/local" ]]; then
:        warn "Add these to your environment:"
        echo "  export LD_LIBRARY_PATH=$INSTALL_PREFIX/lib:\$LD_LIBRARY_PATH"
        echo "  export PKG_CONFIG_PATH=$INSTALL_PREFIX/lib/pkgconfig:\$PKG_CONFIG_PATH"
    fi
}

# Main execution
main() {
    log "Starting ncurses build process..."
    
    check_permissions
    check_dependencies
    download_source
    configure_build
    compile
    run_tests
    install_ncurses
    update_library_cache
    verify_installation
    cleanup
    show_usage_info
}

# Handle script interruption
trap 'error "Script interrupted"' INT TERM

# Run main function
main "$@"
