#!/usr/bin/env bash

# Install command-line dependencies for the dotfiles.
#
# Package names in this interface are canonical tool names (for example,
# `neovim`, `fd`, `delta`, and `venv`).  Platform package names are kept in
# the adapter below, so a package manager always receives one argument per
# package.  There is intentionally no generic "download and hope" fallback:
# --no-sudo fails clearly unless a deterministic local recipe exists.
#
# This file remains Bash 3 compatible for the Bash shipped by macOS.

set -o pipefail

PURPLE='\033[0;35m'
YELLOW='\033[0;33m'
PROGRAM=${0##*/}
SCRIPT_PATH="${BASH_SOURCE[0]}"
SCRIPT_DIR=${SCRIPT_PATH%/*}
[ "$SCRIPT_DIR" = "$SCRIPT_PATH" ] && SCRIPT_DIR=.
SCRIPT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR" 2>/dev/null && pwd -P)" || exit 1
SOURCE_STOW_INSTALLER="$SCRIPT_DIR/../misc/install_stow.sh"
SOURCE_TMUX_INSTALLER="$SCRIPT_DIR/../misc/install_tmux.sh"

RESET='\033[0m'

core_packages=(
    git curl cmake venv neovim fd delta lazygit bat eza tldr zsh htop fzf
    tmux stow ripgrep git-lfs jq starship node npm
)
optional_packages=(
    uv blesh
)

USE_SUDO=true
AUTO_YES=false
SHOW_HELP=false
SPECIFIC_PACKAGES=()

print_usage() {
    cat <<EOF
Usage: $PROGRAM [options] [tool ...]

Install dependencies using the native package manager.  Tool names are
canonical command names; platform package names are selected automatically.

Options:
  --no-sudo    Never invoke sudo. Missing tools without a local recipe fail.
  --auto-yes   Do not prompt before installing.
  -h, --help   Show this help.

Core tools: ${core_packages[*]}
Optional tools: ${optional_packages[*]}
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --no-sudo) USE_SUDO=false ;;
        --auto-yes) AUTO_YES=true ;;
        -h|--help) SHOW_HELP=true ;;
        --) shift; while [ "$#" -gt 0 ]; do SPECIFIC_PACKAGES+=("$1"); shift; done; break ;;
        --*)
            printf '%s\n' "Unknown option: $1" >&2
            print_usage >&2
            exit 2
            ;;
        *) SPECIFIC_PACKAGES+=("$1") ;;
    esac
    shift
done

if [ "$SHOW_HELP" = true ]; then
    print_usage
    exit 0
fi

if [ "${#SPECIFIC_PACKAGES[@]}" -eq 0 ]; then
    SPECIFIC_PACKAGES=("${core_packages[@]}")
fi

is_known_package() {
    local candidate="$1"
    local package
    for package in "${core_packages[@]}" "${optional_packages[@]}"; do
        [ "$candidate" = "$package" ] && return 0
    done
    return 1
}

for package in "${SPECIFIC_PACKAGES[@]}"; do
    if ! is_known_package "$package"; then
        printf '%s\n' "Unknown dependency tool: $package" >&2
        exit 2
    fi
done

if [ "$AUTO_YES" = false ]; then
    if [ ! -t 0 ]; then
        printf '%s\n' 'Dependency installation needs confirmation; use --auto-yes in a non-interactive shell.' >&2
        exit 2
    fi
    printf 'Install dependencies (%s)? [y/N] ' "${SPECIFIC_PACKAGES[*]}"
    IFS= read -r reply
    case "$reply" in
        y|Y|yes|YES|Yes) ;;
        *) printf '%s\n' 'Dependency installation cancelled.'; exit 0 ;;
    esac
fi

# Tests and CI can select a platform explicitly without changing uname.  This
# is also useful for inspecting a package plan without running a package
# manager.  Normal users simply inherit the host platform.
OS_NAME="${DOTFILES_OS:-$(uname -s 2>/dev/null || printf unknown)}"
DISTRO="${DOTFILES_DISTRO:-}"
if [ "$OS_NAME" = Darwin ] || [ "$OS_NAME" = macOS ]; then
    PLATFORM=macos
elif [ "$OS_NAME" = Linux ]; then
    if [ -z "$DISTRO" ]; then
        if [ -f /etc/arch-release ]; then
            DISTRO=arch
        elif [ -r /etc/os-release ]; then
            . /etc/os-release
            case "${ID:-}:${ID_LIKE:-}" in
                debian:*|ubuntu:*|*:debian*|*:ubuntu*) DISTRO=debian ;;
                *) printf '%s\n' "Unsupported Linux distribution: ${ID:-unknown}" >&2; exit 1 ;;
            esac
        else
            printf '%s\n' 'Cannot identify Linux distribution; set DOTFILES_DISTRO=arch or debian explicitly' >&2
            exit 1
        fi
    fi
    case "$DISTRO" in
        arch|debian) PLATFORM="$DISTRO" ;;
        *)
            printf '%s\n' "Unsupported Linux distribution: $DISTRO" >&2
            exit 1
            ;;
    esac
else
    printf '%s\n' "Unsupported operating system: $OS_NAME" >&2
    exit 1
fi

# Return the actual package-manager name for a canonical tool.  An empty
# result means this platform has no supported package-manager recipe.
platform_package_name() {
    local tool="$1"
    case "$PLATFORM:$tool" in
        arch:git|debian:git|macos:git) printf '%s\n' git ;;
        arch:curl|debian:curl|macos:curl) printf '%s\n' curl ;;
        arch:cmake|debian:cmake|macos:cmake) printf '%s\n' cmake ;;
        arch:venv|arch:python|macos:venv|macos:python) printf '%s\n' python ;;
        debian:venv) printf '%s\n' python3-venv ;;
        arch:neovim|macos:neovim) printf '%s\n' neovim ;;
        debian:neovim) printf '%s\n' neovim ;;
        arch:fd|macos:fd) printf '%s\n' fd ;;
        debian:fd) printf '%s\n' fd-find ;;
        arch:delta|debian:delta|macos:delta) printf '%s\n' git-delta ;;
        arch:lazygit|debian:lazygit|macos:lazygit) printf '%s\n' lazygit ;;
        arch:bat|debian:bat|macos:bat) printf '%s\n' bat ;;
        arch:eza|debian:eza|macos:eza) printf '%s\n' eza ;;
        arch:tldr|debian:tldr|macos:tldr) printf '%s\n' tldr ;;
        arch:zsh|debian:zsh|macos:zsh) printf '%s\n' zsh ;;
        arch:htop|debian:htop|macos:htop) printf '%s\n' htop ;;
        arch:fzf|debian:fzf|macos:fzf) printf '%s\n' fzf ;;
        arch:tmux|debian:tmux|macos:tmux) printf '%s\n' tmux ;;
        arch:stow|debian:stow|macos:stow) printf '%s\n' stow ;;
        arch:ripgrep|debian:ripgrep|macos:ripgrep) printf '%s\n' ripgrep ;;
        arch:git-lfs|debian:git-lfs|macos:git-lfs) printf '%s\n' git-lfs ;;
        arch:jq|debian:jq|macos:jq) printf '%s\n' jq ;;
        arch:starship|debian:starship|macos:starship) printf '%s\n' starship ;;
        arch:node) printf '%s\n' nodejs ;;
        debian:node) printf '%s\n' nodejs ;;
        macos:node) printf '%s\n' node ;;
        arch:npm|debian:npm) printf '%s\n' npm ;;
        macos:npm) printf '%s\n' node ;;
        macos:uv) printf '%s\n' uv ;;
        arch:uv) printf '%s\n' uv ;;
        # uv is not a package in the supported Debian base repositories.
        *) return 1 ;;
    esac
}

command_for_tool() {
    case "$1" in
        neovim) printf '%s\n' nvim ;;
        venv) printf '%s\n' python3 ;;
        ripgrep) printf '%s\n' rg ;;
        git-lfs) printf '%s\n' git-lfs ;;
        *) printf '%s\n' "$1" ;;
    esac
}

is_tool_installed() {
    local tool="$1"
    if [ "$tool" = blesh ]; then
        [ -r "${XDG_DATA_HOME:-$HOME/.local/share}/blesh/ble.sh" ]
        return $?
    fi
    if [ "$tool" = venv ]; then
        command -v python3 >/dev/null 2>&1 && python3 -c 'import venv, ensurepip' >/dev/null 2>&1
        return $?
    fi
    if [ "$tool" = fd ]; then
        command -v fd >/dev/null 2>&1 || command -v fdfind >/dev/null 2>&1
        return $?
    fi
    if [ "$tool" = bat ]; then
        command -v bat >/dev/null 2>&1 || command -v batcat >/dev/null 2>&1
        return $?
    fi
    command -v "$(command_for_tool "$tool")" >/dev/null 2>&1
}
# User-local source recipes are deliberately few. Stow and tmux are handled by
# their matching standalone entrypoints. The other recipes remain pinned
# because they are unrelated to this source bootstrap.
local_source_installer() {
    case "$1" in
        stow) printf '%s\n' "$SOURCE_STOW_INSTALLER" ;;
        tmux) printf '%s\n' "$SOURCE_TMUX_INSTALLER" ;;
        *) return 1 ;;
    esac
}

local_recipe_supported() {
    local tool="$1"
    local installer
    case "$tool" in
        stow|tmux)
            installer="$(local_source_installer "$tool")"
            if [ ! -x "$installer" ]; then
                printf '%s\n' "No supported source installer for $tool: $installer" >&2
                return 1
            fi
            ;;
        fzf)
            for prerequisite in git make go; do
                command -v "$prerequisite" >/dev/null 2>&1 || {
                    printf '%s\n' "Missing local-build prerequisite for fzf: $prerequisite" >&2
                    return 1
                }
            done
            ;;
        blesh)
            for prerequisite in git make gawk; do
                command -v "$prerequisite" >/dev/null 2>&1 || {
                    printf '%s\n' "Missing local-build prerequisite for blesh: $prerequisite" >&2
                    if [ "$PLATFORM" = macos ] && [ "$prerequisite" = gawk ]; then
                        printf '%s\n' 'Install it with: brew install gawk' >&2
                    fi
                    return 1
                }
            done
            case "$(make --version 2>/dev/null)" in
                *"GNU Make"*) ;;
                *)
                    printf '%s\n' 'GNU make is required to build blesh; make must resolve to GNU make' >&2
                    return 1
                    ;;
            esac
            ;;
        *)
            printf '%s\n' "No supported deterministic local recipe for $tool" >&2
            return 1
            ;;
    esac
}

BUILD_ROOT=''
cleanup_build_root() {
    if [ -n "$BUILD_ROOT" ] && [ -d "$BUILD_ROOT" ]; then
        rm -rf "$BUILD_ROOT"
    fi
}
finish_build() {
    status=$?
    cleanup_build_root
    exit "$status"
}
trap finish_build EXIT
trap 'exit 130' INT TERM

clone_pinned_source() {
    local url="$1"
    local commit="$2"
    local destination="$3"
    local status
    mkdir -p "$destination"
    status=$?
    [ "$status" -eq 0 ] || return "$status"
    git -C "$destination" init -q
    status=$?
    [ "$status" -eq 0 ] || return "$status"
    git -C "$destination" remote add origin "$url"
    status=$?
    [ "$status" -eq 0 ] || return "$status"
    git -C "$destination" fetch --depth 1 origin "$commit"
    status=$?
    [ "$status" -eq 0 ] || return "$status"
    git -C "$destination" checkout --detach "$commit"
    status=$?
    [ "$status" -eq 0 ] || return "$status"
    if [ "$(git -C "$destination" rev-parse HEAD)" != "$commit" ]; then
        printf '%s\n' "Pinned checkout verification failed for $url" >&2
        return 1
    fi
}

install_local_tool() {
    local tool="$1"
    local source_dir
    local status
    mkdir -p "$HOME/.local/bin"
    status=$?
    [ "$status" -eq 0 ] || return "$status"
    if [ -z "$BUILD_ROOT" ]; then
        BUILD_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-deps.XXXXXX")"
        status=$?
        [ "$status" -eq 0 ] || return "$status"
    fi
    case "$tool" in
        fzf)
            source_dir="$BUILD_ROOT/fzf"
            clone_pinned_source "https://github.com/junegunn/fzf.git" "6765f464a60e39afc20775f54f7ba40896bf1b81" "$source_dir"
            status=$?
            [ "$status" -eq 0 ] || return "$status"
            (cd "$source_dir" && make bin/fzf)
            status=$?
            [ "$status" -eq 0 ] || return "$status"
            cp "$source_dir/bin/fzf" "$HOME/.local/bin/fzf"
            status=$?
            [ "$status" -eq 0 ] || return "$status"
            chmod 755 "$HOME/.local/bin/fzf"
            status=$?
            [ "$status" -eq 0 ] || return "$status"
            ;;
        blesh)
            source_dir="$BUILD_ROOT/blesh"
            clone_pinned_source "https://github.com/akinomyoga/ble.sh.git" "1a5c451c8baa71439a6be4ea0f92750de35a7620" "$source_dir"
            status=$?
            [ "$status" -eq 0 ] || return "$status"
            git -C "$source_dir" submodule update --init --depth 1 -- contrib
            status=$?
            [ "$status" -eq 0 ] || return "$status"
            # Make treats whitespace in target paths as separators. Stage using
            # a relative path, then copy to the user's possibly spaced XDG path.
            (cd "$source_dir" && make install INSDIR=out-install)
            status=$?
            [ "$status" -eq 0 ] || return "$status"
            mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/blesh"
            status=$?
            [ "$status" -eq 0 ] || return "$status"
            cp -R "$source_dir/out-install/." "${XDG_DATA_HOME:-$HOME/.local/share}/blesh/"
            status=$?
            [ "$status" -eq 0 ] || return "$status"
            ;;
        *)
            printf '%s\n' "No local recipe implementation for $tool" >&2
            return 1
            ;;
    esac
}

# Build the complete package request before mutation.  This catches an
# unsupported package, missing build prerequisite, or missing manager without
# partially installing a preceding tool.
export PATH="$HOME/.local/bin:$PATH"
MISSING_TOOLS=()
LOCAL_TOOLS=()
MANAGER_PACKAGES=()
SOURCE_STOW=false
SOURCE_TMUX=false
PREFLIGHT_FAILURE=false
for tool in "${SPECIFIC_PACKAGES[@]}"; do
    if is_tool_installed "$tool"; then
        printf '%s\n' "$tool is already installed; skipping."
        continue
    fi
    MISSING_TOOLS+=("$tool")
    LOCAL_MODE=false
    if [ "$PLATFORM" = macos ] && [ "$tool" = blesh ]; then
        LOCAL_MODE=true
    elif [ "$USE_SUDO" = false ]; then
        if [ "$PLATFORM" != macos ] || [ "$tool" = stow ] || [ "$tool" = tmux ]; then
            LOCAL_MODE=true
        fi
    fi
    if [ "$LOCAL_MODE" = true ]; then
        if local_recipe_supported "$tool"; then
            LOCAL_TOOLS+=("$tool")
            [ "$tool" = stow ] && SOURCE_STOW=true
            [ "$tool" = tmux ] && SOURCE_TMUX=true
        else
            PREFLIGHT_FAILURE=true
        fi
        continue
    fi
    package_name="$(platform_package_name "$tool" 2>/dev/null || true)"
    if [ -z "$package_name" ]; then
        printf '%s\n' "No supported package-manager recipe for $tool on $PLATFORM" >&2
        PREFLIGHT_FAILURE=true
    else
        duplicate=false
        for existing_package in "${MANAGER_PACKAGES[@]}"; do
            [ "$existing_package" = "$package_name" ] && duplicate=true
        done
        [ "$duplicate" = false ] && MANAGER_PACKAGES+=("$package_name")
    fi
done

if [ "$PREFLIGHT_FAILURE" = true ]; then
    exit 1
fi
if [ "${#MISSING_TOOLS[@]}" -eq 0 ]; then
    printf '%s\n' 'All requested dependencies are already installed.'
    exit 0
fi

if [ "${#MANAGER_PACKAGES[@]}" -gt 0 ]; then
    MANAGER=''
    case "$PLATFORM" in
        macos) MANAGER=brew ;;
        arch) MANAGER=pacman ;;
        debian) MANAGER=apt-get ;;
    esac

    if ! command -v "$MANAGER" >/dev/null 2>&1; then
        printf '%s\n' "Required package manager is not installed: $MANAGER" >&2
        exit 1
    fi
    if [ "$PLATFORM" = debian ]; then
        if ! command -v apt-cache >/dev/null 2>&1; then
            printf '%s\n' 'apt-cache is required to verify Debian package availability before installation' >&2
            exit 1
        fi
        for package_name in "${MANAGER_PACKAGES[@]}"; do
            package_info="$(apt-cache show "$package_name" 2>/dev/null || true)"
            if [ -z "$package_info" ]; then
                printf '%s\n' "Debian package is unavailable in the configured repositories: $package_name" >&2
                PREFLIGHT_FAILURE=true
            fi
        done
        [ "$PREFLIGHT_FAILURE" = false ] || exit 1
    fi
    if [ "$USE_SUDO" = true ] && [ "$PLATFORM" != macos ] && ! command -v sudo >/dev/null 2>&1; then
        printf '%s\n' "sudo is required for $PLATFORM dependency installation; use --no-sudo for a supported local recipe" >&2
        exit 1
    fi
fi
if [ "$SOURCE_STOW" = true ]; then
    printf '%s\n' 'Delegating stow to its standalone source installer without sudo'
    "$SOURCE_STOW_INSTALLER" --prefix "$HOME/.local"
    status=$?
    if [ "$status" -ne 0 ]; then
        printf '%s\n' "Source build failed for stow (status $status)" >&2
        exit "$status"
    fi
fi
if [ "$SOURCE_TMUX" = true ]; then
    printf '%s\n' 'Delegating tmux to its standalone source installer without sudo'
    "$SOURCE_TMUX_INSTALLER" --prefix "$HOME/.local"
    status=$?
    if [ "$status" -ne 0 ]; then
        printf '%s\n' "Source build failed for tmux (status $status)" >&2
        exit "$status"
    fi
fi

for tool in "${LOCAL_TOOLS[@]}"; do
    case "$tool" in
        stow|tmux) continue ;;
    esac
    printf '%s\n' "Building $tool from its pinned source revision"
    install_local_tool "$tool"
    status=$?
    if [ "$status" -ne 0 ]; then
        printf '%s\n' "Local build failed for $tool (status $status)" >&2
        exit "$status"
    fi
done

if [ "${#MANAGER_PACKAGES[@]}" -gt 0 ]; then
    printf '%s\n' "Installing package(s): ${MANAGER_PACKAGES[*]}"
    case "$PLATFORM" in
        macos)
            brew install "${MANAGER_PACKAGES[@]}"
            ;;
        arch)
            sudo pacman -S --needed --noconfirm "${MANAGER_PACKAGES[@]}"
            ;;
        debian)
            sudo apt-get install -y "${MANAGER_PACKAGES[@]}"
            ;;
    esac
    status=$?
    if [ "$status" -ne 0 ]; then
        printf '%s\n' "Package manager failed (status $status)" >&2
        exit "$status"
    fi
fi

# Do not claim success merely because an installer returned zero. Verify every
# requested tool after both source and package-manager installations.
POST_FAILURE=false
for tool in "${SPECIFIC_PACKAGES[@]}"; do
    if ! is_tool_installed "$tool"; then
        printf '%s\n' "Dependency installation reported success but $tool is unavailable" >&2
        POST_FAILURE=true
    fi
done
if [ "$POST_FAILURE" = true ]; then
    exit 1
fi
printf '%s\n' 'Dependency installation complete.'
exit 0
