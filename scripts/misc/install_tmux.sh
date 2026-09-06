#!/usr/bin/env bash
# Build tmux and its private static libraries from official source archives.
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
DOWNLOADS=""
SOURCES=""
TOOLS_BIN=""
STAGE_ROOT=""
PARSER_PREFIX=""
LOCAL_PREFIX=""
MAKE_CMD=""
CC_CMD=""
YACC_CMD=""
BISON_CMD=""

TMUX_VERSION=""
TMUX_ARCHIVE=""
TMUX_URL=""

# These archives are deliberately pinned. SHA-256 values were computed from
# the corresponding official release archives.
LIBEVENT_VERSION='2.1.13-stable'
LIBEVENT_ARCHIVE="libevent-$LIBEVENT_VERSION.tar.gz"
LIBEVENT_URL="https://github.com/libevent/libevent/releases/download/release-$LIBEVENT_VERSION/$LIBEVENT_ARCHIVE"
LIBEVENT_SHA256='f7e9383b8c0baa81b687e5b5eecc01beefaf1b19b64151d95ed61647fe7a315c'

NCURSES_VERSION='6.6'
NCURSES_ARCHIVE="ncurses-$NCURSES_VERSION.tar.gz"
NCURSES_URL="https://ftp.gnu.org/gnu/ncurses/$NCURSES_ARCHIVE"
NCURSES_SHA256='355b4cbbed880b0381a04c46617b7656e362585d52e9cf84a67e2009b749ff11'

UTF8PROC_VERSION='2.11.3'
UTF8PROC_ARCHIVE="utf8proc-$UTF8PROC_VERSION.tar.gz"
UTF8PROC_URL="https://github.com/JuliaStrings/utf8proc/releases/download/v$UTF8PROC_VERSION/$UTF8PROC_ARCHIVE"
UTF8PROC_SHA256='415189fd2c85cd6ee5ff26af500fa387de9ada1e3e316e93f7338551481d557d'

M4_VERSION='1.4.21'
M4_ARCHIVE="m4-$M4_VERSION.tar.gz"
M4_URL="https://ftp.gnu.org/gnu/m4/$M4_ARCHIVE"
M4_SHA256='38ae59f7a30bf9c108193cc5c25fbb06014f21e230c7ede2eff614f7b7c37ed8'

BISON_VERSION='3.8.2'
BISON_ARCHIVE="bison-$BISON_VERSION.tar.gz"
BISON_URL="https://ftp.gnu.org/gnu/bison/$BISON_ARCHIVE"
BISON_SHA256='06c9e13bdf7eb24d4ceb6b59205a4f67c2c7e7213119644430fe82fbd14a0abb'

# macOS's tmux configure requires jemalloc. Keep it pinned and static rather
# than depending on a package manager or a system shared library.
JEMALLOC_VERSION='5.3.1'
JEMALLOC_ARCHIVE="jemalloc-$JEMALLOC_VERSION.tar.bz2"
JEMALLOC_URL="https://github.com/jemalloc/jemalloc/releases/download/$JEMALLOC_VERSION/$JEMALLOC_ARCHIVE"
JEMALLOC_SHA256='3826bc80232f22ed5c4662f3034f799ca316e819103bdc7bb99018a421706f92'

TARGET_OS=''
NEED_JEMALLOC=false

TARGET_OS=$(uname -s 2>/dev/null || printf unknown)
if [ "$TARGET_OS" = Darwin ]; then
    NEED_JEMALLOC=true
fi

NEED_PARSER=false
NEED_M4=false

print_usage() {
    cat <<EOF
Usage: $PROGRAM [--prefix PATH] [--jobs N] [--version VERSION]

Build tmux and private static libevent, ncurses, and utf8proc without sudo.
The default installation prefix is:
  $PREFIX

Options:
  --prefix PATH       Install into an absolute path without whitespace.
  --jobs N            Pass N parallel jobs to make (default: 1).
  --version VERSION   Build this exact tmux release (default: latest).
  -h, --help          Show this help and exit without network access.

Required commands: a C compiler, make, tar, mktemp, and curl or wget.
Pinned archive checksums require sha256sum (Linux) or shasum (macOS).
If yacc/bison or m4 are unavailable, pinned GNU releases are built locally.
No git, autotools, pkg-config, Python, makeinfo, or sudo is required.
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
            [ "$#" -ge 2 ] || fail '--jobs must be a positive integer'
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
        [ -z "$VERSION" ] || fail "invalid tmux version: $VERSION"
        ;;
esac

command -v make >/dev/null 2>&1 || fail 'required command not found: make'
command -v tar >/dev/null 2>&1 || fail 'required command not found: tar'
command -v mktemp >/dev/null 2>&1 || fail 'required command not found: mktemp'
command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || fail 'curl or wget is required to download release archives'
if command -v cc >/dev/null 2>&1; then
    CC_CMD=$(command -v cc)
elif command -v gcc >/dev/null 2>&1; then
    CC_CMD=$(command -v gcc)
elif command -v clang >/dev/null 2>&1; then
    CC_CMD=$(command -v clang)
else
    fail 'a C compiler is required for tmux (tried cc, gcc, clang)'
fi
MAKE_CMD=$(command -v make)

# A release archive contains generated cmd-parse.c, but configure still needs
# a usable yacc command. Prefer an existing yacc/bison and build only what is
# absent, using a named wrapper in TOOLS_BIN for tmux's PATH.
if command -v yacc >/dev/null 2>&1; then
    YACC_CMD=yacc
elif command -v bison >/dev/null 2>&1; then
    BISON_CMD=$(command -v bison)
    YACC_CMD='yacc'
    command -v m4 >/dev/null 2>&1 || NEED_M4=true
else
    NEED_PARSER=true
    NEED_M4=true
    YACC_CMD='yacc'
fi

BUILD_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/install-tmux.XXXXXX") || fail 'cannot create a private build directory'
DOWNLOADS="$BUILD_ROOT/downloads"
SOURCES="$BUILD_ROOT/sources"
TOOLS_BIN="$BUILD_ROOT/tools/bin"
STAGE_ROOT="$BUILD_ROOT/stage"
PARSER_PREFIX="$BUILD_ROOT/parser"
LOCAL_PREFIX="$BUILD_ROOT/local"
mkdir -p "$DOWNLOADS" "$SOURCES" "$TOOLS_BIN" "$STAGE_ROOT" "$PARSER_PREFIX" "$LOCAL_PREFIX" || fail 'cannot initialize the private build directory'

if [ -n "$BISON_CMD" ]; then
    printf '%s\n' '#!/bin/sh' "exec \"$BISON_CMD\" -y \"\$@\"" > "$TOOLS_BIN/yacc"
    chmod 755 "$TOOLS_BIN/yacc" || fail 'cannot create yacc wrapper'
fi

discover_latest_tmux() {
    local page="$BUILD_ROOT/tmux-release.html"
    # GitHub's latest page selects the stable release without an API token.
    source_common_download 'https://github.com/tmux/tmux/releases/latest' "$page" || return 1
    TMUX_VERSION=$(sed -n 's@.*<meta property="og:url" content="[^"]*/tmux/tmux/releases/tag/\([^"]*\)".*@\1@p' "$page")
    case "$TMUX_VERSION" in
        ''|*[!A-Za-z0-9._-]*) return 1 ;;
    esac
    TMUX_ARCHIVE="tmux-$TMUX_VERSION.tar.gz"
    TMUX_URL="https://github.com/tmux/tmux/releases/download/$TMUX_VERSION/$TMUX_ARCHIVE"
}

if [ -n "$VERSION" ]; then
    TMUX_VERSION="$VERSION"
    TMUX_ARCHIVE="tmux-$VERSION.tar.gz"
    TMUX_URL="https://github.com/tmux/tmux/releases/download/$VERSION/$TMUX_ARCHIVE"
else
    discover_latest_tmux || fail 'could not discover the latest stable tmux release'
fi

build_m4() {
    archive="$DOWNLOADS/$M4_ARCHIVE"
    source_common_download "$M4_URL" "$archive" || return 1
    source_common_verify_sha256 "$archive" "$M4_SHA256" || return 1
    source_common_extract "$archive" "$SOURCES" "m4-$M4_VERSION" || return 1
    source_dir="$SOURCES/m4-$M4_VERSION"
    (
        cd "$source_dir" &&
        CC="$CC_CMD" ./configure --prefix="$PARSER_PREFIX" --disable-nls &&
        "$MAKE_CMD" -j"$JOBS" MAKEINFO=:
    ) || return $?
    [ -x "$source_dir/src/m4" ] || return 1
    cp "$source_dir/src/m4" "$TOOLS_BIN/m4" || return 1
    chmod 755 "$TOOLS_BIN/m4" || return 1
}

build_bison() {
    archive="$DOWNLOADS/$BISON_ARCHIVE"
    source_common_download "$BISON_URL" "$archive" || return 1
    source_common_verify_sha256 "$archive" "$BISON_SHA256" || return 1
    source_common_extract "$archive" "$SOURCES" "bison-$BISON_VERSION" || return 1
    source_dir="$SOURCES/bison-$BISON_VERSION"
    (
        cd "$source_dir" &&
        PATH="$TOOLS_BIN:$PATH" M4="$TOOLS_BIN/m4" CC="$CC_CMD" ./configure --prefix="$PARSER_PREFIX" --disable-nls &&
        PATH="$TOOLS_BIN:$PATH" "$MAKE_CMD" -j"$JOBS" MAKEINFO=: &&
        PATH="$TOOLS_BIN:$PATH" "$MAKE_CMD" install MAKEINFO=:
    ) || return $?
    [ -x "$PARSER_PREFIX/bin/bison" ] || return 1
    BISON_CMD="$PARSER_PREFIX/bin/bison"
    printf '%s\n' '#!/bin/sh' "exec \"$BISON_CMD\" -y \"\$@\"" > "$TOOLS_BIN/yacc"
    chmod 755 "$TOOLS_BIN/yacc" || return 1
}

build_libevent() {
    archive="$DOWNLOADS/$LIBEVENT_ARCHIVE"
    source_common_download "$LIBEVENT_URL" "$archive" || return 1
    source_common_verify_sha256 "$archive" "$LIBEVENT_SHA256" || return 1
    source_common_extract "$archive" "$SOURCES" "libevent-$LIBEVENT_VERSION" || return 1
    source_dir="$SOURCES/libevent-$LIBEVENT_VERSION"
    (
        cd "$source_dir" &&
        CC="$CC_CMD" ./configure --prefix="$LOCAL_PREFIX" --disable-shared --enable-static --disable-openssl &&
        "$MAKE_CMD" -j"$JOBS" &&
        "$MAKE_CMD" install
    ) || return $?
}

build_ncurses() {
    archive="$DOWNLOADS/$NCURSES_ARCHIVE"
    source_common_download "$NCURSES_URL" "$archive" || return 1
    source_common_verify_sha256 "$archive" "$NCURSES_SHA256" || return 1
    source_common_extract "$archive" "$SOURCES" "ncurses-$NCURSES_VERSION" || return 1
    source_dir="$SOURCES/ncurses-$NCURSES_VERSION"
    (
        cd "$source_dir" &&
        CC="$CC_CMD" ./configure --prefix="$LOCAL_PREFIX" --enable-widec --with-normal --with-termlib --without-shared --without-debug --without-cxx --without-ada --without-manpages --without-tests &&
        "$MAKE_CMD" -j"$JOBS" &&
        "$MAKE_CMD" install
    ) || return $?
}

build_utf8proc() {
    archive="$DOWNLOADS/$UTF8PROC_ARCHIVE"
    source_common_download "$UTF8PROC_URL" "$archive" || return 1
    source_common_verify_sha256 "$archive" "$UTF8PROC_SHA256" || return 1
    source_common_extract "$archive" "$SOURCES" "utf8proc-$UTF8PROC_VERSION" || return 1
    source_dir="$SOURCES/utf8proc-$UTF8PROC_VERSION"
    mkdir -p "$LOCAL_PREFIX/lib" "$LOCAL_PREFIX/include" || return 1
    (
        cd "$source_dir" &&
        "$MAKE_CMD" -j"$JOBS" CC="$CC_CMD" libutf8proc.a
    ) || return $?
    cp "$source_dir/libutf8proc.a" "$LOCAL_PREFIX/lib/" || return 1
    cp "$source_dir/utf8proc.h" "$LOCAL_PREFIX/include/" || return 1
}

build_jemalloc() {
    archive="$DOWNLOADS/$JEMALLOC_ARCHIVE"
    source_common_download "$JEMALLOC_URL" "$archive" || return 1
    source_common_verify_sha256 "$archive" "$JEMALLOC_SHA256" || return 1
    source_common_extract "$archive" "$SOURCES" "jemalloc-$JEMALLOC_VERSION" || return 1
    source_dir="$SOURCES/jemalloc-$JEMALLOC_VERSION"
    (
        cd "$source_dir" &&
        CC="$CC_CMD" ./configure --prefix="$LOCAL_PREFIX" --disable-cxx --disable-doc --disable-shared --enable-static &&
        "$MAKE_CMD" -j"$JOBS" &&
        "$MAKE_CMD" install
    ) || return $?
}

build_tmux() {
    archive="$DOWNLOADS/$TMUX_ARCHIVE"
    source_common_download "$TMUX_URL" "$archive" || return 1
    source_common_extract "$archive" "$SOURCES" "${TMUX_ARCHIVE%.tar.gz}" || return 1
    source_dir="$SOURCES/${TMUX_ARCHIVE%.tar.gz}"
    include_flags="-I$LOCAL_PREFIX/include -I$LOCAL_PREFIX/include/ncursesw"
    library_flags="-L$LOCAL_PREFIX/lib -L$LOCAL_PREFIX/lib64"
    local_event="$LOCAL_PREFIX/lib/libevent_core.a"
    local_ncurses="$LOCAL_PREFIX/lib/libncursesw.a"
    local_tinfo="$LOCAL_PREFIX/lib/libtinfow.a"
    local_utf8proc="$LOCAL_PREFIX/lib/libutf8proc.a"
    jemalloc_cflags=''
    jemalloc_libs=''
    jemalloc_option=''
    [ -f "$local_event" ] || return 1
    [ -f "$local_ncurses" ] || return 1
    [ -f "$local_tinfo" ] || return 1
    [ -f "$local_utf8proc" ] || return 1
    if [ "$NEED_JEMALLOC" = true ]; then
        local_jemalloc="$LOCAL_PREFIX/lib/libjemalloc.a"
        [ -f "$local_jemalloc" ] || return 1
        jemalloc_cflags="$include_flags"
        jemalloc_libs="$local_jemalloc"
        jemalloc_option='--enable-jemalloc'
    fi
    # Absolute archive paths prevent configure from silently selecting system
    # shared libraries. There is intentionally no -Bstatic (not portable to
    # the macOS linker). --enable-utf8proc is required on macOS as well.
    (
        cd "$source_dir" &&
        PATH="$TOOLS_BIN:$PATH" YACC="$YACC_CMD" PKG_CONFIG=false \
        CPPFLAGS="$include_flags" LDFLAGS="$library_flags" \
        LIBEVENT_CORE_CFLAGS="$include_flags" LIBEVENT_CORE_LIBS="$local_event" \
        LIBEVENT_CFLAGS="$include_flags" LIBEVENT_LIBS="$local_event" \
        LIBTINFOW_CFLAGS="$include_flags" LIBTINFOW_LIBS="$local_tinfo" \
        LIBTINFO_CFLAGS="$include_flags" LIBTINFO_LIBS="$local_tinfo" \
        LIBNCURSESW_CFLAGS="$include_flags" LIBNCURSESW_LIBS="$local_ncurses $local_tinfo" \
        LIBNCURSES_CFLAGS="$include_flags" LIBNCURSES_LIBS="$local_ncurses $local_tinfo" \
        LIBUTF8PROC_CFLAGS="$include_flags" LIBUTF8PROC_LIBS="$local_utf8proc" \
        JEMALLOC_CFLAGS="$jemalloc_cflags" JEMALLOC_LIBS="$jemalloc_libs" \
        LIBS="$local_event $local_ncurses $local_tinfo" \
        CC="$CC_CMD" ./configure --prefix="$PREFIX" --enable-utf8proc $jemalloc_option &&
        PATH="$TOOLS_BIN:$PATH" "$MAKE_CMD" -j"$JOBS" DESTDIR="$STAGE_ROOT" &&
        PATH="$TOOLS_BIN:$PATH" "$MAKE_CMD" DESTDIR="$STAGE_ROOT" install
    ) || return $?
}

if [ "$NEED_M4" = true ]; then
    printf '%s\n' "Building pinned GNU m4 $M4_VERSION"
    build_m4 || fail "GNU m4 $M4_VERSION bootstrap failed"
fi
if [ "$NEED_PARSER" = true ]; then
    printf '%s\n' "Building pinned GNU Bison $BISON_VERSION"
    build_bison || fail "GNU Bison $BISON_VERSION bootstrap failed"
fi
printf '%s\n' "Building pinned libevent $LIBEVENT_VERSION (static)"
build_libevent || fail "libevent $LIBEVENT_VERSION build failed"
printf '%s\n' "Building pinned ncurses $NCURSES_VERSION (static wide-character library)"
build_ncurses || fail "ncurses $NCURSES_VERSION build failed"
printf '%s\n' "Building pinned utf8proc $UTF8PROC_VERSION (static Unicode support)"
build_utf8proc || fail "utf8proc $UTF8PROC_VERSION build failed"
if [ "$NEED_JEMALLOC" = true ]; then
    printf '%s\n' "Building pinned jemalloc $JEMALLOC_VERSION (static)"
    build_jemalloc || fail "jemalloc $JEMALLOC_VERSION build failed"
fi
printf '%s\n' "Building tmux $TMUX_VERSION"
build_tmux || fail "tmux $TMUX_VERSION build failed"

STAGED_PREFIX="$STAGE_ROOT$PREFIX"
[ -d "$STAGED_PREFIX" ] || fail "build produced no staged files for prefix: $PREFIX"
mkdir -p "$PREFIX" || fail "cannot create installation prefix: $PREFIX"
cp -R "$STAGED_PREFIX/." "$PREFIX/" || fail "could not install into prefix: $PREFIX"
printf '%s\n' "Installed tmux $TMUX_VERSION at $PREFIX/bin/tmux"
printf '%s\n' "Add this directory to PATH: $PREFIX/bin"
