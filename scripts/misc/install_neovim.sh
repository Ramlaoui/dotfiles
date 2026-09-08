#!/usr/bin/env bash
# Install an official Neovim release archive without sudo.
# The archive is verified against the checksum published on the release page
# before extraction. Each release remains self-contained under --prefix.

set -o pipefail

PROGRAM=${0##*/}
SCRIPT_PATH=${BASH_SOURCE[0]}
SCRIPT_DIR=${SCRIPT_PATH%/*}
[ "$SCRIPT_DIR" = "$SCRIPT_PATH" ] && SCRIPT_DIR=.
SCRIPT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR" 2>/dev/null && pwd -P)" || exit 1
COMMON="$SCRIPT_DIR/../installs/source-common.sh"
[ -r "$COMMON" ] || {
    printf '%s\n' "$PROGRAM: shared source mechanics are missing: $COMMON" >&2
    exit 1
}
# shellcheck source=/dev/null
. "$COMMON"

PREFIX="${HOME:-}/.local"
VERSION=latest
SHOW_HELP=false
BUILD_ROOT=""
DOWNLOADS=""
STAGING_DIR=""
TAG=""
TARGET_OS=""
TARGET_ARCH=""
ARCHIVE=""
ARCHIVE_ROOT=""
ARCHIVE_URL=""
ASSET_METADATA_URL=""
CHECKSUM=""
INSTALL_ROOT=""
BIN_LINK=""
LINK_PATH=""
LINK_TMP=""
RELATIVE_TARGET=""
ROOT_MOVED=false
LINK_SWAP_DONE=false

print_usage() {
    cat <<EOF
Usage: $PROGRAM [options]

Install the official Neovim binary archive into a private prefix.

Options:
  --prefix PATH      Installation prefix (default: \$HOME/.local)
  --version VERSION  Release tag/version, or latest (default: latest)
  -h, --help         Show this help

The managed binary is linked at PATH/bin/nvim. Existing unrelated files and
symlinks are never adopted, overwritten, or deleted.
EOF
}

fail() {
    printf '%s: %s\n' "$PROGRAM" "$1" >&2
    exit 1
}

cleanup() {
    local status=$?

    if [ -n "$LINK_TMP" ]; then
        rm -f "$LINK_TMP" 2>/dev/null || :
    fi
    if [ -n "$STAGING_DIR" ]; then
        rm -rf "$STAGING_DIR" 2>/dev/null || :
    fi
    if [ "$ROOT_MOVED" = true ] && [ "$LINK_SWAP_DONE" != true ]; then
        rm -rf "$INSTALL_ROOT" 2>/dev/null || :
    fi

    if [ -n "$BUILD_ROOT" ]; then
        source_common_cleanup "$BUILD_ROOT"
    fi

    return "$status"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

while [ "$#" -gt 0 ]; do
    case "$1" in
        --prefix)
            [ "$#" -ge 2 ] || fail '--prefix requires a path'
            PREFIX=$2
            shift 2
            ;;
        --version)
            [ "$#" -ge 2 ] || fail '--version requires a release version or latest'
            VERSION=$2
            shift 2
            ;;
        -h|--help)
            SHOW_HELP=true
            shift
            ;;
        *)
            fail "unknown argument: $1 (use --help)"
            ;;
    esac
done

if [ "$SHOW_HELP" = true ]; then
    print_usage
    exit 0
fi

[ -n "$HOME" ] 2>/dev/null || fail 'HOME must be set'
source_common_validate_prefix "$PREFIX" || exit 1

command -v tar >/dev/null 2>&1 || fail 'required command not found: tar'
command -v mktemp >/dev/null 2>&1 || fail 'required command not found: mktemp'
command -v awk >/dev/null 2>&1 || fail 'required command not found: awk'
command -v readlink >/dev/null 2>&1 || fail 'required command not found: readlink'
command -v curl >/dev/null 2>&1 || fail 'curl is required to resolve official release metadata'
if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
    fail 'sha256sum or shasum is required to verify the release archive'
fi

TARGET_OS=$(uname -s 2>/dev/null || printf unknown)
case "$TARGET_OS" in
    Linux) TARGET_OS=linux ;;
    Darwin) TARGET_OS=macos ;;
    *) fail "unsupported operating system: $TARGET_OS (only Linux and macOS are supported)" ;;
esac

case "$(uname -m 2>/dev/null || printf unknown)" in
    x86_64|amd64) TARGET_ARCH=x86_64 ;;
    arm64|aarch64) TARGET_ARCH=arm64 ;;
    *) fail "unsupported architecture: $(uname -m 2>/dev/null || printf unknown) (only x86_64 and arm64 are supported)" ;;
esac

# Keep tags safe for use in release URLs and versioned directory names. The
# optional leading v is canonical for Neovim release tags.
case "$VERSION" in
    latest|latest-stable) ;;
    v*)
        TAG=$VERSION
        ;;
    '')
        fail '--version must not be empty'
        ;;
    *)
        TAG=v$VERSION
        ;;
esac
if [ -z "$TAG" ]; then
    LATEST_URL='https://github.com/neovim/neovim/releases/latest'
    EFFECTIVE_URL=$(curl --fail --location --silent --show-error --output /dev/null --write-out '%{url_effective}' "$LATEST_URL") || fail "could not resolve the latest Neovim release: $LATEST_URL"
    case "$EFFECTIVE_URL" in
        https://github.com/neovim/neovim/releases/tag/*)
            TAG=${EFFECTIVE_URL##*/}
            ;;
        *)
            fail "latest Neovim release resolved to an unexpected URL: $EFFECTIVE_URL"
            ;;
    esac
fi

# Reject URL/path metacharacters even when a caller supplied a tag directly.
case "$TAG" in
    v[0-9]*|[0-9]*) ;;
    *) fail "invalid Neovim release version: $VERSION" ;;
esac
case "$TAG" in
    */*|*[!A-Za-z0-9._+-]*) fail "invalid Neovim release version: $VERSION" ;;
esac

ARCHIVE="nvim-$TARGET_OS-$TARGET_ARCH.tar.gz"
ARCHIVE_ROOT=${ARCHIVE%.tar.gz}
ARCHIVE_URL="https://github.com/neovim/neovim/releases/download/$TAG/$ARCHIVE"
ASSET_METADATA_URL="https://github.com/neovim/neovim/releases/expanded_assets/$TAG"

BUILD_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/install-neovim.XXXXXX") || fail 'cannot create a private build directory'
DOWNLOADS="$BUILD_ROOT/downloads"
mkdir -p "$DOWNLOADS" || fail 'cannot initialize the private download directory'

# GitHub publishes per-asset SHA256 values in the official expanded release
# page. This avoids the unauthenticated API and works for latest and exact tags.
metadata="$DOWNLOADS/release-assets.html"
source_common_download "$ASSET_METADATA_URL" "$metadata" || fail "could not read official release metadata for $TAG"
CHECKSUM=$(awk -v asset="$ARCHIVE" '
    index($0, asset) {
        in_asset=1
        next
    }
    in_asset && index($0, "sha256:") {
        value=$0
        sub(/^.*sha256:/, "", value)
        sub(/[^0-9A-Fa-f].*$/, "", value)
        if (length(value) == 64) {
            print tolower(value)
            exit
        }
    }
    in_asset && index($0, "releases/download/") {
        exit
    }
' "$metadata")
[ -n "$CHECKSUM" ] || fail "official release has no SHA256 metadata for $ARCHIVE (unsupported target or release: $TAG)"

archive="$DOWNLOADS/$ARCHIVE"
source_common_download "$ARCHIVE_URL" "$archive" || fail "could not download Neovim $TAG for $TARGET_OS/$TARGET_ARCH"
source_common_verify_sha256 "$archive" "$CHECKSUM" || fail "official Neovim archive verification failed for $TAG"
mkdir -p "$BUILD_ROOT/home" "$BUILD_ROOT/config" "$BUILD_ROOT/data" "$BUILD_ROOT/state" || fail 'cannot initialize the private Neovim smoke-test home'

INSTALL_ROOT="$PREFIX/lib/nvim-$TAG"
BIN_LINK="$PREFIX/bin/nvim"
LINK_PATH="$PREFIX/bin/.nvim.new.$$"
RELATIVE_TARGET="../lib/nvim-$TAG/bin/nvim"

# Preflight every destination before mutating the prefix. Existing release
# roots are never replaced, and only links into our own lib/nvim-* tree may be
# updated.
if [ -L "$PREFIX" ]; then
    fail "refusing to follow a symlink at installation prefix: $PREFIX"
fi
if [ -e "$PREFIX" ] && [ ! -d "$PREFIX" ]; then
    fail "installation prefix is not a directory: $PREFIX"
fi
if [ -e "$PREFIX/lib" ] && [ ! -d "$PREFIX/lib" ]; then
    fail "prefix path is not a directory: $PREFIX/lib"
fi
if [ -L "$PREFIX/lib" ]; then
    fail "refusing to follow a symlink at: $PREFIX/lib"
fi
if [ -e "$PREFIX/bin" ] && [ ! -d "$PREFIX/bin" ]; then
    fail "prefix path is not a directory: $PREFIX/bin"
fi
if [ -L "$PREFIX/bin" ]; then
    fail "refusing to follow a symlink at: $PREFIX/bin"
fi

# Re-running the standalone installer for the same release is a verified
# no-op only when our exact managed link and complete runtime root are intact.
if [ -L "$INSTALL_ROOT" ]; then
    fail "refusing to follow a symlink at existing installation root: $INSTALL_ROOT"
fi
if [ -e "$INSTALL_ROOT" ]; then
    [ -d "$INSTALL_ROOT" ] || fail "installation root already exists but is not a directory: $INSTALL_ROOT"
    [ -L "$BIN_LINK" ] || fail "installation root already exists without its managed Neovim link: $INSTALL_ROOT"
    current_target=$(readlink "$BIN_LINK") || fail "cannot inspect existing Neovim link: $BIN_LINK"
    [ "$current_target" = "$RELATIVE_TARGET" ] || fail "refusing to replace existing release root with an unrelated link: $BIN_LINK -> $current_target"
    [ -x "$INSTALL_ROOT/bin/nvim" ] || fail "existing Neovim root is missing executable bin/nvim: $INSTALL_ROOT"
    [ -d "$INSTALL_ROOT/lib" ] || fail "existing Neovim root is missing lib runtime: $INSTALL_ROOT"
    [ -d "$INSTALL_ROOT/share" ] || fail "existing Neovim root is missing share runtime: $INSTALL_ROOT"
    if ! (
        unset VIM VIMRUNTIME
        HOME="$BUILD_ROOT/home" XDG_CONFIG_HOME="$BUILD_ROOT/config" XDG_DATA_HOME="$BUILD_ROOT/data" XDG_STATE_HOME="$BUILD_ROOT/state" "$INSTALL_ROOT/bin/nvim" --headless -u NONE -n +'qa!' >"$BUILD_ROOT/existing.stdout" 2>"$BUILD_ROOT/existing.stderr"
    ); then
        fail "existing Neovim root is not functional: $INSTALL_ROOT"
    fi
    printf '%s\n' "Neovim $TAG is already installed and verified at $INSTALL_ROOT"
    printf '%s\n' "Managed binary link: $BIN_LINK -> $RELATIVE_TARGET"
    printf '%s\n' "Verified SHA256: $CHECKSUM"
    printf '%s\n' "Add this directory to PATH: $PREFIX/bin"
    exit 0
fi

if [ -e "$BIN_LINK" ] || [ -L "$BIN_LINK" ]; then
    [ -L "$BIN_LINK" ] || fail "refusing to overwrite existing non-managed file: $BIN_LINK"
    current_target=$(readlink "$BIN_LINK") || fail "cannot inspect existing Neovim link: $BIN_LINK"
    case "$current_target" in
        "$PREFIX/lib/"nvim-*/bin/nvim|../lib/nvim-*/bin/nvim) ;;
        *) fail "refusing to overwrite unrelated Neovim symlink: $BIN_LINK -> $current_target" ;;
    esac
fi
[ ! -e "$LINK_PATH" ] && [ ! -L "$LINK_PATH" ] || fail "temporary link path already exists: $LINK_PATH"

mkdir -p "$PREFIX/lib" "$PREFIX/bin" || fail "could not create installation directories under: $PREFIX"
STAGING_DIR=$(mktemp -d "$PREFIX/lib/.nvim-$TAG.XXXXXX") || fail "could not create private staging directory under: $PREFIX/lib"

# The archive is already verified. Extract directly into a private directory on
# the destination filesystem, then rename the complete tree into place.
source_common_extract "$archive" "$STAGING_DIR" "$ARCHIVE_ROOT" || fail "could not extract official Neovim archive $ARCHIVE"
candidate="$STAGING_DIR/$ARCHIVE_ROOT"
[ -x "$candidate/bin/nvim" ] || fail "official Neovim archive has no executable bin/nvim"
[ -d "$candidate/lib" ] || fail "official Neovim archive is missing its lib runtime directory"
[ -d "$candidate/share" ] || fail "official Neovim archive is missing its share runtime directory"

# A clean headless invocation catches an unusable libc/loader or broken runtime
# before anything is copied into the user's prefix. Never fall back to AppImage.
if ! (
    unset VIM VIMRUNTIME
    HOME="$BUILD_ROOT/home" XDG_CONFIG_HOME="$BUILD_ROOT/config" XDG_DATA_HOME="$BUILD_ROOT/data" XDG_STATE_HOME="$BUILD_ROOT/state" "$candidate/bin/nvim" --headless -u NONE -n +'qa!' >"$BUILD_ROOT/nvim.stdout" 2>"$BUILD_ROOT/nvim.stderr"
); then
    printf '%s\n' "Official Neovim $TAG cannot run on this host; refusing to install it." >&2
    sed -n '1,12p' "$BUILD_ROOT/nvim.stderr" >&2 || :
    fail 'the downloaded binary is not functional on this host (libc/loader/runtime incompatibility)'
fi

mv "$candidate" "$INSTALL_ROOT" || fail "could not place Neovim $TAG at: $INSTALL_ROOT"
STAGING_DIR=""
ROOT_MOVED=true

# Link creation happens in the same directory as the managed destination; mv
# replaces only the preflight-approved managed link atomically.
ln -s "$RELATIVE_TARGET" "$LINK_PATH" || fail "could not create the managed Neovim link"
LINK_TMP="$LINK_PATH"
mv -f "$LINK_TMP" "$BIN_LINK" || fail "could not activate the managed Neovim link"
LINK_TMP=""
LINK_SWAP_DONE=true

printf '%s\n' "Installed Neovim $TAG ($TARGET_OS/$TARGET_ARCH) at $INSTALL_ROOT"
printf '%s\n' "Managed binary link: $BIN_LINK -> $RELATIVE_TARGET"
printf '%s\n' "Verified SHA256: $CHECKSUM"
printf '%s\n' "Add this directory to PATH: $PREFIX/bin"
