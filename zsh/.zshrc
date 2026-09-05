#!/usr/bin/env zsh

_shell_config=${XDG_CONFIG_HOME:-${HOME:-.}/.config}/shell
[[ -r "$_shell_config/env" ]] && source -- "$_shell_config/env"
_shell_config=${XDG_CONFIG_HOME:-${HOME:-.}/.config}/shell

# Local host settings are explicit and optional.
[[ -r "${HOME:-.}/.zshrc.local" ]] && source -- "${HOME:-.}/.zshrc.local"

[[ $- != *i* ]] && return

[[ -r "$_shell_config/aliases" ]] && source -- "$_shell_config/aliases"
alias sourcesh='source "${ZDOTDIR:-$HOME}/.zshrc"'
[[ -r "$_shell_config/functions" ]] && source -- "$_shell_config/functions"
_shell_zsh_config=${XDG_CONFIG_HOME:-${HOME:-.}/.config}/zsh
[[ -r "$_shell_zsh_config/.zsh_functions" ]] && source -- "$_shell_zsh_config/.zsh_functions"

# Prezto, Starship and fzf are optional integrations; startup never installs them.
if [[ -r "${ZDOTDIR:-${HOME:-.}}/.zprezto/init.zsh" ]]; then
    source -- "${ZDOTDIR:-${HOME:-.}}/.zprezto/init.zsh"
fi

bindkey -v
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi

function zle-line-init zle-keymap-select {
    RPS1="${${KEYMAP/vicmd/-- NORMAL --}/(main|viins)/-- INSERT --}"
    RPS2=$RPS1
    zle reset-prompt
}
zle -N zle-line-init
zle -N zle-keymap-select

if command -v fzf >/dev/null 2>&1; then
    source <(fzf --zsh)
fi
[[ ! -r "${HOME:-.}/.local/bin/env" ]] || source -- "${HOME:-.}/.local/bin/env"

unset _shell_config _shell_zsh_config
