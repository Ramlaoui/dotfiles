#!/usr/bin/env bash

# Bash-specific aliases

# Edit bash configuration files
alias editbash="$EDITOR ~/.bashrc"
alias editbashlocal="$EDITOR ~/.bashrc.local"
alias editbashprofile="$EDITOR ~/.bash_profile"
alias editalias="$EDITOR ~/.config/bash/.bash_aliases"
alias editbashfunc="$EDITOR ~/.config/bash/.bash_functions"

# Source bash configuration
alias sourcebash="source ~/.bashrc"

# Kill last background process (bash-specific syntax)
alias kilast='kill -9 $!'

# Watch directory changes (bash-specific syntax)
alias wdir="watch -d -n 1 'ls -lah --color=auto'"

# Quick directory navigation
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

# Better defaults
alias grep="grep --color=auto"
alias mkdir="mkdir -p" 
