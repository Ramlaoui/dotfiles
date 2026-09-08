#!/usr/bin/env bash
# Install an official Go distribution into a user-local prefix without sudo.
# The complete GOROOT stays intact under prefix/lib; only managed symlinks are
# placed in prefix/bin so Go can infer its root from the executable location.

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
VERSION=""
SHOW_HELP=false
BUILD_ROOT=""
GO_VERSION=""
GO_OS=""
GO_ARCH=""
GO_ARCHIVE=""
GO_URL=""
GO_SHA256=""
GOROOT_DIR=""

print_usage() {
    cat <<EOF
Usage: $PROGRAM [--prefix PATH] [--version VERSION]

Install the official Go distribution without sudo.  The default installation
prefix is:
  $PREFIX

Options:
  --prefix PATH       Install into an absolute path without whitespace.
  --version VERSION   Install this exact stable Go release (default: latest).
  -h, --help          Show this help and exit without network access.

Supported targets: Linux and macOS on amd64 or arm64.
Required commands: tar, mktemp, mkdir, mv, ln, rm, readlink, sed, tr, and
curl or wget, plus sha256sum (Linux) or shasum (macOS).
The complete GOROOT is kept under PREFIX/lib.  The script never edits shell
startup files or sets GOROOT/PATH; add PREFIX/bin to PATH yourself.
EOF
}

fail() {
    printf '%s: %s\n' "$PROGRAM" "$1" >&2
    exit 1
}

cleanup() {
    status=$?
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
            shift
            ;;
        --prefix=*) PREFIX=${1#--prefix=} ;;
        --version)
            [ "$#" -ge 2 ] || fail '--version requires a release version'
            VERSION="$2"
            shift
            ;;
        --version=*) VERSION=${1#--version=} ;;
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

[ -n "$HOME" ] 2>/dev/null || fail 'HOME must be set'
source_common_validate_prefix "$PREFIX" || exit 1

# Accept the conventional 1.25.1 spelling and the archive's go1.25.1
# spelling, but reject prereleases and path-like values before any network use.
if [ -n "$VERSION" ]; then
    GO_VERSION=$(printf '%s\n' "$VERSION" | sed -n 's/^\(go\)\{0,1\}\(1\.[0-9][0-9]*\.[0-9][0-9]*\)$/go\2/p')
    [ -n "$GO_VERSION" ] || fail "invalid Go version: $VERSION (expected 1.X.Y)"
fi

TARGET_OS=$(uname -s 2>/dev/null || printf unknown)
TARGET_ARCH=$(uname -m 2>/dev/null || printf unknown)
case "$TARGET_OS" in
    Linux) GO_OS=linux ;;
    Darwin) GO_OS=darwin ;;
    *) fail "unsupported operating system: $TARGET_OS (supported: Linux, macOS)" ;;
esac
case "$TARGET_ARCH" in
    x86_64|amd64) GO_ARCH=amd64 ;;
    aarch64|arm64) GO_ARCH=arm64 ;;
    *) fail "unsupported architecture: $TARGET_ARCH (supported: amd64, arm64)" ;;
esac

# Refuse to follow directory symlinks for the two trees this installer owns.
# Missing directories are created only after the archive has passed checksum
# verification and extraction checks.
for owned_dir in "$PREFIX/bin" "$PREFIX/lib"; do
    if [ -L "$owned_dir" ]; then
        fail "refusing symlinked installation directory: $owned_dir"
    fi
    if [ -e "$owned_dir" ] && [ ! -d "$owned_dir" ]; then
        fail "installation path is not a directory: $owned_dir"
    fi
done

for required in tar mktemp mkdir mv ln rm readlink sed tr; do
    command -v "$required" >/dev/null 2>&1 || fail "required command not found: $required"
done
command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || fail 'curl or wget is required to download Go releases'
if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
    fail 'sha256sum or shasum is required to verify the Go release archive'
fi

# An existing regular file, directory, or unrelated symlink is never adopted
# or overwritten.  Relative links matching our own layout are upgrade slots.
validate_link_slot() {
    local name="$1"
    local link="$PREFIX/bin/$name"
    local target
    if [ -L "$link" ]; then
        target=$(readlink "$link") || fail "cannot inspect existing $link"
        case "$target" in
            ../lib/go[0-9]*"/bin/$name") ;;
            *) fail "refusing to replace unrelated existing target: $link" ;;
        esac
    elif [ -e "$link" ]; then
        fail "refusing to replace existing file: $link"
    fi
}
validate_link_slot go
validate_link_slot gofmt

BUILD_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/install-go.XXXXXX") || fail 'cannot create a private build directory'
DOWNLOADS="$BUILD_ROOT/downloads"
EXTRACTED="$BUILD_ROOT/extracted"
mkdir -p "$DOWNLOADS" "$EXTRACTED" || fail 'cannot initialize the private build directory'

if [ -z "$GO_VERSION" ]; then
    VERSION_LISTING="$BUILD_ROOT/version.txt"
    source_common_download 'https://go.dev/VERSION?m=text' "$VERSION_LISTING" || fail 'could not discover the latest stable Go release'
    GO_VERSION=$(sed -n '1s/^\(go[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*$/\1/p' "$VERSION_LISTING")
    [ -n "$GO_VERSION" ] || fail 'official Go version endpoint returned no stable release'
fi

GO_ARCHIVE="$GO_VERSION.$GO_OS-$GO_ARCH.tar.gz"
GO_URL="https://go.dev/dl/$GO_ARCHIVE"

# go.dev's JSON listing is the official release metadata and includes the
# published SHA-256 for each archive.  Match the complete archive name rather
# than trusting a checksum downloaded from an unrelated host.
RELEASES_JSON="$BUILD_ROOT/releases.json"
source_common_download 'https://go.dev/dl/?mode=json&include=all' "$RELEASES_JSON" || fail 'could not retrieve official Go release checksums'
GO_SHA256=''
while IFS= read -r release_object || [ -n "$release_object" ]; do
    case "$release_object" in
        *\"filename\":\""$GO_ARCHIVE"\"*)
            GO_SHA256=$(printf '%s\n' "$release_object" | sed -n 's/.*"sha256":"\([0-9a-fA-F]\{64\}\)".*/\1/p')
            [ -n "$GO_SHA256" ] && break
            ;;
    esac
done < <(tr -d '[:space:]' < "$RELEASES_JSON" | tr '{' '\n')
case "$(printf '%s\n' "$GO_SHA256" | sed -n '/^[0-9a-fA-F]\{64\}$/p')" in
    '') fail "official Go metadata has no SHA-256 for $GO_ARCHIVE" ;;
esac

archive="$DOWNLOADS/$GO_ARCHIVE"
source_common_download "$GO_URL" "$archive" || fail "could not download Go $GO_VERSION"
source_common_verify_sha256 "$archive" "$GO_SHA256" || fail "Go $GO_VERSION archive checksum verification failed"
source_common_extract "$archive" "$EXTRACTED" go || fail "could not extract Go $GO_VERSION"
STAGED_ROOT="$EXTRACTED/go"
[ -x "$STAGED_ROOT/bin/go" ] || fail "Go archive has no executable go tool"
[ -x "$STAGED_ROOT/bin/gofmt" ] || fail "Go archive has no executable gofmt tool"

GOROOT_DIR="$PREFIX/lib/$GO_VERSION"
if [ -L "$GOROOT_DIR" ]; then
    fail "refusing to replace symlinked Go root: $GOROOT_DIR"
fi
if [ -e "$GOROOT_DIR" ]; then
    [ -d "$GOROOT_DIR" ] || fail "existing Go root is not a directory: $GOROOT_DIR"
    [ -x "$GOROOT_DIR/bin/go" ] && [ -x "$GOROOT_DIR/bin/gofmt" ] || fail "existing Go root is incomplete: $GOROOT_DIR"
else
    mkdir -p "$PREFIX/lib" || fail "cannot create Go library directory: $PREFIX/lib"
    mv "$STAGED_ROOT" "$GOROOT_DIR" || fail "cannot install Go root: $GOROOT_DIR"
fi

# Replace only the two links this installer owns.  Use a same-directory
# temporary link so each replacement is atomic on Linux and macOS.
install_link() {
    local name="$1"
    local target="../lib/$GO_VERSION/bin/$name"
    local link="$PREFIX/bin/$name"
    local temporary="$PREFIX/bin/.go-$name.$$"
    rm -f "$temporary" || return 1
    ln -s "$target" "$temporary" || return 1
    if mv "$temporary" "$link"; then
        return 0
    fi
    rm -f "$temporary"
    return 1
}

restore_link() {
    local name="$1"
    local target="$2"
    local link="$PREFIX/bin/$name"
    local temporary="$PREFIX/bin/.go-restore-$name.$$"
    rm -f "$temporary" || return 1
    ln -s "$target" "$temporary" || return 1
    if mv "$temporary" "$link"; then
        return 0
    fi
    rm -f "$temporary"
    return 1
}

mkdir -p "$PREFIX/bin" || fail "cannot create Go binary directory: $PREFIX/bin"
OLD_GO_LINK=''
OLD_GOFMT_LINK=''
[ -L "$PREFIX/bin/go" ] && OLD_GO_LINK=$(readlink "$PREFIX/bin/go")
[ -L "$PREFIX/bin/gofmt" ] && OLD_GOFMT_LINK=$(readlink "$PREFIX/bin/gofmt")
if ! install_link go; then
    fail "cannot update Go binary link: $PREFIX/bin/go"
fi
if ! install_link gofmt; then
    if [ -n "$OLD_GO_LINK" ]; then
        restore_link go "$OLD_GO_LINK" || true
    else
        rm -f "$PREFIX/bin/go" || true
    fi
    fail "cannot update Go binary link: $PREFIX/bin/gofmt"
fi

printf '%s\n' "Installed Go $GO_VERSION at $GOROOT_DIR"
printf '%s\n' "Add this directory to PATH: $PREFIX/bin"
