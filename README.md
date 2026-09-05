# Dotfiles

Configuration packages managed with GNU Stow. Linking, dependency installation,
and runtime activation are separate operations.

## Install

```bash
git clone https://github.com/Ramlaoui/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh deps --auto-yes
./install.sh sync --dry-run
./install.sh sync
```

`./install.sh` defaults to **sync only** and requires GNU Stow already in `PATH`.
`./install.sh all` installs dependencies before linking the default packages.
`make` shows help; `make sync`, `make deps`, and `make install` select these phases.

Select packages or tools explicitly:

```bash
./install.sh sync bash zsh tmux nvim git
./install.sh deps git git-lfs jq stow
./install.sh deps --no-sudo stow
./install.sh sync --with-omarchy
```

All selected destinations are checked before linking. Existing conflicting files
are not adopted, overwritten, or deleted; a conflict or command failure exits
nonzero. Move conflicting configuration aside deliberately, then retry. A dry-run
creates no target directories. A failure during actual linking can leave earlier
successful operations linked; correct the cause and rerun.

Root files target `$HOME`; configuration subtrees target
`${XDG_CONFIG_HOME:-$HOME/.config}`. macOS VS Code targets
`~/Library/Application Support/Code`. Linux desktop packages are platform-gated.
Codex, Zen, Doom, and WezTerm are optional and never selected by default. Selecting
Bash or Zsh also links the shared `shell` package. Use `./install.sh --help` for
package names and platform options.

Sync does not delete plugin directories, source a running tmux session, change
your login shell, install plugins, or apply desktop defaults. Restart applications
or reload their configuration deliberately after reviewing the links. Shell
plugins must be installed separately; shell startup never downloads them.

## Dependencies

`scripts/installs/core-dependency.sh --help` lists canonical tool names. Native
package adapters translate them into platform package names and preserve argument
boundaries and failure statuses. Git LFS is included because the Git configuration
uses its filters. `uv` and `blesh` are optional.

`--no-sudo` never invokes sudo. Missing tools without a supported local recipe fail
explicitly rather than attempting a privileged installation. Stow and tmux delegate
to the standalone source installers below; other local recipes use pinned
revisions. Build failures propagate. Not every core dependency has a local recipe.
Bootstrap scripts are not fetched and piped into a shell.

### Latest Stow and tmux from source (no sudo)

```bash
# Independent installs into ~/.local, even if older system versions exist.
bash scripts/misc/install_stow.sh --jobs 4
bash scripts/misc/install_tmux.sh --jobs 4
export PATH="$HOME/.local/bin:$PATH"
stow --version
tmux -V

# Choose a prefix or request an explicit application version:
bash scripts/misc/install_stow.sh --prefix "$HOME/local" --version 2.4.1
bash scripts/misc/install_tmux.sh --prefix "$HOME/local" --jobs 4 --version 3.7c
```

Each installer defaults to the latest stable application release: GNU's release
listing for Stow, GitHub's latest stable release for tmux. `--version` selects an
explicit release instead. Both use release archives, not Git checkouts.

tmux's supporting libraries and parser tools use tested versions with checked-in
SHA256 checksums; they do not independently chase latest releases. A checksum
mismatch stops the build before extraction.
These hashes pin the official dependency archives retrieved during development.
Application archives are downloaded over official HTTPS URLs without signature
verification; `--version` selects a release, not a cryptographic content pin.

Stow needs **make, Perl, tar/gzip, curl or wget**, and ordinary Unix shell
utilities. tmux additionally needs a **C compiler and its standard toolchain**
and **sha256sum or shasum** (standard on Linux/macOS respectively).
Linux needs a working compiler/libc development environment; macOS needs the
Command Line Tools. Those basic prerequisites cannot be bootstrapped from nothing.
No sudo, Git, autotools, pkg-config, Python, makeinfo, or preinstalled
libevent/ncurses development packages are required. Missing m4/Bison parser tools
are built locally when needed.

tmux is linked with locally built static libevent, ncurses, and utf8proc libraries,
so no `LD_LIBRARY_PATH` setup is needed. Each installer uses a private temporary
build directory and stages its files before copying into the chosen prefix.
The final copy is not an atomic transaction. Neither installer changes shell
configuration or restarts a running tmux. Network access is required.

The two entrypoints own their recipes. `scripts/installs/source-common.sh` only
shares common installation mechanics; there is no combined installer or recipe
registry.

The general `./install.sh deps --no-sudo stow tmux` path calls these same scripts
for missing tools. Use the standalone commands above to upgrade an already
installed version. Change PATH deliberately to select the new binaries.
Prefixes must be absolute paths without whitespace (an upstream build limitation).

## Configuration ownership

- `shell/.config/shell/`: shared environment, aliases, and safe archive/temporary
  directory helpers; Bash and Zsh startup files source these modules. Keep
  machine-specific shell additions in your local startup override.
- `git/.config/git/`: Git configuration, native global ignore, and credential
  adapter. macOS Keychain or available libsecret is preferred; otherwise credentials
  use memory-only caching. Existing plaintext credential files are **not deleted**:
  migrate their secrets and remove obsolete copies yourself.
- `python/.config/ruff/ruff.toml`: the single user-level Ruff configuration.
  Project-local Ruff configuration still takes precedence.
- `nvim/.config/nvim/`: tracked plugin lockfile, LuaSnip snippets, and the shared
  Omarchy theme adapter. Launching Neovim can bootstrap the pinned lazy.nvim
  revision and install missing plugins; sync itself does not run Neovim or install
  its plugins. Lazy also checks for plugin updates.
- `tmux/.config/tmux/scripts/`: installed sidebar/worktree and pane borrowing/return
  helpers (tmux and fzf required for interactive pane selection). Optional
  tmux-switcher configuration uses `TMUX_SWITCHER_PATH`, not a host-specific path.
- `zen/.config/zen/README.md`: manual, locked profile patching and backup restoration.

## Desktop safety

Clipboard history is disabled unless `ROFI_CLIPBOARD_HISTORY=1` is exported.
Enabled history uses private files, serialized atomic updates, and lossless
multiline records. Base64 encoding is **not encryption**; retained clipboard
content remains sensitive. Wayland uses `wl-clipboard`; X11 uses xclip or xsel.

Process actions target the selected PID and verify its start identity. Logout
addresses the current session only. Lock failure never falls back to suspend.
Wi-Fi passwords are supplied on standard input rather than command arguments.
Desktop utilities remain optional; install their platform dependencies explicitly.
macOS defaults are a separate opt-in script and retain quarantine and disk-image
verification protections. GNOME tiling tooling is installed manually, not at startup.

The tmux copy-mode opener is intentionally unchanged, including its existing
shell-interpolation risk. Do not use it with untrusted selections.

## Verification

```bash
make test
```

Tests use disposable homes and stub external desktop/package-manager actions.
Install Python 3, Bash, Zsh, GNU Stow, jq, Neovim, and Ruff to exercise the relevant
checks; unavailable optional tools can produce skips. CI covers Linux and macOS.
Tests do not install system packages, terminate your session, alter a browser
profile, or reconfigure your running tmux server.
