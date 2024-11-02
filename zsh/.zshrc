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

# -- Use fd instead of fzf --

export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# Use fd (https://github.com/sharkdp/fd) for listing path candidates.
# - The first argument to the function ($1) is the base path to start traversal
# - See the source code (completion.{bash,zsh}) for the details.
_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}

show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"

export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

# Advanced customization of fzf options via _fzf_comprun function
# - The first argument to the function is the name of the command.
# - You should make sure to pass the rest of the arguments to fzf.
_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)           fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
    export|unset) fzf --preview "eval 'echo ${}'"         "$@" ;;
    ssh)          fzf --preview 'dig {}'                   "$@" ;;
    *)            fzf --preview "$show_file_or_dir_preview" "$@" ;;
  esac
}

source $HOME/.zshrc.local
