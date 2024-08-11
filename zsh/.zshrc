ZSH_DIR=$HOME/.config/zsh
ZDOTDIR=$HOME/.config/zsh

[[ $- != *i* ]] && return # if not interactive shell, return

# add in exports with XDG_HOME?
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# vi mode
bindkey -v

# Source 

# Source exports
[[ ! -f $ZSH_DIR/.exports ]] || source $ZSH_DIR/.exports

# Source aliases
[[ ! -f $ZSH_DIR/.aliases ]] || source $ZSH_DIR/.aliases

# Source functions
[[ ! -f $ZSH_DIR/.functions ]] || source $ZSH_DIR/.functions

# Source starship
eval "$(starship init zsh)"

# source Prezto
source "${ZDOTDIR}/.zprezto/init.zsh"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/opt/homebrew/Caskroom/miniconda/base/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/homebrew/Caskroom/miniconda/base/etc/profile.d/conda.sh" ]; then
        . "/opt/homebrew/Caskroom/miniconda/base/etc/profile.d/conda.sh"
    else
        export PATH="/opt/homebrew/Caskroom/miniconda/base/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/aliramlaoui/Downloads/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/aliramlaoui/Downloads/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/aliramlaoui/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/aliramlaoui/Downloads/google-cloud-sdk/completion.zsh.inc'; fi
