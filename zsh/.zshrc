ZSH_DIR=$HOME/.config/zsh
ZDOTDIR=$HOME # The only way to change this from the default is to set it in the environment before starting zsh (.zshenv)...

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

