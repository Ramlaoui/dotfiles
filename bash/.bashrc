#!/usr/bin/env bash

# Set directories
BASH_DIR=$HOME/.config/bash
ZSH_DIR=$HOME/.config/zsh

# Source shared configuration files from zsh
# Source exports (shared with zsh)
[[ ! -f $ZSH_DIR/.exports ]] || source $ZSH_DIR/.exports

# Source local bash config (for machine-specific settings)
[[ ! -f $HOME/.bashrc.local ]] || source $HOME/.bashrc.local

# Add node to PATH
export PATH=$XDG_DATA_HOME/node/bin:$PATH

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

export TERM='xterm-256color'

# Source aliases (shared with zsh)
[[ ! -f $ZSH_DIR/.aliases ]] || source $ZSH_DIR/.aliases

# Source functions (shared with zsh)
[[ ! -f $ZSH_DIR/.functions ]] || source $ZSH_DIR/.functions

# Source bash-specific config files
[[ ! -f $BASH_DIR/.bash_aliases ]] || source $BASH_DIR/.bash_aliases
[[ ! -f $BASH_DIR/.bash_functions ]] || source $BASH_DIR/.bash_functions

# Initialize starship prompt if available
if command -v starship &> /dev/null; then
    eval "$(starship init bash)"
fi

# Initialize fzf if available
if command -v fzf &> /dev/null; then
    source <(fzf --bash)
fi

# Source fzf if available (alternate location)
[[ ! -f ~/.fzf.bash ]] || source ~/.fzf.bash

# Set up better history control
HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend
shopt -s checkwinsize

# Set up a nicer prompt if starship is not available
if ! command -v starship &> /dev/null; then
    PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
fi

# Enable bash completion
if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

# Source local environment
[[ ! -f "$HOME/.local/share/../bin/env" ]] || . "$HOME/.local/share/../bin/env"
