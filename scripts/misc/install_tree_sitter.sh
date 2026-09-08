#!/usr/bin/env bash
# Install a verified Tree-sitter release, building the same version locally
# when its official binary cannot run against the host's system libraries.
set -o pipefail

PROGRAM=${0##*/}
SCRIPT_PATH=${BASH_SOURCE[0]}
SCRIPT_DIR=${SCRIPT_PATH%/*}
[ "$SCRIPT_DIR" = "$SCRIPT_PATH" ] && SCRIPT_DIR=.
SCRIPT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR" && pwd -P)" || exit 1
. "$SCRIPT_DIR/../installs/source-common.sh" || exit 1
PREFIX="${HOME:-}/.local"
PREFIX_GIVEN=false
VERSION=latest
JOBS=${CARGO_BUILD_JOBS:-2}
WORK=''
STAGE=''
LINK_DIR=''
CREATED_ROOT=''
BIN_LINK=''
RELATIVE_TARGET=''

fail() { printf '%s: %s\n' "$PROGRAM" "$*" >&2; exit 1; }
cleanup() {
    local status=$?
    source_common_cleanup "$LINK_DIR"
    source_common_cleanup "$STAGE"
    # Inspect activation itself, including interruption immediately after mv.
    if [ -n "$CREATED_ROOT" ] && {
        [ ! -L "$BIN_LINK" ] || [ "$(readlink "$BIN_LINK")" != "$RELATIVE_TARGET" ];
    }; then
        rm -rf "$CREATED_ROOT"
    fi
    source_common_cleanup "$WORK"
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

while [ "$#" -gt 0 ]; do
    case "$1" in
        --prefix) [ "$#" -ge 2 ] || fail '--prefix requires a path'; PREFIX=$2; PREFIX_GIVEN=true; shift 2 ;;
        --prefix=*) PREFIX=${1#*=}; PREFIX_GIVEN=true; shift ;;
        --version) [ "$#" -ge 2 ] || fail '--version requires a version'; VERSION=$2; shift 2 ;;
        --version=*) VERSION=${1#*=}; shift ;;
        --jobs) [ "$#" -ge 2 ] || fail '--jobs requires a count'; JOBS=$2; shift 2 ;;
        --jobs=*) JOBS=${1#*=}; shift ;;
        -h|--help)
            cat <<EOF
Usage: $PROGRAM [--prefix PATH] [--version VERSION] [--jobs N]

Install the official Tree-sitter CLI into PREFIX/bin (default: \$HOME/.local).
Versions default to latest stable; source-build jobs default to
\$CARGO_BUILD_JOBS or 2. Linux GNU and macOS, x86_64/arm64 are supported.

A verified binary that cannot run triggers an exact-version native Cargo
build. A native C compiler is then required; missing or outdated Rust is
bootstrapped temporarily from verified official components. Neither Rust
nor Cargo state is installed into your home, and no shell files are edited.
EOF
            exit 0 ;;
        --) shift; [ "$#" -eq 0 ] || fail 'unexpected positional argument' ;;
        *) fail "unknown option: $1" ;;
    esac
done
[ "$PREFIX_GIVEN" = true ] || [ -n "${HOME:-}" ] || fail 'HOME is required without --prefix'
source_common_validate_prefix "$PREFIX" || exit 1
source_common_validate_jobs "$JOBS" || exit 1
for utility in gzip awk sed tar mktemp mkdir cp mv rm ln readlink chmod uname tr; do
    command -v "$utility" >/dev/null 2>&1 || fail "required command not found: $utility"
done
command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || fail 'curl or wget is required'
command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 || fail 'sha256sum or shasum is required'

case "$(uname -s)" in
    Linux) OS=linux; TARGET_SUFFIX=unknown-linux-gnu ;;
    Darwin) OS=macos; TARGET_SUFFIX=apple-darwin ;;
    *) fail 'only Linux GNU and macOS are supported' ;;
esac
case "$(uname -m)" in
    x86_64|amd64) ARCH=x64; TARGET="x86_64-$TARGET_SUFFIX" ;;
    arm64|aarch64) ARCH=arm64; TARGET="aarch64-$TARGET_SUFFIX" ;;
    *) fail 'only x86_64 and arm64 are supported' ;;
esac
WORK=$(mktemp -d "${TMPDIR:-/tmp}/install-tree-sitter.XXXXXX") || fail 'cannot create private build directory'
RELEASES=https://github.com/tree-sitter/tree-sitter/releases
if [ "$VERSION" = latest ]; then
    source_common_download "$RELEASES/latest" "$WORK/latest.html" || exit 1
    VERSION=$(sed -n 's#.*tree-sitter/tree-sitter/releases/tag/v\([^"<>/?[:space:]]*\).*#\1#p' "$WORK/latest.html" | sed -n '1p')
fi
VERSION=${VERSION#v}
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "invalid stable version: $VERSION"
ROOT="$PREFIX/lib/tree-sitter-v$VERSION"
BIN_LINK="$PREFIX/bin/tree-sitter"
RELATIVE_TARGET="../lib/tree-sitter-v$VERSION/bin/tree-sitter"
for directory in "$PREFIX" "$PREFIX/bin" "$PREFIX/lib" "$ROOT"; do
    [ ! -L "$directory" ] || fail "refusing symlinked installation directory: $directory"
    [ ! -e "$directory" ] || [ -d "$directory" ] || fail "not a directory: $directory"
done
if [ -e "$BIN_LINK" ] || [ -L "$BIN_LINK" ]; then
    [ -L "$BIN_LINK" ] || fail "refusing unrelated file: $BIN_LINK"
    old_target=$(readlink "$BIN_LINK") || fail 'cannot inspect existing Tree-sitter link'
    case "$old_target" in
        ../lib/tree-sitter-v*/bin/tree-sitter)
            old_version=${old_target#../lib/tree-sitter-v}
            old_version=${old_version%/bin/tree-sitter}
            [[ "$old_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "unrelated link: $BIN_LINK" ;;
        *) fail "unrelated link: $BIN_LINK" ;;
    esac
fi
if [ -e "$ROOT" ]; then
    [ -L "$BIN_LINK" ] && [ "$(readlink "$BIN_LINK")" = "$RELATIVE_TARGET" ] || fail "refusing existing root without its managed link: $ROOT"
    [ ! -L "$ROOT/bin" ] && [ ! -L "$ROOT/bin/tree-sitter" ] || fail "refusing symlinked content in $ROOT"
    reported_version=$("$ROOT/bin/tree-sitter" --version) || fail "existing Tree-sitter cannot run: $ROOT"
    case "$reported_version" in
        "tree-sitter $VERSION"|"tree-sitter $VERSION "*) ;;
        *) fail "existing root does not contain Tree-sitter $VERSION: $ROOT" ;;
    esac
    printf '%s\n' "Tree-sitter $VERSION is already installed at $ROOT"
    exit 0
fi

ASSET="tree-sitter-$OS-$ARCH.gz"
source_common_download "$RELEASES/expanded_assets/v$VERSION" "$WORK/assets.html" || exit 1
CHECKSUM=$(awk -v asset="/$ASSET\"" '
    index($0, "/releases/download/") && index($0, asset) { found=1; next }
    found && index($0, "/releases/download/") { exit }
    found && index($0, "sha256:") {
        sub(/^.*sha256:[[:space:]]*/, "")
        sub(/[^0-9A-Fa-f].*$/, "")
        if (length($0) == 64) print tolower($0)
        exit
    }
' "$WORK/assets.html")
[ "${#CHECKSUM}" -eq 64 ] || fail "release has no SHA256 metadata for $ASSET"
source_common_download "$RELEASES/download/v$VERSION/$ASSET" "$WORK/$ASSET" || exit 1
source_common_verify_sha256 "$WORK/$ASSET" "$CHECKSUM" || exit 1
CANDIDATE="$WORK/tree-sitter"
gzip -dc "$WORK/$ASSET" > "$CANDIDATE" || fail 'cannot decompress verified release'
chmod 755 "$CANDIDATE" || exit 1

# Both official TOML files use ordinary quoted values in named sections.
toml_value() {
    awk -v section="[$2]" -v key="$3" '
        $0 == section { found=1; next }
        found && /^\[/ { exit }
        found && $0 ~ ("^[[:space:]]*" key "[[:space:]]*=") {
            sub(/^[^=]*=[[:space:]]*"/, "")
            sub(/".*$/, "")
            print; exit
        }
    ' "$1"
}
rust_is_current_enough() {
    local have=$1 need=$2
    [[ "$have" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
    [[ "$need" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || return 1
    awk -v have="$have" -v need="$need" 'BEGIN {
        split(have,h,"."); split(need,n,".")
        for (i=1;i<=3;i++) { if (h[i]+0>n[i]+0) exit 0; if (h[i]+0<n[i]+0) exit 1 }
        exit 0
    }'
}

INSTALL_KIND='official binary'
if ! "$CANDIDATE" --version > "$WORK/binary-probe.log" 2>&1; then
    printf '%s\n' 'Verified release binary cannot run on this host; building the same version locally.' >&2
    sed -n '1,12p' "$WORK/binary-probe.log" >&2
    CC_BIN=$(command -v "${CC:-cc}" 2>/dev/null) || fail 'a native C compiler (CC or cc) is required for source fallback'
    [ -x "$CC_BIN" ] || fail "compiler is not an executable file: $CC_BIN"
    CARGO=$(command -v cargo 2>/dev/null || true)
    RUSTC=$(command -v rustc 2>/dev/null || true)
    REUSE_RUST=false
    if [ -n "$CARGO" ] && [ -n "$RUSTC" ] && "$CARGO" --version >/dev/null 2>&1; then
        have=$("$RUSTC" --version 2>/dev/null | sed -n 's/^rustc \([0-9.]*\).*/\1/p')
        if source_common_download "https://raw.githubusercontent.com/tree-sitter/tree-sitter/v$VERSION/Cargo.toml" "$WORK/tree-sitter-Cargo.toml"; then
            need=$(toml_value "$WORK/tree-sitter-Cargo.toml" workspace.package rust-version)
            if rust_is_current_enough "$have" "$need"; then
                # Resolve rustup shims before isolating HOME; never use or
                # modify the user's rustup state during the Cargo build.
                sysroot=$("$RUSTC" --print sysroot) || fail 'cannot resolve Rust sysroot'
                if [ -x "$sysroot/bin/cargo" ] && [ -x "$sysroot/bin/rustc" ]; then
                    CARGO="$sysroot/bin/cargo"; RUSTC="$sysroot/bin/rustc"
                    REUSE_RUST=true
                fi
            fi
        fi
    fi
    if [ "$REUSE_RUST" != true ]; then
        printf '%s\n' 'Bootstrapping a private, temporary Rust toolchain.'
        source_common_download https://static.rust-lang.org/dist/channel-rust-stable.toml "$WORK/rust.toml" || exit 1
        url_key=url; hash_key=hash
        if command -v xz >/dev/null 2>&1; then url_key=xz_url; hash_key=xz_hash; fi
        for component in cargo rustc rust-std; do
            section="pkg.$component.target.$TARGET"
            url=$(toml_value "$WORK/rust.toml" "$section" "$url_key")
            hash=$(toml_value "$WORK/rust.toml" "$section" "$hash_key")
            case "$url" in
                https://static.rust-lang.org/dist/*.tar.gz|https://static.rust-lang.org/dist/*.tar.xz) ;;
                *) fail "Rust manifest has no official $component archive for $TARGET" ;;
            esac
            [[ "$hash" =~ ^[0-9a-f]{64}$ ]] || fail "Rust manifest has no valid $component checksum"
            archive="$WORK/${url##*/}"
            archive_root=${url##*/}; archive_root=${archive_root%.tar.*}
            source_common_download "$url" "$archive" || exit 1
            source_common_verify_sha256 "$archive" "$hash" || exit 1
            source_common_extract "$archive" "$WORK" "$archive_root" || exit 1
            # Rust's installer accepts --prefix=VALUE, not two arguments.
            "$WORK/$archive_root/install.sh" --prefix="$WORK/rust" --disable-ldconfig || fail "cannot install temporary Rust $component"
        done
        CARGO="$WORK/rust/bin/cargo"; RUSTC="$WORK/rust/bin/rustc"
    fi
    mkdir -p "$WORK/home" "$WORK/cargo-home" || exit 1
    linker_key="CARGO_TARGET_$(printf '%s' "$TARGET" | tr 'a-z-' 'A-Z_')_LINKER"
    (
        export HOME="$WORK/home" XDG_CONFIG_HOME="$WORK/home/.config"
        export XDG_DATA_HOME="$WORK/home/.local/share" XDG_CACHE_HOME="$WORK/home/.cache"
        export XDG_STATE_HOME="$WORK/home/.local/state" RUSTUP_HOME="$WORK/rustup"
        export CARGO_HOME="$WORK/cargo-home" CARGO_TARGET_DIR="$WORK/target"
        export RUSTC CC="$CC_BIN" "$linker_key=$CC_BIN"
        export PATH="${RUSTC%/*}:$PATH"
        # Rust 1.90+ forces bundled LLD on this target. Compiler wrappers such
        # as Cray cc need their own linker to understand their plugin options.
        compiler_version=$("$RUSTC" --version | sed -n 's/^rustc \([0-9.]*\).*/\1/p')
        if [ "$TARGET" = x86_64-unknown-linux-gnu ] && rust_is_current_enough "$compiler_version" 1.90.0; then
            if [ -n "${CARGO_ENCODED_RUSTFLAGS:-}" ]; then
                export CARGO_ENCODED_RUSTFLAGS="${CARGO_ENCODED_RUSTFLAGS}$(printf '\037')-Clinker-features=-lld"
            else
                export RUSTFLAGS="${RUSTFLAGS:-} -Clinker-features=-lld"
            fi
        fi
        cd "$WORK" || exit 1
        # An explicit --target would exclude host build scripts/proc macros
        # from RUSTFLAGS, reintroducing the incompatible bundled linker.
        unset CARGO_BUILD_TARGET
        "$CARGO" install --locked --version "=$VERSION" \
            --jobs "$JOBS" --root "$WORK/built" tree-sitter-cli
    ) || fail "native tree-sitter-cli $VERSION build failed"
    CANDIDATE="$WORK/built/bin/tree-sitter"
    "$CANDIDATE" --version || fail 'native source-built Tree-sitter cannot run'
    INSTALL_KIND='native source build'
fi

# Private same-filesystem staging makes activation a single link replacement.
# Assign cleanup ownership only after mktemp succeeds, never on collision.
mkdir -p "$PREFIX/lib" "$PREFIX/bin" || exit 1
STAGE=$(mktemp -d "$PREFIX/lib/.tree-sitter.XXXXXX") || fail 'cannot create installation staging directory'
mkdir "$STAGE/bin" || exit 1
cp "$CANDIDATE" "$STAGE/bin/tree-sitter" || exit 1
"$STAGE/bin/tree-sitter" --version || fail 'staged executable cannot run from this prefix'
# Recheck after the build, then record ownership before the rename: a signal
# may run the EXIT trap before the shell executes the next assignment.
[ ! -e "$ROOT" ] && [ ! -L "$ROOT" ] || fail "installation root appeared during the build: $ROOT"
CREATED_ROOT="$ROOT"
mv "$STAGE" "$ROOT" || exit 1
STAGE=''
LINK_DIR=$(mktemp -d "$PREFIX/bin/.tree-sitter.XXXXXX") || fail 'cannot stage managed link'
ln -s "$RELATIVE_TARGET" "$LINK_DIR/tree-sitter" || exit 1
mv -f "$LINK_DIR/tree-sitter" "$BIN_LINK" || exit 1
printf '%s\n' "Installed Tree-sitter $VERSION ($INSTALL_KIND) at $BIN_LINK"
printf '%s\n' "Add this directory to PATH: $PREFIX/bin"
