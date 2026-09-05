#!/usr/bin/env bash
# Build the latest stable GNU Stow release from its official source archive.
# No sudo is used; the final staged tree is copied into --prefix.

set -o pipefail

PROGRAM=${0##*/}
SCRIPT_PATH=${BASH_SOURCE[0]}
SCRIPT_DIR=${SCRIPT_PATH%/*}
[ "$SCRIPT_DIR" = "$SCRIPT_PATH" ] && SCRIPT_DIR=.
SCRIPT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR" 2>/dev/null && pwd -P)" || exit 1
COMMON="$SCRIPT_DIR/../installs/source-common.sh"
[ -r "$COMMON" ] || { printf '%s\n' "$PROGRAM: shared source mechanics are missing: $COMMON" >&2; exit 1; }
# shellcheck source=/dev/null
. "$COMMON"

PREFIX="${HOME:-}/.local"
JOBS=1
VERSION=""
SHOW_HELP=false
BUILD_ROOT=""
MAKE_CMD=""
PERL_CMD=""
STOW_ARCHIVE=""
STOW_URL=""
STOW_VERSION=""

print_usage() {
    cat <<EOF
Usage: $PROGRAM [--prefix PATH] [--jobs N] [--version VERSION]

Build GNU Stow from the official GNU release archive without sudo.
The default installation prefix is:
  $PREFIX

Options:
  --prefix PATH       Install into an absolute path without whitespace.
  --jobs N            Pass N parallel jobs to make (default: 1).
  --version VERSION   Build this exact GNU Stow release (default: latest).
  -h, --help          Show this help and exit without network access.

Required commands: make, Perl, tar, gzip, mktemp, and curl or wget.
The script never edits shell startup files. Add PREFIX/bin to PATH yourself.
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
        --jobs)
            [ "$#" -ge 2 ] || fail '--jobs requires a positive integer'
            JOBS="$2"
            shift
            ;;
        --jobs=*) JOBS=${1#--jobs=} ;;
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
source_common_validate_jobs "$JOBS" || fail '--jobs must be a positive integer'
source_common_validate_prefix "$PREFIX" || exit 1
case "$VERSION" in
    ''|*[!A-Za-z0-9._-]*)
        [ -z "$VERSION" ] || fail "invalid Stow version: $VERSION"
        ;;
esac

command -v make >/dev/null 2>&1 || fail 'required command not found: make'
command -v perl >/dev/null 2>&1 || fail 'required command not found: perl'
command -v tar >/dev/null 2>&1 || fail 'required command not found: tar'
command -v gzip >/dev/null 2>&1 || fail 'required command not found: gzip'
command -v mktemp >/dev/null 2>&1 || fail 'required command not found: mktemp'
command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || fail 'curl or wget is required to download release archives'
MAKE_CMD=$(command -v make)
PERL_CMD=$(command -v perl)

BUILD_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/install-stow.XXXXXX") || fail 'cannot create a private build directory'
DOWNLOADS="$BUILD_ROOT/downloads"
SOURCES="$BUILD_ROOT/sources"
STAGE_ROOT="$BUILD_ROOT/stage"
mkdir -p "$DOWNLOADS" "$SOURCES" "$STAGE_ROOT" || fail 'cannot initialize the private build directory'

numeric_version_newer() {
    candidate="$1"
    current="$2"
    VERSION_NEWER=false
    case "$candidate" in ''|*[!0-9.]*) return 0 ;; esac
    case "$current" in ''|*[!0-9.]*) current='' ;; esac
    [ -z "$current" ] && { VERSION_NEWER=true; return 0; }
    old_ifs="$IFS"
    IFS=.
    candidate_parts=($candidate)
    current_parts=($current)
    IFS="$old_ifs"
    i=0
    while [ "$i" -lt 8 ]; do
        candidate_part=${candidate_parts[$i]:-0}
        current_part=${current_parts[$i]:-0}
        if [ "$candidate_part" -gt "$current_part" ] 2>/dev/null; then
            VERSION_NEWER=true
            return 0
        fi
        if [ "$candidate_part" -lt "$current_part" ] 2>/dev/null; then
            return 0
        fi
        i=$((i + 1))
    done
}

discover_latest_stow() {
    listing="$BUILD_ROOT/stow.listing"
    names="$BUILD_ROOT/stow.names"
    source_common_download 'https://ftp.gnu.org/gnu/stow/' "$listing" || return 1
    sed -n '/\.sig/! s/.*\(stow-[0-9][0-9.]*\.tar\.gz\).*/\1/p' "$listing" > "$names"
    best_version=''
    best_archive=''
    while IFS= read -r archive_name; do
        [ -n "$archive_name" ] || continue
        candidate=${archive_name#stow-}
        candidate=${candidate%.tar.gz}
        numeric_version_newer "$candidate" "$best_version"
        if [ "$VERSION_NEWER" = true ]; then
            best_version="$candidate"
            best_archive="$archive_name"
        fi
    done < "$names"
    [ -n "$best_archive" ] || return 1
    STOW_VERSION="$best_version"
    STOW_ARCHIVE="$best_archive"
    STOW_URL="https://ftp.gnu.org/gnu/stow/$best_archive"
}

if [ -n "$VERSION" ]; then
    STOW_VERSION="$VERSION"
    STOW_ARCHIVE="stow-$VERSION.tar.gz"
    STOW_URL="https://ftp.gnu.org/gnu/stow/$STOW_ARCHIVE"
else
    discover_latest_stow || fail 'could not discover the latest stable GNU Stow release'
fi

printf '%s\n' "Building GNU Stow $STOW_VERSION"
archive="$DOWNLOADS/$STOW_ARCHIVE"
source_common_download "$STOW_URL" "$archive" || fail "could not download GNU Stow $STOW_VERSION"
source_common_extract "$archive" "$SOURCES" "stow-$STOW_VERSION" || fail "could not extract GNU Stow $STOW_VERSION"
source_dir="$SOURCES/stow-$STOW_VERSION"

# Configure against the final prefix so generated Perl scripts retain the
# correct @INC after DESTDIR staging. Avoid documentation tool requirements.
(
    cd "$source_dir" &&
    PERL="$PERL_CMD" ./configure --prefix="$PREFIX" &&
    "$MAKE_CMD" -j"$JOBS" DESTDIR="$STAGE_ROOT" install-exec install-pmDATA install-pmstowDATA
) || fail "GNU Stow $STOW_VERSION build failed"

STAGED_PREFIX="$STAGE_ROOT$PREFIX"
[ -d "$STAGED_PREFIX" ] || fail "build produced no staged files for prefix: $PREFIX"
mkdir -p "$PREFIX" || fail "cannot create installation prefix: $PREFIX"
cp -R "$STAGED_PREFIX/." "$PREFIX/" || fail "could not install into prefix: $PREFIX"
printf '%s\n' "Installed GNU Stow $STOW_VERSION at $PREFIX/bin/stow"
printf '%s\n' "Add this directory to PATH: $PREFIX/bin"
