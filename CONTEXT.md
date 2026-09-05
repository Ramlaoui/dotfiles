# Dotfiles

This context describes the ownership language for personal configuration managed in this repository.

## Language

**Dotfiles-owned Neovim config**:
The Neovim behavior controlled by this repository: plugin specs, keymaps, options, snippets, and integration adapters. Omarchy should not be the canonical owner of this behavior.
_Avoid_: Omarchy Neovim setup, live Neovim config

**Omarchy theme provider**:
The external Omarchy state that provides the currently selected visual theme for Neovim and other desktop tools. In Neovim, this should be consumed through a dotfiles-owned adapter.
_Avoid_: Omarchy-owned Neovim config

**Tmux scroll mode**:
A dotfiles-owned history-browsing workflow for quickly moving through pane output. It is a navigation workflow, not the selection workflow for copying or opening text.
_Avoid_: native tmux mode, copy selection mode

**Tmux copy mode**:
Tmux's selection-capable history view for vi-style movement, selecting text, copying text, and invoking copy-mode actions.
_Avoid_: scroll mode, shell mode

## Example Dialogue

Dev: Should Omarchy update my Neovim plugins and keymaps?
Domain expert: No. Dotfiles own Neovim behavior; Omarchy only provides the current theme.

Dev: Where should Neovim read the Omarchy theme from?
Domain expert: Through a dotfiles-owned adapter that reads the current Omarchy theme when it exists.

Dev: Is tmux scroll mode a separate tmux mode?
Domain expert: No. It is a dotfiles-owned history-browsing workflow layered on top of tmux copy mode.
