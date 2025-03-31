ZDOTDIR=$HOME # The only way to change this from the default is to set it in the environment before starting zsh (.zshenv)...
ZSH_DIR=$HOME/.config/zsh

export TERM='xterm-256color'

[[ $- != *i* ]] && return # if not interactive shell, return

# Source 
source $HOME/.zshrc.local

# Source exports
[[ ! -f $ZSH_DIR/.exports ]] || source $ZSH_DIR/.exports

# Source aliases
[[ ! -f $ZSH_DIR/.aliases ]] || source $ZSH_DIR/.aliases

# Source functions
[[ ! -f $ZSH_DIR/.functions ]] || source $ZSH_DIR/.functions

# source Prezto
source "${ZDOTDIR}/.zprezto/init.zsh"

# Source starship
eval "$(starship init zsh)"

# Problem with vi-mode and starship, this fixes it
function zle-line-init zle-keymap-select {
RPS1="${${KEYMAP/vicmd/-- NORMAL --}/(main|viins)/-- INSERT --}"
RPS2=$RPS1
zle reset-prompt
}
zle -N zle-line-init
zle -N zle-keymap-select

# Source fzf if command fzf succeeds
command -v fzf >/dev/null && source <(fzf --zsh)

export PATH=$XDG_DATA_HOME/node/bin:$PATH


. "$HOME/.local/share/../bin/env"

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/aliramlaoui/Downloads/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/aliramlaoui/Downloads/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/aliramlaoui/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/aliramlaoui/Downloads/google-cloud-sdk/completion.zsh.inc'; fi
