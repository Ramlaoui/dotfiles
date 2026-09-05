#!/usr/bin/env bash

# Dotfiles deployment entry point.
#
# The command deliberately has no side effects other than the selected phase:
#   sync  - preflight and link configuration with GNU Stow (the default)
#   deps  - install selected command-line dependencies
#   all   install dependencies, then sync using their defaults
#
# This script is written for the Bash shipped by macOS (Bash 3) as well as
# newer Bash releases.  It does not use associative arrays or Bash 4-only
# builtins.

set -o pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)" || exit 1

log_info() { printf '%s\n' "[INFO] $1"; }
log_success() { printf '%s\n' "[OK] $1"; }
log_error() { printf '%s\n' "[ERROR] $1" >&2; }
log_warning() { printf '%s\n' "[WARN] $1" >&2; }

usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [options] [names...]

Commands:
  sync [packages...]  Preflight and link configuration with GNU Stow (default)
  deps [tools...]     Install command-line dependencies
  all                 Install dependencies, then sync using their defaults

Sync options:
  --dry-run           Show the Stow plan without changing files
  --with-omarchy      Include the optional Linux Omarchy theme adapter

Dependency options:
  --no-sudo           Do not invoke sudo; unsupported local installs fail
  --auto-yes          Do not prompt before dependency installation

Common options:
  -h, --help          Show this help

With no package/tool names, sync and deps use their platform-appropriate
supported defaults.  Supported sync packages include: zsh tmux nvim git
python bash shell rofi kanata vscode linux ghostty codex zen doom wezterm.
Optional sync packages (codex, zen, doom, wezterm) are never selected by
all or a no-argument sync.  Selecting bash or zsh also selects shell.
EOF
}

COMMAND=sync
ORCHESTRATED_ALL=false
DRY_RUN=false
WITH_OMARCHY=false
NO_SUDO=false
AUTO_YES=false
HELP=false
POSITIONAL=()

# A leading command is optional: options without a command still mean sync.
if [ "$#" -gt 0 ]; then
    case "$1" in
        sync|deps|all)
            COMMAND="$1"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
    esac
fi

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run)
            if [ "$COMMAND" = deps ]; then
                log_error "--dry-run is only valid for sync"
                exit 2
            fi
            DRY_RUN=true
            ;;
        --with-omarchy)
            if [ "$COMMAND" = deps ]; then
                log_error "--with-omarchy is only valid for sync"
                exit 2
            fi
            WITH_OMARCHY=true
            ;;
        --no-sudo)
            if [ "$COMMAND" = sync ]; then
                log_error "--no-sudo is only valid for deps"
                exit 2
            fi
            NO_SUDO=true
            ;;
        --auto-yes)
            if [ "$COMMAND" = sync ]; then
                log_error "--auto-yes is only valid for deps"
                exit 2
            fi
            AUTO_YES=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            while [ "$#" -gt 0 ]; do
                POSITIONAL+=("$1")
                shift
            done
            break
            ;;
        --*)
            log_error "Unknown option: $1"
            usage >&2
            exit 2
            ;;
        *)
            POSITIONAL+=("$1")
            ;;
    esac
    shift
done

if [ "$COMMAND" = all ]; then
    # all is the only orchestration command: bootstrap dependencies first so
    # a missing Stow can be installed before the linking phase.  Its sync
    # package set remains the platform default and cannot be overridden here.
    if [ "$DRY_RUN" = true ] || [ "${#POSITIONAL[@]}" -gt 0 ]; then
        log_error "all accepts only --no-sudo, --auto-yes, and --with-omarchy"
        exit 2
    fi
    CORE_DEPENDENCY="$DOTFILES_DIR/scripts/installs/core-dependency.sh"
    if [ ! -x "$CORE_DEPENDENCY" ]; then
        log_error "Dependency module is missing or not executable: $CORE_DEPENDENCY"
        exit 1
    fi
    DEP_ARGS=()
    [ "$NO_SUDO" = true ] && DEP_ARGS+=(--no-sudo)
    [ "$AUTO_YES" = true ] && DEP_ARGS+=(--auto-yes)
    log_info "Installing dependencies before syncing dotfiles"
    "$CORE_DEPENDENCY" "${DEP_ARGS[@]}"
    status=$?
    if [ "$status" -ne 0 ]; then
        log_error "Dependency phase failed (status $status); sync was not attempted"
    fi
    ORCHESTRATED_ALL=true
    COMMAND=sync
fi

if [ "$COMMAND" = sync ] || [ "$COMMAND" = all ]; then
    # Stow package names are intentionally separate from dependency names.
    # This keeps a typo from silently turning into a package-manager request.
    SYNC_PACKAGES=()
    SUPPORTED_SYNC_PACKAGES="zsh tmux nvim git python bash shell rofi kanata vscode linux ghostty codex zen doom wezterm omarchy"
    OS_NAME="$(uname -s 2>/dev/null || printf unknown)"
    case "$OS_NAME" in
        Darwin*) OS_TYPE=macos ;;
        Linux*) OS_TYPE=linux ;;
        *) OS_TYPE=unknown ;;
    esac

    add_sync_package() {
        local candidate="$1"
        local existing
        for existing in "${SYNC_PACKAGES[@]}"; do
            [ "$existing" = "$candidate" ] && return 0
        done
        SYNC_PACKAGES+=("$candidate")
    }

    sync_package_supported() {
        local candidate="$1"
        case " $SUPPORTED_SYNC_PACKAGES " in
            *" $candidate "*) return 0 ;;
            *) return 1 ;;
        esac
    }

    if [ "$COMMAND" = all ] || [ "${#POSITIONAL[@]}" -eq 0 ]; then
        # Keep defaults platform-appropriate instead of attempting to deploy
        # Linux and macOS-only trees on every host.
        for package in zsh tmux nvim git python bash vscode; do
            add_sync_package "$package"
        done
        add_sync_package shell
        if [ "$OS_TYPE" = linux ]; then
            add_sync_package linux
            add_sync_package rofi
        elif [ "$OS_TYPE" = macos ]; then
            add_sync_package ghostty
        fi
    else
        for package in "${POSITIONAL[@]}"; do
            if ! sync_package_supported "$package"; then
                log_error "Unsupported sync package: $package"
                exit 2
            fi
            if [ "$package" = linux ] && [ "$OS_TYPE" != linux ]; then
                log_error "Sync package linux is only supported on Linux"
                exit 2
            fi
            if [ "$package" = rofi ] && [ "$OS_TYPE" != linux ]; then
                log_error "Sync package rofi is only supported on Linux"
                exit 2
            fi
            if [ "$package" = ghostty ] && [ "$OS_TYPE" != macos ]; then
                log_error "Sync package ghostty is only supported on macOS"
                exit 2
            fi
            if [ "$package" = omarchy ] && [ "$OS_TYPE" != linux ]; then
                log_error "Sync package omarchy is only supported on Linux"
                exit 2
            fi
            add_sync_package "$package"
        done
    fi

    if [ "$WITH_OMARCHY" = true ]; then
        if [ "$OS_TYPE" != linux ]; then
            log_error "--with-omarchy is only supported on Linux"
            exit 2
        fi
        add_sync_package omarchy
    fi

    # shell is the shared configuration package used by both shell startup
    # files.  Selecting either shell package must not leave that dependency
    # absent on a fresh host.
    requested_shell_package=false
    for package in "${SYNC_PACKAGES[@]}"; do
        if [ "$package" = bash ] || [ "$package" = zsh ]; then
            requested_shell_package=true
        fi
    done
    if [ "$requested_shell_package" = true ]; then
        add_sync_package shell
    fi

    # A no-argument sync creates no optional package links.  Explicit package
    # names remain an allow-listed interface, including the opt-in integrations.
    STOW_DIRS=()
    STOW_TARGETS=()
    STOW_NAMES=()
    STOW_KINDS=()
    STOW_IGNORE_CONFIG=()

    add_stow_operation() {
        STOW_DIRS+=("$1")
        STOW_TARGETS+=("$2")
        STOW_NAMES+=("$3")
        STOW_KINDS+=("$4")
        STOW_IGNORE_CONFIG+=("$5")
    }

    for package in "${SYNC_PACKAGES[@]}"; do
        package_root="$DOTFILES_DIR/$package"
        if [ ! -d "$package_root" ]; then
            log_error "Selected sync package does not exist: $package"
            exit 2
        fi

        # Root files (.bashrc, .tmux.conf, .codex, Library, ...) belong under
        # HOME.  The .config subtree is linked independently so custom XDG
        # roots work without creating a .config symlink farm.
        add_stow_operation "$DOTFILES_DIR" "$HOME" "$package" root yes

        if [ -d "$package_root/.config" ]; then
            config_target="${XDG_CONFIG_HOME:-$HOME/.config}"
            if [ "$package" = vscode ] && [ "$OS_TYPE" = macos ]; then
                # vscode/.config/Code must map to ~/Library/Application Support/Code,
                # not ~/Library/Application Support/.config/Code.
                config_target="$HOME/Library/Application Support"
            fi
            add_stow_operation "$package_root" "$config_target" .config config no
        fi
    done

    if ! command -v stow >/dev/null 2>&1; then
        log_error "GNU Stow is required for sync but was not found in PATH"
        exit 1
    fi

    # Check all planned leaf paths ourselves before invoking Stow.  GNU Stow's
    # simulation catches its own conflicts; this pass additionally catches two
    # selected packages claiming the same destination before either can mutate.
    PLANNED_DESTINATIONS=()
    PLANNED_SOURCES=()
    PREFLIGHT_FAILURE=false
    canonical_path() {
        local path="$1"
        local dir base
        if [ -d "$path" ]; then
            (cd "$path" 2>/dev/null && pwd -P)
            return $?
        fi
        dir="$(dirname "$path")"
        base="$(basename "$path")"
        (cd "$dir" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$base")
    }
    existing_link_target() {
        local path="$1"
        local link target
        link="$(readlink "$path" 2>/dev/null)" || return 1
        case "$link" in
            /*) target="$link" ;;
            *) target="$(dirname "$path")/$link" ;;
        esac
        canonical_path "$target"
    }
    source_matches_link() {
        local source="$1"
        local destination="$2"
        local source_canonical link_canonical
        source_canonical="$(canonical_path "$source")" || return 1
        link_canonical="$(existing_link_target "$destination")" || return 1
        [ "$source_canonical" = "$link_canonical" ]
    }
    check_leaf() {
        local source="$1"
        local destination="$2"
        local target_root="$3"
        local planned_index previous_source previous_destination parent

        planned_index=0
        while [ "$planned_index" -lt "${#PLANNED_DESTINATIONS[@]}" ]; do
            previous_destination="${PLANNED_DESTINATIONS[$planned_index]}"
            previous_source="${PLANNED_SOURCES[$planned_index]}"
            if [ "$previous_destination" = "$destination" ] && [ "$previous_source" != "$source" ]; then
                log_error "Planned conflict: $destination is claimed by multiple packages"
                PREFLIGHT_FAILURE=true
            fi
            planned_index=$((planned_index + 1))
        done
        PLANNED_DESTINATIONS+=("$destination")
        PLANNED_SOURCES+=("$source")

        if [ -e "$destination" ] || [ -L "$destination" ]; then
            if [ -L "$destination" ]; then
                if ! source_matches_link "$source" "$destination"; then
                    log_error "Existing symlink conflicts with $destination"
                    PREFLIGHT_FAILURE=true
                fi
            elif [ -d "$destination" ]; then
                log_error "Existing directory conflicts with file $destination"
                PREFLIGHT_FAILURE=true
            else
                log_error "Existing file conflicts with $destination"
                PREFLIGHT_FAILURE=true
            fi
        fi

        parent="$(dirname "$destination")"
        while [ "$parent" != "/" ] && [ "$parent" != "$target_root" ]; do
            if [ -f "$parent" ] || [ -L "$parent" ]; then
                log_error "Existing path blocks destination $destination"
                PREFLIGHT_FAILURE=true
                break
            fi
            parent="$(dirname "$parent")"
        done
    }

    collect_preflight_paths() {
        local index="$1"
        local stow_dir="${STOW_DIRS[$index]}"
        local target="${STOW_TARGETS[$index]}"
        local package="${STOW_NAMES[$index]}"
        local kind="${STOW_KINDS[$index]}"
        local package_root="$stow_dir/$package"
        local source relative destination
        if [ "$kind" = root ]; then
            # Root operation ignores .config and documentation.  Find is used
            # only for inspection and never writes to the repository or target.
            while IFS= read -r -d '' source; do
                relative="${source#"$package_root/"}"
                case "$relative" in
                    .config|.config/*|README.md) continue ;;
                esac
                destination="$target/$relative"
                check_leaf "$source" "$destination" "$target"
            done < <(find "$package_root" -mindepth 1 \( -type f -o -type l \) -print0 2>/dev/null)
        else
            while IFS= read -r -d '' source; do
                relative="${source#"$package_root/"}"
                destination="$target/$relative"
                check_leaf "$source" "$destination" "$target"
            done < <(find "$package_root" -mindepth 1 \( -type f -o -type l \) -print0 2>/dev/null)
        fi
    }
    index=0
    while [ "$index" -lt "${#STOW_DIRS[@]}" ]; do
        collect_preflight_paths "$index"
        index=$((index + 1))
    done
    if [ "$PREFLIGHT_FAILURE" = true ]; then
        log_error "Sync preflight failed; no files were changed"
        exit 1
    fi

    # Stow requires existing target directories.  For a real sync, missing
    # targets are simulated privately and created only after every package
    # passes simulation.  A dry-run never creates anything in the user's HOME.
    DRY_RUN_ROOT=''
    cleanup_dry_run_root() {
        if [ -n "$DRY_RUN_ROOT" ] && [ -d "$DRY_RUN_ROOT" ]; then
            rm -rf "$DRY_RUN_ROOT"
        fi
    }
    finish_dry_run() {
        status=$?
        cleanup_dry_run_root
        exit "$status"
    }
    trap finish_dry_run EXIT

    TARGETS_CREATED=()
    MISSING_TARGETS=()
    STOW_RUNTIME_TARGETS=()
    runtime_index=0
    for target in "${STOW_TARGETS[@]}"; do
        already=false
        for existing_target in "${TARGETS_CREATED[@]}"; do
            [ "$existing_target" = "$target" ] && already=true
        done
        if [ -d "$target" ]; then
            runtime_target="$target"
        else
            if [ -z "$DRY_RUN_ROOT" ]; then
                DRY_RUN_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-sync.XXXXXX")" || exit 1
            fi
            runtime_target="$DRY_RUN_ROOT/$runtime_index"
            mkdir -p "$runtime_target" || exit 1
            if [ "$already" = false ]; then
                MISSING_TARGETS+=("$target")
            fi
        fi
        STOW_RUNTIME_TARGETS+=("$runtime_target")
        if [ "$already" = false ]; then
            TARGETS_CREATED+=("$target")
        fi
        runtime_index=$((runtime_index + 1))
    done

    run_stow_operation() {
        local index="$1"
        local simulate="$2"
        local args=(--no-folding --restow "--dir=${STOW_DIRS[$index]}" "--target=${STOW_RUNTIME_TARGETS[$index]}")
        if [ "${STOW_IGNORE_CONFIG[$index]}" = yes ]; then
            args+=(--ignore='^\.config$' --ignore='^README\.md$')
        fi
        if [ "$simulate" = true ]; then
            args+=(--no)
        fi
        args+=("${STOW_NAMES[$index]}")
        stow "${args[@]}"
    }

    # Simulate every operation before any linking.  A failure from any package
    # aborts the batch, while all packages are still checked and reported.
    STOW_FAILURE=false
    index=0
    while [ "$index" -lt "${#STOW_DIRS[@]}" ]; do
        log_info "Preflighting ${STOW_NAMES[$index]} -> ${STOW_TARGETS[$index]}"
        if ! run_stow_operation "$index" true; then
            log_error "Stow preflight failed for ${STOW_NAMES[$index]}"
            STOW_FAILURE=true
        fi
        index=$((index + 1))
    done
    if [ "$STOW_FAILURE" = true ]; then
        log_error "Sync preflight failed; no files were changed"
        exit 1
    fi

    if [ "$DRY_RUN" = true ]; then
        log_success "Sync dry-run complete; no files were changed"
        exit 0
    fi

    for target in "${MISSING_TARGETS[@]}"; do
        if ! mkdir -p "$target"; then
            log_error "Cannot create Stow target: $target"
            exit 1
        fi
    done
    STOW_RUNTIME_TARGETS=("${STOW_TARGETS[@]}")

    index=0
    while [ "$index" -lt "${#STOW_DIRS[@]}" ]; do
        log_info "Stowing ${STOW_NAMES[$index]} -> ${STOW_TARGETS[$index]}"
        if ! run_stow_operation "$index" false; then
            # This should be rare because every operation was simulated first.
            # Report failure and stop rather than claiming a complete sync.
            log_error "Stow failed for ${STOW_NAMES[$index]}"
            exit 1
        fi
        index=$((index + 1))
    done
    log_success "Sync complete (${#SYNC_PACKAGES[@]} package(s))"
    if [ "$COMMAND" = sync ] && [ "$ORCHESTRATED_ALL" = false ]; then
        exit 0
    fi
    if [ "$ORCHESTRATED_ALL" = true ]; then
        # exec does not run EXIT traps; clean the private simulation tree
        # before completing the orchestrated command.
        cleanup_dry_run_root
        trap - EXIT
    fi
fi
if [ "$ORCHESTRATED_ALL" = true ]; then
    exit 0
fi

# The deps command installs tools without runtime activation or shell mutation.
DEP_ARGS=()
[ "$NO_SUDO" = true ] && DEP_ARGS+=(--no-sudo)
[ "$AUTO_YES" = true ] && DEP_ARGS+=(--auto-yes)
if [ "$COMMAND" = deps ]; then
    DEP_ARGS+=("${POSITIONAL[@]}")
fi
CORE_DEPENDENCY="$DOTFILES_DIR/scripts/installs/core-dependency.sh"
if [ ! -x "$CORE_DEPENDENCY" ]; then
    log_error "Dependency module is missing or not executable: $CORE_DEPENDENCY"
    exit 1
fi
exec "$CORE_DEPENDENCY" "${DEP_ARGS[@]}"
