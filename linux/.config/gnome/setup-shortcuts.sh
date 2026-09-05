#!/bin/bash

# Configure rofi GNOME shortcuts

set -e
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# Function to switch to existing terminal window or launch new one
switch_to_terminal() {
    if wmctrl -x -a "gnome-terminal-server.Gnome-terminal" 2>/dev/null; then
        # Successfully focused existing terminal
        exit 0
    elif pgrep -f "gnome-terminal" > /dev/null; then
        # Terminal process exists but wmctrl failed, try alternative
        wmctrl -a "$(wmctrl -l | grep -E "(Terminal|$USER)" | head -1 | cut -d' ' -f5-)"
    else
        # No terminal running, launch new one
        gnome-terminal &
    fi
}

# Function to switch to existing app window or launch if not running
switch_to_app() {
    local command="$1"
    local window_class="$2"

    if [[ -z "$command" || -z "$window_class" ]]; then
        echo "Usage: switch_to_app <command> <window_class>"
        exit 1
    fi
    if [[ "$command" == *[!a-zA-Z0-9_./-]* ]]; then
        echo "Refusing an unsafe application command: $command" >&2
        exit 1
    fi

    # Check if window exists and focus it.
    if wmctrl -l | grep -i -F -- "$window_class" > /dev/null; then
        wmctrl -a "$window_class"
    else
        "$command" &
    fi
}

# Handle function calls when script is called with arguments
if [[ "$1" == "switch_to_terminal" ]]; then
    switch_to_terminal
    exit 0
elif [[ "$1" == "switch_to_app" ]]; then
    shift
    switch_to_app "$@"
    exit 0
fi

echo "🔧 Configuring custom GNOME Shortcuts..."

# Define shortcuts
declare -A shortcuts=(
    ["rofi-launcher"]="<Shift><Control><Alt><Super>a|Rofi App Launcher|rofi -show drun"
    ["rofi-window"]="<Shift><Control><Alt><Super>w|Rofi Window Switcher|rofi -show window"
    ["rofi-combined"]="<Shift><Control><Alt><Super>g|Rofi Combined Menu|$CONFIG_HOME/rofi/scripts/combined-menu.sh"
    ["terminal"]="<Shift><Control><Alt><Super>t|Switch to Terminal|$CONFIG_HOME/gnome/setup-shortcuts.sh switch_to_terminal"
    ["browser"]="<Shift><Control><Alt><Super>b|Switch to Browser|$CONFIG_HOME/gnome/setup-shortcuts.sh switch_to_app google-chrome Chrome"
    ["slack"]="<Shift><Control><Alt><Super>s|Switch to Slack|$CONFIG_HOME/gnome/setup-shortcuts.sh switch_to_app slack Slack"
    ["spotify"]="<Shift><Control><Alt><Super>p|Switch to Spotify|$CONFIG_HOME/gnome/setup-shortcuts.sh switch_to_app spotify Spotify"
    ["code"]="<Shift><Control><Alt><Super>k|Switch to Code|$CONFIG_HOME/gnome/setup-shortcuts.sh switch_to_app code Code"
    ["files"]="<Shift><Control><Alt><Super>f|Switch to Files|$CONFIG_HOME/gnome/setup-shortcuts.sh switch_to_app nautilus Files"
)

# Get current custom keybindings.  gsettings returns either [] or "@as []"
# for an empty array; do not synthesize a malformed value with sed.
if ! current_bindings=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings); then
    echo "Unable to read existing GNOME custom keybindings." >&2
    exit 1
fi
case "$current_bindings" in
    "[]"|"@as []")
        new_bindings="[]"
        ;;
    \[*\]|@as\ \[*\])
        new_bindings="${current_bindings#@as }"
        ;;
    *)
        echo "Unsupported custom-keybindings value: $current_bindings" >&2
        exit 1
        ;;
esac

append_binding() {
    local path="$1" inner
    [[ "$new_bindings" == *"'$path'"* ]] && return 0
    if [[ "$new_bindings" == "[]" ]]; then
        new_bindings="['$path']"
        return 0
    fi
    [[ "$new_bindings" == \[*\] ]] || return 1
    inner="${new_bindings:1:${#new_bindings}-2}"
    new_bindings="[$inner, '$path']"
}

# Setup each shortcut
for id in "${!shortcuts[@]}"; do
    IFS='|' read -r binding name command <<< "${shortcuts[$id]}"
    path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/$id/"

    echo "Setting up: $name ($binding)"

    # Set only this shortcut's properties; unrelated GNOME settings remain
    # untouched.
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$path" name "$name"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$path" command "$command"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$path" binding "$binding"
    append_binding "$path" || {
        echo "Unable to append custom keybinding $path." >&2
        exit 1
    }
done

if [[ "$new_bindings" != "${current_bindings#@as }" ]]; then
    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$new_bindings"
fi

echo "✅ All shortcuts configured successfully!"
echo
echo "Your shortcuts:"
echo "• Shift+Ctrl+Alt+Super+A - App Launcher"
echo "• Shift+Ctrl+Alt+Super+W - Window Switcher"  
echo "• Shift+Ctrl+Alt+Super+G - Combined Menu"
echo "• Shift+Ctrl+Alt+Super+T - Terminal"
echo "• Shift+Ctrl+Alt+Super+B - Browser (Chrome)"
echo "• Shift+Ctrl+Alt+Super+S - Slack"
echo "• Shift+Ctrl+Alt+Super+P - Spotify"
echo "• Shift+Ctrl+Alt+Super+K - Code"
echo "• Shift+Ctrl+Alt+Super+F - Files"