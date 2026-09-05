#!/usr/bin/env bash
# Build the requested GNU Stow and tmux releases into a user prefix.
#
# This script intentionally uses release archives rather than source-control
# checkouts.  It is suitable for the Bash 3 shipped by macOS: no associative
# arrays, namerefs, process substitution, or Bash 4-only builtins are used.

set -o pipefail

PROGRAM=${0##*/}
PREFIX="${HOME:-}/.local"
JOBS=1
SELECTION=""
SHOW_HELP=false
BUILD_ROOT=""
DOWNLOAD_TOOL=""
MAKE_CMD=""
CC_CMD=""
PERL_CMD=""
YACC_CMD=""
BISON_CMD=""
STAGE_ROOT=""
PARSER_PREFIX=""
STAGE_PREFIX=""
TOOLS_BIN=""
LOCAL_PREFIX=""

STOW_VERSION=""
STOW_ARCHIVE_NAME=""
STOW_URL=""
TMUX_VERSION=""
TMUX_ARCHIVE_NAME=""
TMUX_URL=""
LIBEVENT_VERSION=""
LIBEVENT_ARCHIVE_NAME=""
LIBEVENT_URL=""
NCURSES_VERSION=""
NCURSES_ARCHIVE_NAME=""
NCURSES_URL=""
M4_VERSION=""
M4_ARCHIVE_NAME=""
M4_URL=""
BISON_VERSION=""
BISON_ARCHIVE_NAME=""
BISON_URL=""

print_usage() {
    cat <<EOF
Usage: $PROGRAM [--prefix PATH] [--jobs N] stow|tmux|all

Build the latest stable GNU Stow and/or tmux release from official source
archives without sudo.  The default installation prefix is:
  $PREFIX

Tools:
  stow          Build GNU Stow only.
  tmux          Build tmux, with private static libevent and ncurses.
  all           Build both tools before installing either.

Options:
  --prefix PATH Install into an absolute PATH without whitespace.
  --jobs N      Pass N parallel jobs to make (default: 1).
  -h, --help    Show this help and exit without network access.

The script never edits shell startup files.  After a successful install, add
PREFIX/bin to PATH in the shell that should use these binaries, for example:
  export PATH="$PREFIX/bin:\$PATH"

Required for stow: make, Perl, tar, gzip, mktemp, and curl or wget.
Required for tmux: a C compiler, make, tar, gzip, mktemp, and curl or wget.
If tmux has no yacc/bison, GNU m4 and bison are bootstrapped from release
archives; autotools, pkg-config, Python, Git, and makeinfo are not required.
EOF
}

fail() {
    printf '%s\n' "$PROGRAM: $1" >&2
    exit 1
}

cleanup() {
    status=$?
    if [ -n "$BUILD_ROOT" ] && [ -d "$BUILD_ROOT" ]; then
        rm -rf "$BUILD_ROOT"
    fi
    exit "$status"
}

trap cleanup EXIT
trap 'exit 130' INT TERM

while [ "$#" -gt 0 ]; do
    case "$1" in
        --prefix)
            [ "$#" -ge 2 ] || fail "--prefix requires a path"
            PREFIX="$2"
            shift
            ;;
        --prefix=*)
            PREFIX=${1#--prefix=}
            ;;
        --jobs)
            [ "$#" -ge 2 ] || fail "--jobs requires a positive integer"
            JOBS="$2"
            shift
            ;;
        --jobs=*)
            JOBS=${1#--jobs=}
            ;;
        -h|--help)
            SHOW_HELP=true
            ;;
        --)
            shift
            [ "$#" -eq 1 ] || fail "exactly one tool selection is required"
            SELECTION="$1"
            shift
            ;;
        stow|tmux|all)
            [ -z "$SELECTION" ] || fail "only one tool selection may be supplied"
            SELECTION="$1"
            ;;
        *)
            fail "unknown option or tool: $1 (use --help for usage)"
            ;;
    esac
    shift
done

if [ "$SHOW_HELP" = true ]; then
    print_usage
    exit 0
fi

[ -n "$SELECTION" ] || { print_usage >&2; exit 2; }
case "$SELECTION" in
    stow|tmux|all) ;;
    *) fail "unknown tool selection: $SELECTION" ;;
esac

case "$JOBS" in
    ''|*[!0-9]*) fail "--jobs must be a positive integer" ;;
esac
[ "$JOBS" -gt 0 ] 2>/dev/null || fail "--jobs must be a positive integer"

[ -n "$HOME" ] 2>/dev/null || fail "HOME must be set"
[ -n "$PREFIX" ] || fail "prefix must not be empty"
case "$PREFIX" in
    /) fail "refusing root directory as installation prefix" ;;
    /*) ;;
    *) fail "prefix must be an absolute path (got: $PREFIX)" ;;
esac
case "$PREFIX" in
    *[[:space:]]*) fail "prefix must not contain whitespace: upstream build rules do not support it" ;;
esac

need_command() {
    command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

# Select a compiler without assuming that `cc` is present on every platform.
select_compiler() {
    if command -v cc >/dev/null 2>&1; then
        CC_CMD=$(command -v cc)
    elif command -v gcc >/dev/null 2>&1; then
        CC_CMD=$(command -v gcc)
    elif command -v clang >/dev/null 2>&1; then
        CC_CMD=$(command -v clang)
    else
        fail "a C compiler is required for tmux (tried cc, gcc, clang)"
    fi
}

preflight_common() {
    need_command tar
    need_command gzip
    need_command mktemp
    if command -v curl >/dev/null 2>&1; then
        DOWNLOAD_TOOL=curl
    elif command -v wget >/dev/null 2>&1; then
        DOWNLOAD_TOOL=wget
    else
        fail "curl or wget is required to download release archives"
    fi
}

if [ "$SELECTION" = stow ] || [ "$SELECTION" = all ]; then
    preflight_common
    need_command make
    need_command perl
    MAKE_CMD=$(command -v make)
    PERL_CMD=$(command -v perl)
fi
if [ "$SELECTION" = tmux ] || [ "$SELECTION" = all ]; then
    preflight_common
    need_command make
    select_compiler
    export CC="$CC_CMD"
    MAKE_CMD=${MAKE_CMD:-$(command -v make)}
fi

# Determine whether a parser generator must be built.  A release archive
# includes generated cmd-parse.c, but tmux's configure script still requires a
# usable yacc command.  Existing yacc/bison is preferred; only missing tools
# are built locally.
NEED_PARSER=false
NEED_M4=false
if [ "$SELECTION" = tmux ] || [ "$SELECTION" = all ]; then
    if command -v yacc >/dev/null 2>&1; then
        YACC_CMD=yacc
    elif command -v bison >/dev/null 2>&1; then
        BISON_CMD=$(command -v bison)
        YACC_CMD=yacc
        if ! command -v m4 >/dev/null 2>&1; then
            NEED_M4=true
        fi
    else
        NEED_PARSER=true
        NEED_M4=true
        YACC_CMD=yacc
    fi
fi

# A single private build tree keeps downloads, extracted trees, generated
# parser tools, and staged installation separate from the user's prefix.
BUILD_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/source-tools.XXXXXX") || fail "cannot create a private build directory"
DOWNLOADS="$BUILD_ROOT/downloads"
SOURCES="$BUILD_ROOT/sources"
TOOLS_BIN="$BUILD_ROOT/tools/bin"
STAGE_ROOT="$BUILD_ROOT/stage"
PARSER_PREFIX="$BUILD_ROOT/parser"
STAGE_PREFIX="$PREFIX"
LOCAL_PREFIX="$BUILD_ROOT/local"
mkdir -p "$DOWNLOADS" "$SOURCES" "$TOOLS_BIN" "$STAGE_ROOT" "$PARSER_PREFIX" "$LOCAL_PREFIX" || fail "cannot initialize the private build directory"

# When bison is present but yacc is not, expose it under the simple `yacc`
# name expected by tmux's generated configure script and Makefile.
if [ -n "$BISON_CMD" ]; then
    printf '%s\n' '#!/bin/sh' "exec \"$BISON_CMD\" -y \"\$@\"" > "$TOOLS_BIN/yacc"
    chmod 755 "$TOOLS_BIN/yacc" || fail "cannot create yacc wrapper"
fi

# Download one file and reject empty/truncated responses.  A failed curl/wget
# is never replaced with an older or system-installed source.
download_file() {
    url="$1"
    destination="$2"
    printf '%s\n' "Downloading $url"
    rm -f "$destination"
    if [ "$DOWNLOAD_TOOL" = curl ]; then
        curl --fail --location --silent --show-error --output "$destination" "$url"
        status=$?
    else
        wget --output-document="$destination" "$url"
        status=$?
    fi
    [ "$status" -eq 0 ] || {
        printf '%s\n' "Download failed (status $status): $url" >&2
        return "$status"
    }
    [ -s "$destination" ] || {
        printf '%s\n' "Download produced an empty archive: $url" >&2
        return 1
    }
}

numeric_version_newer() {
    candidate="$1"
    current="$2"
    VERSION_NEWER=false
    case "$candidate" in
        ''|*[!0-9.]*) return 0 ;;
    esac
    case "$current" in
        ''|*[!0-9.]*) current="" ;;
    esac
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

# Extract one release archive and expose its top-level directory in
# EXTRACTED_ROOT.  Release archives are expected to contain a directory; this
# guards against malformed downloads before any build command runs.
extract_archive() {
    archive="$1"
    destination="$2"
    listing="$BUILD_ROOT/${archive##*/}.contents"
    tar -tzf "$archive" > "$listing" || {
        printf '%s\n' "Cannot inspect source archive: $archive" >&2
        return 1
    }
    EXTRACTED_ROOT=$(sed -n 's#^\([^/][^/]*\)/.*#\1#p' "$listing" | sed -n '1p')
    [ -n "$EXTRACTED_ROOT" ] || {
        printf '%s\n' "Source archive has no top-level directory: $archive" >&2
        return 1
    }
    tar -xzf "$archive" -C "$destination" || {
        printf '%s\n' "Cannot extract source archive: $archive" >&2
        return 1
    }
    [ -d "$destination/$EXTRACTED_ROOT" ] || {
        printf '%s\n' "Source archive extracted without expected directory: $EXTRACTED_ROOT" >&2
        return 1
    }
    EXTRACTED_ROOT="$destination/$EXTRACTED_ROOT"
}

# Parse the official GNU directory listing and select the numerically highest
# stable release archive.  Signature files and rolling *-latest aliases are
# deliberately excluded.
discover_gnu_archive() {
    listing_url="$1"
    name_prefix="$2"
    result_prefix="$3"
    listing="$BUILD_ROOT/${result_prefix}.listing"
    download_file "$listing_url" "$listing" || return 1
    names="$BUILD_ROOT/${result_prefix}.names"
    sed -n "/\\.sig/! s/.*\\(${name_prefix}-[0-9][0-9.]*\\.tar\\.gz\\).*/\\1/p" "$listing" > "$names"
    best_version=""
    best_name=""
    while IFS= read -r archive_name; do
        [ -n "$archive_name" ] || continue
        version=${archive_name#${name_prefix}-}
        version=${version%.tar.gz}
        numeric_version_newer "$version" "$best_version"
        if [ "$VERSION_NEWER" = true ]; then
            best_version="$version"
            best_name="$archive_name"
        fi
    done < "$names"
    [ -n "$best_name" ] || {
        printf '%s\n' "No stable $name_prefix release archive found at $listing_url" >&2
        return 1
    }
    case "$result_prefix" in
        STOW)
            STOW_VERSION="$best_version"
            STOW_ARCHIVE_NAME="$best_name"
            STOW_URL="${listing_url%/}/$best_name"
            ;;
        NCURSES)
            NCURSES_VERSION="$best_version"
            NCURSES_ARCHIVE_NAME="$best_name"
            NCURSES_URL="${listing_url%/}/$best_name"
            ;;
        M4)
            M4_VERSION="$best_version"
            M4_ARCHIVE_NAME="$best_name"
            M4_URL="${listing_url%/}/$best_name"
            ;;
        BISON)
            BISON_VERSION="$best_version"
            BISON_ARCHIVE_NAME="$best_name"
            BISON_URL="${listing_url%/}/$best_name"
            ;;
        *) printf '%s\n' "Internal release selection error: $result_prefix" >&2; return 1 ;;
    esac
}

# GitHub's /releases/latest endpoint excludes prereleases.  Check the response
# explicitly anyway, and require an uploaded .tar.gz asset rather than using a
# generated master/source-control archive.
discover_github_release() {
    api_url="$1"
    result_prefix="$2"
    metadata="$BUILD_ROOT/${result_prefix}.json"
    download_file "$api_url" "$metadata" || return 1
    tag=$(sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$metadata" | sed -n '1p')
    prerelease=$(sed -n 's/.*"prerelease"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p' "$metadata" | sed -n '1p')
    draft=$(sed -n 's/.*"draft"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p' "$metadata" | sed -n '1p')
    [ -n "$tag" ] || { printf '%s\n' "GitHub release response has no tag_name: $api_url" >&2; return 1; }
    [ "$prerelease" = false ] || { printf '%s\n' "Refusing prerelease GitHub release: $tag" >&2; return 1; }
    [ "$draft" = false ] || { printf '%s\n' "Refusing draft GitHub release: $tag" >&2; return 1; }
    case "$tag" in
        master|main|next|*alpha*|*beta*|*rc*|*dev*)
            printf '%s\n' "Refusing non-stable GitHub release tag: $tag" >&2
            return 1
            ;;
    esac
    asset_url=$(sed -n '/"browser_download_url"[[:space:]]*:/ { s/.*"browser_download_url"[[:space:]]*:[[:space:]]*"\([^"]*\.tar\.gz\)".*/\1/p; }' "$metadata" | sed -n '1p')
    [ -n "$asset_url" ] || { printf '%s\n' "No stable .tar.gz release asset in GitHub response: $tag" >&2; return 1; }
    case "$asset_url" in
        https://github.com/*/releases/download/*/*.tar.gz) ;;
        *) printf '%s\n' "Refusing non-release archive URL: $asset_url" >&2; return 1 ;;
    esac
    archive_name=${asset_url##*/}
    case "$result_prefix" in
        TMUX)
            TMUX_VERSION="$tag"
            TMUX_ARCHIVE_NAME="$archive_name"
            TMUX_URL="$asset_url"
            ;;
        LIBEVENT)
            LIBEVENT_VERSION="$tag"
            LIBEVENT_ARCHIVE_NAME="$archive_name"
            LIBEVENT_URL="$asset_url"
            ;;
        *) printf '%s\n' "Internal GitHub release selection error: $result_prefix" >&2; return 1 ;;
    esac
}

if [ "$SELECTION" = stow ] || [ "$SELECTION" = all ]; then
    discover_gnu_archive "https://ftp.gnu.org/gnu/stow/" stow STOW || fail "could not discover the latest stable GNU Stow release"
fi
if [ "$SELECTION" = tmux ] || [ "$SELECTION" = all ]; then
    discover_github_release "https://api.github.com/repos/tmux/tmux/releases/latest" TMUX || fail "could not discover the latest stable tmux release"
    discover_github_release "https://api.github.com/repos/libevent/libevent/releases/latest" LIBEVENT || fail "could not discover the latest stable libevent release"
    discover_gnu_archive "https://ftp.gnu.org/gnu/ncurses/" ncurses NCURSES || fail "could not discover the latest stable ncurses release"
    if [ "$NEED_M4" = true ]; then
        discover_gnu_archive "https://ftp.gnu.org/gnu/m4/" m4 M4 || fail "could not discover a stable GNU m4 release"
    fi
    if [ "$NEED_PARSER" = true ]; then
        discover_gnu_archive "https://ftp.gnu.org/gnu/bison/" bison BISON || fail "could not discover a stable GNU Bison release"
    fi
fi
build_m4() {
    archive="$DOWNLOADS/$M4_ARCHIVE_NAME"
    download_file "$M4_URL" "$archive" || return 1
    extract_archive "$archive" "$SOURCES" || return 1
    source_dir="$EXTRACTED_ROOT"
    # Build the complete tree so the generated m4 binary is linked with its
    # gnulib objects; skip documentation generation, which is not needed.
    (cd "$source_dir" && ./configure --prefix="$PARSER_PREFIX" --disable-nls && "$MAKE_CMD" -j"$JOBS" MAKEINFO=:) || return $?
    [ -x "$source_dir/src/m4" ] || { printf '%s\n' "GNU m4 build did not produce src/m4" >&2; return 1; }
    cp "$source_dir/src/m4" "$TOOLS_BIN/m4" || return 1
    chmod 755 "$TOOLS_BIN/m4" || return 1
}


build_bison() {
    archive="$DOWNLOADS/$BISON_ARCHIVE_NAME"
    download_file "$BISON_URL" "$archive" || return 1
    extract_archive "$archive" "$SOURCES" || return 1
    source_dir="$EXTRACTED_ROOT"
    # The complete build is required: Bison's gnulib objects and data
    # directory (skeletons) are part of the yacc runtime.
    (cd "$source_dir" && PATH="$TOOLS_BIN:$PATH" M4="$TOOLS_BIN/m4" ./configure --prefix="$PARSER_PREFIX" --disable-nls && PATH="$TOOLS_BIN:$PATH" "$MAKE_CMD" -j"$JOBS" MAKEINFO=: && PATH="$TOOLS_BIN:$PATH" "$MAKE_CMD" install MAKEINFO=:) || return $?
    [ -x "$PARSER_PREFIX/bin/bison" ] || { printf '%s\n' "GNU Bison install did not produce bin/bison" >&2; return 1; }
    BISON_CMD="$PARSER_PREFIX/bin/bison"
    printf '%s\n' '#!/bin/sh' "exec \"$BISON_CMD\" -y \"\$@\"" > "$TOOLS_BIN/yacc"
    chmod 755 "$TOOLS_BIN/yacc" || return 1
}

build_libevent() {
    archive="$DOWNLOADS/$LIBEVENT_ARCHIVE_NAME"
    download_file "$LIBEVENT_URL" "$archive" || return 1
    extract_archive "$archive" "$SOURCES" || return 1
    source_dir="$EXTRACTED_ROOT"
    (cd "$source_dir" && CC="$CC_CMD" ./configure --prefix="$LOCAL_PREFIX" --disable-shared --enable-static --disable-openssl && "$MAKE_CMD" -j"$JOBS" && "$MAKE_CMD" install) || return $?
}

build_ncurses() {
    archive="$DOWNLOADS/$NCURSES_ARCHIVE_NAME"
    download_file "$NCURSES_URL" "$archive" || return 1
    extract_archive "$archive" "$SOURCES" || return 1
    source_dir="$EXTRACTED_ROOT"
    (cd "$source_dir" && CC="$CC_CMD" ./configure --prefix="$LOCAL_PREFIX" --enable-widec --with-normal --with-termlib --without-shared --without-debug --without-cxx --without-ada --without-manpages --without-tests && "$MAKE_CMD" -j"$JOBS" && "$MAKE_CMD" install) || return $?
}

build_stow() {
    archive="$DOWNLOADS/$STOW_ARCHIVE_NAME"
    download_file "$STOW_URL" "$archive" || return 1
    extract_archive "$archive" "$SOURCES" || return 1
    source_dir="$EXTRACTED_ROOT"
    # Configure against the final prefix so generated Perl scripts retain the
    # correct @INC after DESTDIR staging.  Explicit runtime targets avoid
    # makeinfo, texi2html, and pod2man.
    (cd "$source_dir" && PERL="$PERL_CMD" ./configure --prefix="$PREFIX" && "$MAKE_CMD" -j"$JOBS" DESTDIR="$STAGE_ROOT" install-exec install-pmDATA install-pmstowDATA) || return $?
}

build_tmux() {
    archive="$DOWNLOADS/$TMUX_ARCHIVE_NAME"
    download_file "$TMUX_URL" "$archive" || return 1
    extract_archive "$archive" "$SOURCES" || return 1
    source_dir="$EXTRACTED_ROOT"
    include_flags="-I$LOCAL_PREFIX/include -I$LOCAL_PREFIX/include/ncursesw"
    library_flags="-L$LOCAL_PREFIX/lib -L$LOCAL_PREFIX/lib64"
    local_event="$LOCAL_PREFIX/lib/libevent_core.a"
    local_ncurses="$LOCAL_PREFIX/lib/libncursesw.a"
    local_tinfo="$LOCAL_PREFIX/lib/libtinfow.a"
    [ -f "$local_event" ] || { printf '%s\n' "Local libevent archive is missing: $local_event" >&2; return 1; }
    [ -f "$local_ncurses" ] || { printf '%s\n' "Local ncurses archive is missing: $local_ncurses" >&2; return 1; }
    [ -f "$local_tinfo" ] || { printf '%s\n' "Local wide-character terminfo archive is missing: $local_tinfo" >&2; return 1; }
    # PKG_CONFIG=false forces configure's direct checks.  Absolute archive
    # paths in the module variables prevent a fallback to system .so files;
    # absolute archive paths work with both GNU ld and the macOS linker.
    (cd "$source_dir" && PATH="$TOOLS_BIN:$PATH" YACC="$YACC_CMD" PKG_CONFIG=false \
        CPPFLAGS="$include_flags" LDFLAGS="$library_flags" \
        LIBEVENT_CORE_CFLAGS="$include_flags" LIBEVENT_CORE_LIBS="$local_event" \
        LIBEVENT_CFLAGS="$include_flags" LIBEVENT_LIBS="$local_event" \
        LIBTINFOW_CFLAGS="$include_flags" LIBTINFOW_LIBS="$local_tinfo" \
        LIBTINFO_CFLAGS="$include_flags" LIBTINFO_LIBS="$local_tinfo" \
        LIBNCURSESW_CFLAGS="$include_flags" LIBNCURSESW_LIBS="$local_ncurses $local_tinfo" \
        LIBNCURSES_CFLAGS="$include_flags" LIBNCURSES_LIBS="$local_ncurses $local_tinfo" \
        LIBS="$local_event $local_ncurses $local_tinfo" \
        CC="$CC_CMD" ./configure --prefix="$PREFIX" && \
        PATH="$TOOLS_BIN:$PATH" "$MAKE_CMD" -j"$JOBS" DESTDIR="$STAGE_ROOT" && \
        PATH="$TOOLS_BIN:$PATH" "$MAKE_CMD" DESTDIR="$STAGE_ROOT" install) || return $?
}

if [ "$NEED_M4" = true ]; then
    printf '%s\n' 'No usable GNU m4 found; bootstrapping it from a release archive.'
    build_m4 || fail 'GNU m4 bootstrap failed'
fi
if [ "$NEED_PARSER" = true ]; then
    printf '%s\n' 'No yacc/bison found; bootstrapping GNU Bison from a release archive.'
    build_bison || fail 'GNU Bison bootstrap failed'
fi

if [ "$SELECTION" = stow ] || [ "$SELECTION" = all ]; then
    printf '%s\n' "Building GNU Stow $STOW_VERSION"
    build_stow || fail "GNU Stow $STOW_VERSION build failed"
fi
if [ "$SELECTION" = tmux ] || [ "$SELECTION" = all ]; then
    printf '%s\n' "Building libevent $LIBEVENT_VERSION (static)"
    build_libevent || fail "libevent $LIBEVENT_VERSION build failed"
    printf '%s\n' "Building ncurses $NCURSES_VERSION (static wide-character library)"
    build_ncurses || fail "ncurses $NCURSES_VERSION build failed"
    printf '%s\n' "Building tmux $TMUX_VERSION"
    build_tmux || fail "tmux $TMUX_VERSION build failed"
fi

# Commit only after every requested source and dependency build has succeeded.
# This keeps a failed discovery/download/configure/build from creating a
# partial user installation.
STAGED_PREFIX="$STAGE_ROOT$PREFIX"
[ -d "$STAGED_PREFIX" ] || fail "build produced no staged files for prefix: $PREFIX"
mkdir -p "$PREFIX" || fail "cannot create installation prefix: $PREFIX"
cp -R "$STAGED_PREFIX/." "$PREFIX/" || fail "could not install into prefix: $PREFIX"

if [ "$SELECTION" = stow ] || [ "$SELECTION" = all ]; then
    printf '%s\n' "Installed GNU Stow $STOW_VERSION at $PREFIX/bin/stow"
fi
if [ "$SELECTION" = tmux ] || [ "$SELECTION" = all ]; then
    printf '%s\n' "Installed tmux $TMUX_VERSION at $PREFIX/bin/tmux"
fi
printf '%s\n' "Add this directory to PATH: $PREFIX/bin"
printf 'For the current shell: export PATH="%s/bin:$PATH"\n' "$PREFIX"
exit 0
