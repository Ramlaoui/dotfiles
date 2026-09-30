#!/usr/bin/env bash
# Install missing tmux plugins without loading a user's running tmux server.

set -o pipefail
export PATH="$HOME/.local/bin:$PATH"

TPM_REVISION=e261deb1b47614eed3400089ce7197dc68acc4eb
CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}"
PLUGIN_ROOT="$CONFIG_ROOT/tmux/plugins"
TPM_DIR="$PLUGIN_ROOT/tpm"
WORK_DIR=''
SOCKET=''

fail() { printf '%s\n' "[ERROR] $1" >&2; exit 1; }
cleanup() {
    status=$?
    if [ -n "$SOCKET" ]; then
        tmux -S "$SOCKET" kill-server >/dev/null 2>&1 || true
    fi
    if [ -n "$WORK_DIR" ]; then
        rm -rf "$WORK_DIR"
    fi
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

for command in git tmux; do
    command -v "$command" >/dev/null 2>&1 || fail "$command is required for tmux plugin installation"
done
[ -r "$CONFIG_ROOT/tmux/tmux.conf" ] || fail 'Sync the tmux configuration before installing plugins: ./install.sh sync tmux'

if [ -e "$TPM_DIR" ] || [ -L "$TPM_DIR" ]; then
    [ -x "$TPM_DIR/tpm" ] && [ -x "$TPM_DIR/bin/install_plugins" ] ||
        fail "Existing TPM path is incomplete; it was preserved: $TPM_DIR"
fi

# Keep the socket path short enough for Unix socket limits on macOS as well.
WORK_DIR=$(mktemp -d /tmp/dotfiles-tpm.XXXXXXXX) || exit 1
SOCKET="$WORK_DIR/tmux.sock"
export GIT_TERMINAL_PROMPT=0
if [ ! -d "$TPM_DIR" ]; then
    printf '%s\n' '[INFO] Installing TPM from its pinned revision'
    git clone --quiet https://github.com/tmux-plugins/tpm.git "$WORK_DIR/tpm" || exit $?
    git -C "$WORK_DIR/tpm" checkout --quiet --detach "$TPM_REVISION" || exit $?
    [ "$(git -C "$WORK_DIR/tpm" rev-parse HEAD)" = "$TPM_REVISION" ] || fail 'TPM revision verification failed'
    mkdir -p "$PLUGIN_ROOT" || exit $?
    mv "$WORK_DIR/tpm" "$TPM_DIR" || exit $?
fi

# TPM reads plugin declarations from the synced configuration. Its CLI only
# installs missing checkouts; it does not update existing plugins or load them.
# A private server supplies TPM's environment without sourcing user config,
# triggering restore hooks, or touching any existing sessions.
tmux -S "$SOCKET" -f /dev/null new-session -d -s plugin-install 'exec sleep 3600' || exit $?
server_pid=$(tmux -S "$SOCKET" display-message -p '#{pid}') || exit $?
export TMUX="$SOCKET,$server_pid,0"
tmux -S "$SOCKET" set-environment -g TMUX_PLUGIN_MANAGER_PATH "$PLUGIN_ROOT/" || exit $?
printf '%s\n' '[INFO] Installing missing tmux plugins'
"$TPM_DIR/bin/install_plugins"
status=$?
[ "$status" -eq 0 ] || exit "$status"
printf '%s\n' '[OK] Tmux plugins installed; reload tmux configuration to activate them'
