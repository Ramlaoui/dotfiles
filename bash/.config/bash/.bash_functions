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
