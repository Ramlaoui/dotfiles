#!/usr/bin/env bash

# Establish only the default XDG lookup when the caller has not supplied one.
_shell_config=${XDG_CONFIG_HOME:-${HOME:-.}/.config}/shell
[[ -r "$_shell_config/env" ]] && source -- "$_shell_config/env"
_shell_config=${XDG_CONFIG_HOME:-${HOME:-.}/.config}/shell

# Local host settings are explicit and optional.
[[ -r "${HOME:-.}/.bashrc.local" ]] && source -- "${HOME:-.}/.bashrc.local"

# Non-interactive shells still receive the shared environment above.
[[ $- != *i* ]] && return

# Load ble.sh early so it can wrap the readline-compatible settings below.
if [[ -r "${XDG_DATA_HOME:-${HOME:-.}/.local/share}/blesh/ble.sh" ]]; then
    source -- "${XDG_DATA_HOME:-${HOME:-.}/.local/share}/blesh/ble.sh" --attach=none
fi

# Shared aliases/functions are optional when only Bash is deployed.
[[ -r "$_shell_config/aliases" ]] && source -- "$_shell_config/aliases"
[[ -r "$_shell_config/functions" ]] && source -- "$_shell_config/functions"

# Bash-only additions remain in the Bash package.
_shell_bash_config=${XDG_CONFIG_HOME:-${HOME:-.}/.config}/bash
[[ -r "$_shell_bash_config/.bash_aliases" ]] && source -- "$_shell_bash_config/.bash_aliases"
[[ -r "$_shell_bash_config/.bash_functions" ]] && source -- "$_shell_bash_config/.bash_functions"

if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
else
    PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
fi

HISTCONTROL=ignoredups
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend
shopt -s checkwinsize

if [[ -r /etc/bash_completion ]]; then
    source -- /etc/bash_completion
fi

if command -v fzf >/dev/null 2>&1; then
    if [[ ${BLE_VERSION-} ]]; then
        ble-import -d integration/fzf-completion
        ble-import -d integration/fzf-key-bindings
    else
        source <(fzf --bash)
    fi
fi

[[ ${BLE_VERSION-} || ! -r "${HOME:-.}/.fzf.bash" ]] || source -- "${HOME:-.}/.fzf.bash"
[[ ! -r "${HOME:-.}/.local/bin/env" ]] || source -- "${HOME:-.}/.local/bin/env"

if [[ ${BLE_VERSION-} ]]; then
    ble-bind -m vi_imap -f 'C-m' 'accept-line syntax'
    ble-bind -m vi_imap -f 'RET' 'accept-line syntax'
    ble-bind -m vi_imap -f 'C-j' 'accept-line syntax'
    ble-bind -m vi_nmap -f 'C-m' 'accept-line syntax'
    ble-bind -m vi_nmap -f 'RET' 'accept-line syntax'
    ble-bind -m vi_nmap -f 'C-j' 'accept-line syntax'
    ble-bind -m vi_imap -f 'C-c' discard-line
    ble-bind -m vi_nmap -f 'C-c' discard-line
    ble-attach
fi

unset _shell_config _shell_bash_config
