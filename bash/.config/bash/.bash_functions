#!/usr/bin/env bash

# Bash-specific functions

# Create a new directory and enter it
function mkdircd() {
    mkdir -p "$1" && cd "$1"
}

# Find files by name
function find_file() {
    find . -type f -name "*$1*"
}

# Find directories by name
function find_dir() {
    find . -type d -name "*$1*"
}

# Display calendar for current month
function cal_month() {
    cal $(date +"%m %Y")
}

# Edit bash configuration quickly
function editrc() {
    $EDITOR ~/.bashrc
}

# Backup a file with timestamp
function backup_file() {
    local filename=$(basename "$1")
    local dest="${2:-$HOME/backups}"
    local timestamp=$(date +"%Y%m%d-%H%M%S")
    
    mkdir -p "$dest"
    cp -a "$1" "$dest/${filename}_${timestamp}"
    echo "Backup created: $dest/${filename}_${timestamp}"
}

# Show running services with grep filtering (bash-specific syntax)
function show_services() {
    if [[ $(uname) == "Darwin" ]]; then
        launchctl list | grep "$1"
    else
        systemctl list-units --type=service | grep "$1"
    fi
}

# Better man pages with colors (bash-specific syntax)
function man() {
    env \
        LESS_TERMCAP_md=$'\e[1;36m' \
        LESS_TERMCAP_me=$'\e[0m' \
        LESS_TERMCAP_se=$'\e[0m' \
        LESS_TERMCAP_so=$'\e[1;40;92m' \
        LESS_TERMCAP_ue=$'\e[0m' \
        LESS_TERMCAP_us=$'\e[1;32m' \
        man "$@"
}

# Extract archives of various types
function extract_file() {
    if [ -f "$1" ] ; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar e "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *)           echo "'$1' cannot be extracted via extract_file()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
} 

# Save and switch Claude Code auth profiles.
function claudeswitch() {
    local claude_dir="$HOME/.claude"
    local profiles_dir="$claude_dir/profiles"
    local active_credentials="$claude_dir/.credentials.json"
    local active_state="$HOME/.claude.json"
    local current_profile_file="$profiles_dir/.current-profile"
    local command="$1"
    local profile="$2"

    if [[ -z "$command" ]]; then
        echo "Usage: claudeswitch <save|use|list|current> [profile]"
        return 1
    fi

    mkdir -p "$profiles_dir"

    case "$command" in
        save)
            if [[ -z "$profile" ]]; then
                echo "Usage: claudeswitch save <profile>"
                return 1
            fi

            if [[ ! -f "$active_credentials" ]] || [[ ! -f "$active_state" ]]; then
                echo "Claude credentials not found in the active locations."
                return 1
            fi

            local profile_dir="$profiles_dir/$profile"
            mkdir -p "$profile_dir"
            cp "$active_credentials" "$profile_dir/.credentials.json"
            cp "$active_state" "$profile_dir/.claude.json"
            chmod 600 "$profile_dir/.credentials.json" "$profile_dir/.claude.json"
            printf '%s\n' "$profile" > "$current_profile_file"
            echo "Saved current Claude profile to $profile_dir"
            ;;
        use)
            if [[ -z "$profile" ]]; then
                echo "Usage: claudeswitch use <profile>"
                return 1
            fi

            local profile_dir="$profiles_dir/$profile"
            if [[ ! -f "$profile_dir/.credentials.json" ]] || [[ ! -f "$profile_dir/.claude.json" ]]; then
                echo "Profile '$profile' is incomplete or missing in $profile_dir"
                return 1
            fi

            cp "$profile_dir/.credentials.json" "$active_credentials"
            cp "$profile_dir/.claude.json" "$active_state"
            chmod 600 "$active_credentials" "$active_state"
            printf '%s\n' "$profile" > "$current_profile_file"
            echo "Activated Claude profile '$profile'"
            echo "Restart Claude Code if it is already running."
            ;;
        list)
            if [[ ! -d "$profiles_dir" ]]; then
                echo "No Claude profiles saved."
                return 0
            fi

            local current_profile=""
            if [[ -f "$current_profile_file" ]]; then
                current_profile=$(<"$current_profile_file")
            fi

            local found=0
            local dir
            for dir in "$profiles_dir"/*; do
                [[ -d "$dir" ]] || continue
                found=1
                local name
                name=$(basename "$dir")
                if [[ "$name" == "$current_profile" ]]; then
                    echo "* $name"
                else
                    echo "  $name"
                fi
            done

            if [[ $found -eq 0 ]]; then
                echo "No Claude profiles saved."
            fi
            ;;
        current)
            if [[ -f "$current_profile_file" ]]; then
                cat "$current_profile_file"
            else
                echo "No Claude profile has been marked current yet."
                return 1
            fi
            ;;
        *)
            echo "Usage: claudeswitch <save|use|list|current> [profile]"
            return 1
            ;;
    esac
}
