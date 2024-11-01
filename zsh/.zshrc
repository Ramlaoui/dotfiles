ZSH_DIR=$HOME/.config/zsh
ZDOTDIR=$HOME # The only way to change this from the default is to set it in the environment before starting zsh (.zshenv)...

export TERM='xterm-256color'

[[ $- != *i* ]] && return # if not interactive shell, return

# Source 

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

# Source fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

export PATH=$XDG_DATA_HOME/node/bin:$PATH
export PATH="/home/ramlaouiali/usr/local/bin:$PATH"

source $HOME/.zshrc.local
