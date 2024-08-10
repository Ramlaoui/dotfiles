ZSH_DIR=$HOME/.config/zsh

[[ $- != *i* ]] && return # if not interactive shell, return

# Source 

# Source exports
[[ ! -f $ZSH_DIR/.exports ]] || source $ZSH_DIR/.exports

# Source aliases
[[ ! -f $ZSH_DIR/.aliases ]] || source $ZSH_DIR/.aliases

# Source functions
[[ ! -f $ZSH_DIR/.functions ]] || source $ZSH_DIR/.functions

# source Prezto
source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"

# export PATH=$HOME/bin:/usr/local/bin:$PATH

# # Path to your oh-my-zsh installation.
# export ZSH="$HOME/.oh-my-zsh"

# vi mode
bindkey -v

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
# plugins=(
# 	git
# 	zsh-autosuggestions
# 	zsh-syntax-highlighting
# 	vi-mode
# )

# source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# # To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
# [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

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

# Custom aliases
alias ls='ls -G'
alias ll='ls -lh'
alias la='ls -a'
alias mkdir='mkdir -p'
alias df='df -h'
alias admin="cd /Users/aliramlaoui/Google\ Drive/My\ Drive/Admin"
alias inkscape-watch="inkscape-figures watch"
alias code-ssh="code -nw --remote ssh-remote+ramlaoui"

# Custom functions

copy_pwd() {
    pwd | pbcopy
}

alias stage="cd /Users/aliramlaoui/Google\ Drive/My\ Drive/stage/"

export DRIVE="/Users/aliramlaoui/Google Drive/My Drive/"
export COURS="/Users/aliramlaoui/Google Drive/My Drive/Cours 3A"
cours() {
    cd /Users/aliramlaoui/Google\ Drive/My\ Drive/Cours\ 3A
}

fun() {
    cd /Users/aliramlaoui/Google\ Drive/My\ Drive/fun
}

ritz() {
    cd "$DRIVE"ritz
}

function latexnote() {
    if [[ $# -eq 0 ]]; then
        echo "Please provide a directory name as an argument."
        return 1
    fi

    local dest_dir="$1"
    local template_dir="/Users/aliramlaoui/Google Drive/My Drive/Cours 3A/latex/latex_template/"

    # Check if the destination directory exists, create it if it doesn't
    if [[ ! -d "$dest_dir" ]]; then
        mkdir -p "$dest_dir"
    fi

    # Copy the latex_template folder to the destination directory
    cp -r "$template_dir" "$dest_dir"

    echo "latex_template folder copied to $dest_dir successfully."
}

function latexbeamer() {
    if [[ $# -eq 0 ]]; then
        echo "Please provide a directory name as an argument."
        return 1
    fi

    local dest_dir="$1"
    local template_dir="/Users/aliramlaoui/Google Drive/My Drive/Cours 3A/latex/latex_beamer/"

    # Check if the destination directory exists, create it if it doesn't
    if [[ ! -d "$dest_dir" ]]; then
        mkdir -p "$dest_dir"
    fi

    # Copy the latex_template folder to the destination directory
    cp -r "$template_dir" "$dest_dir"

    echo "latex_template folder copied to $dest_dir successfully."
}

function latexcs() {
    if [[ $# -eq 0 ]]; then
        echo "Please provide a directory name as an argument."
        return 1
    fi

    local dest_dir="$1"
    local template_dir="/Users/aliramlaoui/Google Drive/My Drive/Cours 3A/latex/latex_cs/"

    # Check if the destination directory exists, create it if it doesn't
    if [[ ! -d "$dest_dir" ]]; then
        mkdir -p "$dest_dir"
    fi

    # Copy the latex_template folder to the destination directory
    cp -r "$template_dir" "$dest_dir"

    echo "latex_template folder copied to $dest_dir successfully."
}

editrc() {
    nvim ~/.zshrc
}

vault() {
    cd /Users/aliramlaoui/Library/Mobile\ Documents/iCloud~md~obsidian/Documents/Obsidian\ Vault
}

vaultcourse() {
    cd /Users/aliramlaoui/Library/Mobile\ Documents/iCloud~md~obsidian/Documents/Obsidian\ Vault/CSMVA
}

latexsnippets() {
    nvim ~/.config/nvim/my_snippets/tex.snippets
}

nvimconfig() {
    cd ~/.config/nvim
}

tmuxconfig() {
    nvim ~/.config/tmux/.tmux.conf
}

export EDITOR=nvim

