#!/usr/bin/env bash
# Install the official prebuilt uv and uvx binaries without sudo or Python.
#
# The release archive and detached SHA-256 metadata are downloaded from
# Astral's official release mirror.  A complete versioned tree is staged before
# any managed links are changed, so failures leave the previous installation
# untouched.

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
PREFIX_ARG_SET=false
VERSION=""
VERSION_ARG_SET=false
SHOW_HELP=false
BUILD_ROOT=""
DOWNLOADS=""
SOURCES=""
INSTALL_ROOT=""
COMMIT_ROOT=""
LINK_STAGE_UV=""
LINK_STAGE_UVX=""
COMMIT_ROOT_CREATED=false
ROOT_CREATED=false
INSTALL_SUCCEEDED=false
UV_LINK_STAGE_CREATED=false
UVX_LINK_STAGE_CREATED=false
UV_LINK_INSTALLED=false
UVX_LINK_INSTALLED=false
OLD_UV_PRESENT=false
OLD_UVX_PRESENT=false
OLD_UV_TARGET=""
OLD_UVX_TARGET=""

TARGET_OS=""
TARGET_ARCH=""
TARGET_TRIPLE=""
UV_VERSION=""
UV_ARCHIVE=""
UV_ARCHIVE_URL=""
UV_CHECKSUM_URL=""
EXPECTED_LINK_UV=""
EXPECTED_LINK_UVX=""

print_usage() {
    cat <<EOF
Usage: $PROGRAM [--prefix PATH] [--version VERSION]

Install official prebuilt uv and uvx binaries without sudo or Python.
The default installation prefix is:
  $PREFIX

Options:
  --prefix PATH       Install into an absolute path without whitespace.
  --version VERSION   Install this exact uv release (default: latest stable).
  -h, --help          Show this help and exit without network access.

Supported targets: Linux GNU or musl and macOS, x86_64 or arm64/aarch64,
when the corresponding official uv release asset exists.  The script installs
both binaries below PREFIX/lib/uv-VERSION and manages PREFIX/bin/uv and
PREFIX/bin/uvx relative links.  It never edits shell startup files or PATH.

Required commands: tar, mktemp, mkdir, cp, mv, rm, ln, readlink, chmod, sed,
tr, and curl or wget.  SHA-256 verification requires sha256sum (Linux) or
shasum (macOS).
EOF
}

fail() {
    printf '%s: %s\n' "$PROGRAM" "$1" >&2
    exit 1
}

cleanup() {
    status=$?
    # Remove only paths this invocation successfully created.  In particular,
    # INSTALL_ROOT is never removed merely because its path was inspected.
    if [ "$ROOT_CREATED" = true ] && [ "$INSTALL_SUCCEEDED" != true ] && [ -n "$INSTALL_ROOT" ]; then
        rm -rf "$INSTALL_ROOT"
    fi
    if [ "$COMMIT_ROOT_CREATED" = true ] && [ -n "$COMMIT_ROOT" ]; then
        rm -rf "$COMMIT_ROOT"
    fi
    if [ "$UV_LINK_STAGE_CREATED" = true ] && [ -n "$LINK_STAGE_UV" ]; then
        rm -f "$LINK_STAGE_UV"
    fi
    if [ "$UVX_LINK_STAGE_CREATED" = true ] && [ -n "$LINK_STAGE_UVX" ]; then
        rm -f "$LINK_STAGE_UVX"
    fi
    source_common_cleanup "$BUILD_ROOT"
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

while [ "$#" -gt 0 ]; do
    case "$1" in
        --prefix)
            [ "$#" -ge 2 ] || fail '--prefix requires a path'
            PREFIX="$2"
            PREFIX_ARG_SET=true
            shift
            ;;
        --prefix=*) PREFIX=${1#--prefix=}; PREFIX_ARG_SET=true ;;
        --version)
            [ "$#" -ge 2 ] || fail '--version requires a release version'
            VERSION="$2"
            VERSION_ARG_SET=true
            shift
            ;;
        --version=*) VERSION=${1#--version=}; VERSION_ARG_SET=true ;;
        -h|--help) SHOW_HELP=true ;;
        --) shift; [ "$#" -eq 0 ] || fail 'unexpected positional argument' ;;
        *) fail "unknown option: $1 (use --help for usage)" ;;
    esac
    shift
done

if [ "$SHOW_HELP" = true ]; then
    print_usage
    exit 0
fi
if [ "$PREFIX_ARG_SET" != true ] && [ -z "${HOME:-}" ]; then
    fail 'HOME must be set when --prefix is not provided'
fi
source_common_validate_prefix "$PREFIX" || exit 1
case "$VERSION" in
    ''|*[!A-Za-z0-9._-]*)
        [ -z "$VERSION" ] || fail "invalid uv version: $VERSION"
        ;;
esac
# Release tags currently omit the conventional leading v.  Accept it for
# convenience while keeping the URL and versioned root canonical.
case "$VERSION" in
    v*) VERSION=${VERSION#v} ;;
esac
if [ "$VERSION_ARG_SET" = true ] && [ -z "$VERSION" ]; then
    fail 'invalid uv version: empty release version'
fi

for command_name in tar mktemp mkdir cp mv rm ln readlink chmod sed tr; do
    command -v "$command_name" >/dev/null 2>&1 || fail "required command not found: $command_name"
done
command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || \
    fail 'curl or wget is required to download uv release assets'
command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 || \
    fail 'sha256sum or shasum is required to verify the uv release archive'

TARGET_OS=$(uname -s 2>/dev/null || printf unknown)
TARGET_ARCH=$(uname -m 2>/dev/null || printf unknown)
case "$TARGET_OS" in
    Linux)
        case "$TARGET_ARCH" in
            x86_64|amd64) TARGET_TRIPLE=x86_64-unknown-linux-gnu ;;
            aarch64|arm64) TARGET_TRIPLE=aarch64-unknown-linux-gnu ;;
            *) fail "unsupported Linux architecture: $TARGET_ARCH (uv supports x86_64 and aarch64 here)" ;;
        esac
        # A musl dynamic linker is unambiguous even when ldd is a BusyBox
        # wrapper.  ldd output covers distributions where the loader path is
        # not under /lib or /lib64.
        for musl_loader in /lib/ld-musl-*.so.1 /lib64/ld-musl-*.so.1; do
            if [ -e "$musl_loader" ]; then
                TARGET_TRIPLE=${TARGET_TRIPLE%-gnu}-musl
                break
            fi
        done
        if [ "${TARGET_TRIPLE##*-}" = gnu ] && command -v ldd >/dev/null 2>&1; then
            LDD_VERSION=$(ldd --version 2>&1 || true)
            case "$LDD_VERSION" in
                *musl*|*Musl*|*MUSL*) TARGET_TRIPLE=${TARGET_TRIPLE%-gnu}-musl ;;
            esac
        fi
        ;;
    Darwin|macOS)
        case "$TARGET_ARCH" in
            x86_64|amd64) TARGET_TRIPLE=x86_64-apple-darwin ;;
            arm64|aarch64) TARGET_TRIPLE=aarch64-apple-darwin ;;
            *) fail "unsupported macOS architecture: $TARGET_ARCH (uv supports x86_64 and arm64 here)" ;;
        esac
        ;;
    *)
        fail "unsupported operating system: $TARGET_OS (uv supports Linux and macOS here)"
        ;;
esac

BUILD_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/install-uv.XXXXXX") || fail 'cannot create a private staging directory'
DOWNLOADS="$BUILD_ROOT/downloads"
SOURCES="$BUILD_ROOT/sources"
mkdir -p "$DOWNLOADS" "$SOURCES" || fail 'cannot initialize the private staging directory'

if [ -n "$VERSION" ]; then
    UV_VERSION="$VERSION"
else
    LATEST_PAGE="$DOWNLOADS/latest.html"
    source_common_download 'https://github.com/astral-sh/uv/releases/latest' "$LATEST_PAGE" || \
        fail 'could not discover the latest stable uv release'
    UV_VERSION=$(sed -n 's#.*astral-sh/uv/releases/tag/\([^"<>/?[:space:]]*\).*#\1#p' "$LATEST_PAGE" | sed -n '1p')
    case "$UV_VERSION" in
        v*) UV_VERSION=${UV_VERSION#v} ;;
    esac
    [ -n "$UV_VERSION" ] || fail 'latest uv release page did not contain a stable release tag'
    case "$UV_VERSION" in
        *[!A-Za-z0-9._-]*) fail "latest uv release has an invalid version: $UV_VERSION" ;;
    esac
fi

INSTALL_ROOT="$PREFIX/lib/uv-$UV_VERSION"
EXPECTED_LINK_UV="../lib/uv-$UV_VERSION/uv"
EXPECTED_LINK_UVX="../lib/uv-$UV_VERSION/uvx"

# Refuse symlinked installation directories, matching the Go installer.  This
# prevents a collision from redirecting writes outside the requested prefix.
for container in "$PREFIX/bin" "$PREFIX/lib"; do
    if [ -L "$container" ]; then
        fail "refusing symlinked installation directory: $container"
    fi
    if [ -e "$container" ] && [ ! -d "$container" ]; then
        fail "installation path is not a directory: $container"
    fi
done

link_matches() {
    local path="$1"
    local expected="$2"
    [ -L "$path" ] || return 1
    [ "$(readlink "$path" 2>/dev/null)" = "$expected" ]
}

validate_link_slot() {
    local path="$1"
    local name="$2"
    local target
    if [ -e "$path" ] || [ -L "$path" ]; then
        [ -L "$path" ] || fail "refusing unrelated existing file at $path"
        target=$(readlink "$path") || fail "cannot inspect existing managed link: $path"
        case "$target" in
            ../lib/uv-*/$name) ;;
            *) fail "refusing unrelated existing symlink at $path" ;;
        esac
    fi
}

# A complete same-version install with both exact managed links is idempotent.
# Any other existing root is refused before downloads or filesystem mutation.
if [ -L "$INSTALL_ROOT" ]; then
    fail "refusing symlinked uv root: $INSTALL_ROOT"
fi
if [ -e "$INSTALL_ROOT" ]; then
    [ -d "$INSTALL_ROOT" ] || fail "existing uv root is not a directory: $INSTALL_ROOT"
    [ -x "$INSTALL_ROOT/uv" ] && [ -x "$INSTALL_ROOT/uvx" ] || \
        fail "existing uv root is incomplete: $INSTALL_ROOT"
    link_matches "$PREFIX/bin/uv" "$EXPECTED_LINK_UV" && \
        link_matches "$PREFIX/bin/uvx" "$EXPECTED_LINK_UVX" || \
        fail "existing uv root requires its exact managed links: $INSTALL_ROOT"
    "$INSTALL_ROOT/uv" --version >/dev/null 2>&1 || fail 'existing uv binary cannot run on this host'
    printf '%s\n' "uv $UV_VERSION is already installed at $INSTALL_ROOT"
    exit 0
fi
validate_link_slot "$PREFIX/bin/uv" uv
validate_link_slot "$PREFIX/bin/uvx" uvx

UV_ARCHIVE="uv-$TARGET_TRIPLE.tar.gz"
UV_ARCHIVE_URL="https://releases.astral.sh/github/uv/releases/download/$UV_VERSION/$UV_ARCHIVE"
UV_CHECKSUM_URL="$UV_ARCHIVE_URL.sha256"
ARCHIVE="$DOWNLOADS/$UV_ARCHIVE"
CHECKSUM="$DOWNLOADS/$UV_ARCHIVE.sha256"
printf '%s\n' "Installing uv $UV_VERSION for $TARGET_TRIPLE"
source_common_download "$UV_CHECKSUM_URL" "$CHECKSUM" || \
    fail "could not download the official SHA-256 metadata for uv $UV_VERSION"
source_common_download "$UV_ARCHIVE_URL" "$ARCHIVE" || \
    fail "could not download the official uv $UV_VERSION archive"
EXPECTED_SHA256=$(tr -s '[:space:]' '\n' < "$CHECKSUM" | sed -n '1p' | tr 'A-F' 'a-f')
case "$EXPECTED_SHA256" in
    ''|*[!A-Fa-f0-9]*) fail "official checksum metadata is malformed: $UV_CHECKSUM_URL" ;;
esac
[ "${#EXPECTED_SHA256}" -eq 64 ] || fail "official checksum metadata is not a SHA-256 hash: $UV_CHECKSUM_URL"
source_common_verify_sha256 "$ARCHIVE" "$EXPECTED_SHA256" || \
    fail "official SHA-256 verification failed for uv $UV_VERSION"

ARCHIVE_ROOT="uv-$TARGET_TRIPLE"
source_common_extract "$ARCHIVE" "$SOURCES" "$ARCHIVE_ROOT" || \
    fail "could not extract the verified uv $UV_VERSION archive"
SOURCE_ROOT="$SOURCES/$ARCHIVE_ROOT"
[ -x "$SOURCE_ROOT/uv" ] || fail "verified uv archive has no executable uv binary: $ARCHIVE_ROOT/uv"
[ -x "$SOURCE_ROOT/uvx" ] || fail "verified uv archive has no executable uvx binary: $ARCHIVE_ROOT/uvx"
# Probe before activation so an incompatible loader cannot replace a working
# installation.  uvx is shipped as the same standalone implementation.
"$SOURCE_ROOT/uv" --version >/dev/null 2>&1 || fail 'staged uv binary failed its --version probe'

LIB_DIR="$PREFIX/lib"
BIN_DIR="$PREFIX/bin"
mkdir -p "$LIB_DIR" "$BIN_DIR" || fail 'cannot create installation directories'
COMMIT_ROOT="$LIB_DIR/.uv-$UV_VERSION.install.$$"
if [ -e "$COMMIT_ROOT" ] || [ -L "$COMMIT_ROOT" ]; then
    fail "temporary installation path already exists: $COMMIT_ROOT"
fi
mkdir "$COMMIT_ROOT" || fail 'cannot create the versioned uv installation staging root'
COMMIT_ROOT_CREATED=true
cp -R "$SOURCE_ROOT/." "$COMMIT_ROOT/" || fail 'could not stage the versioned uv installation'
[ -x "$COMMIT_ROOT/uv" ] && [ -x "$COMMIT_ROOT/uvx" ] || \
    fail 'staged uv installation is missing executable binaries'

LINK_STAGE_UV="$BIN_DIR/.uv-$UV_VERSION.link.$$"
LINK_STAGE_UVX="$BIN_DIR/.uvx-$UV_VERSION.link.$$"
if [ -e "$LINK_STAGE_UV" ] || [ -L "$LINK_STAGE_UV" ] || \
   [ -e "$LINK_STAGE_UVX" ] || [ -L "$LINK_STAGE_UVX" ]; then
    fail 'temporary managed-link path already exists'
fi
ln -s "$EXPECTED_LINK_UV" "$LINK_STAGE_UV" || fail 'could not stage the uv managed link'
UV_LINK_STAGE_CREATED=true
ln -s "$EXPECTED_LINK_UVX" "$LINK_STAGE_UVX" || fail 'could not stage the uvx managed link'
UVX_LINK_STAGE_CREATED=true

if [ -e "$PREFIX/bin/uv" ] || [ -L "$PREFIX/bin/uv" ]; then
    OLD_UV_PRESENT=true
    OLD_UV_TARGET=$(readlink "$PREFIX/bin/uv") || fail 'cannot save the existing uv managed link'
fi
if [ -e "$PREFIX/bin/uvx" ] || [ -L "$PREFIX/bin/uvx" ]; then
    OLD_UVX_PRESENT=true
    OLD_UVX_TARGET=$(readlink "$PREFIX/bin/uvx") || fail 'cannot save the existing uvx managed link'
fi

mv "$COMMIT_ROOT" "$INSTALL_ROOT" || fail 'could not commit the versioned uv installation'
COMMIT_ROOT_CREATED=false
ROOT_CREATED=true

rollback_install() {
    if [ "$UVX_LINK_INSTALLED" = true ]; then
        rm -f "$PREFIX/bin/uvx"
        if [ "$OLD_UVX_PRESENT" = true ]; then
            ln -s "$OLD_UVX_TARGET" "$PREFIX/bin/uvx"
        fi
        UVX_LINK_INSTALLED=false
    fi
    if [ "$UV_LINK_INSTALLED" = true ]; then
        rm -f "$PREFIX/bin/uv"
        if [ "$OLD_UV_PRESENT" = true ]; then
            ln -s "$OLD_UV_TARGET" "$PREFIX/bin/uv"
        fi
        UV_LINK_INSTALLED=false
    fi
    if [ "$ROOT_CREATED" = true ]; then
        rm -rf "$INSTALL_ROOT"
        ROOT_CREATED=false
    fi
}

if ! mv -f "$LINK_STAGE_UV" "$PREFIX/bin/uv"; then
    rollback_install
    fail 'could not install the uv managed link'
fi
UV_LINK_INSTALLED=true
UV_LINK_STAGE_CREATED=false
LINK_STAGE_UV=""
if ! mv -f "$LINK_STAGE_UVX" "$PREFIX/bin/uvx"; then
    rollback_install
    fail 'could not install the uvx managed link'
fi
UVX_LINK_INSTALLED=true
UVX_LINK_STAGE_CREATED=false
LINK_STAGE_UVX=""
INSTALL_SUCCEEDED=true

printf '%s\n' "Installed uv $UV_VERSION at $INSTALL_ROOT/uv"
printf '%s\n' "Managed links at $PREFIX/bin/uv and $PREFIX/bin/uvx"
printf '%s\n' "Add this directory to PATH: $PREFIX/bin"
