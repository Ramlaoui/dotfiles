.DEFAULT_GOAL := help
.PHONY: install sync deps plugins all dry-run no-sudo auto-yes help test

install:
	./install.sh all

sync:
	./install.sh sync

dry-run:
	./install.sh sync --dry-run

deps:
	./install.sh deps

plugins:
	./install.sh plugins

all:
	./install.sh all

no-sudo:
	./install.sh deps --no-sudo

auto-yes:
	./install.sh deps --auto-yes

test:
	python3 -m unittest discover -s tests -v

help:
	@printf '%s\n' \
	  'Usage: make <target>' \
	  '  sync       Preflight and link default dotfiles with GNU Stow' \
	  '  dry-run    Show the sync plan without changing files' \
	  '  deps       Install default dependencies' \
	  '  plugins    Install TPM and missing tmux plugins' \
	  '  all        Install dependencies, sync, then install tmux plugins' \
	  '  no-sudo    Run deps without invoking sudo' \
	  '  auto-yes   Run deps without prompting' \
	  '  test       Run the Python unittest suite' \
	  '  help       Show this help'
