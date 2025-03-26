install:
	./install.sh

# Install with only stow, skipping dependencies
stow-only:
	./install.sh --stow-only

# Install without requiring sudo permissions
no-sudo:
	./install.sh --no-sudo

# Install with automatic yes to all prompts
auto-yes:
	./install.sh --auto-yes

# Install without changing the default shell
no-shell-change:
	./install.sh --skip-shell

# Install with verbose output
verbose:
	./install.sh --verbose

# Install with multiple options
stow-and-no-sudo:
	./install.sh --stow-only --no-sudo

help:
	@echo "Available targets:"
	@echo "  install         - Run the standard installation"
	@echo "  stow-only       - Only apply 'stow' to the folders, skip dependencies installation"
	@echo "  no-sudo         - Install packages from source without using sudo"
	@echo "  auto-yes        - Automatically agree to all prompts"
	@echo "  no-shell-change - Skip changing the default shell to zsh"
	@echo "  verbose         - Show verbose output"
	@echo "  stow-and-no-sudo - Apply stow only without sudo"
	@echo "  help            - Display this help message"

.PHONY: install stow-only no-sudo auto-yes no-shell-change verbose stow-and-no-sudo help
