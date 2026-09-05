#!/usr/bin/env bash

# Bash-specific aliases
_shell_bash_config=${XDG_CONFIG_HOME:-$HOME/.config}/bash
_shell_shared_config=${XDG_CONFIG_HOME:-$HOME/.config}/shell
alias editbash="${EDITOR:-vi} \"$HOME/.bashrc\""
alias editbashlocal="${EDITOR:-vi} \"$HOME/.bashrc.local\""
alias editbashprofile="${EDITOR:-vi} \"$HOME/.bash_profile\""
alias editalias="${EDITOR:-vi} \"$_shell_bash_config/.bash_aliases\""
alias editbashfunc="${EDITOR:-vi} \"$_shell_bash_config/.bash_functions\""
alias editshell="${EDITOR:-vi} \"$_shell_shared_config\""

alias sourcebash='source "$HOME/.bashrc"'
alias kilast='kill -9 %%'
alias wdir="watch -d -n 1 'ls -lah --color=auto'"
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias grep='grep --color=auto'
alias mkdir='mkdir -p'
unset _shell_bash_config _shell_shared_config
