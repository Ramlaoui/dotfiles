#!/bin/bash

# Configure rofi GNOME shortcuts

set -e

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
# Usage: switch_to_app <command> <window_class>
switch_to_app() {
    local COMMAND="$1"
    local WINDOW_CLASS="$2"
    
    if [[ -z "$COMMAND" || -z "$WINDOW_CLASS" ]]; then
        echo "Usage: switch_to_app <command> <window_class>"
        exit 1
    fi
    
    # Check if window exists and focus it
    if wmctrl -l | grep -i "$WINDOW_CLASS" > /dev/null; then
        # Window exists, focus it
        wmctrl -a "$WINDOW_CLASS"
    else
        # Window doesn't exist, launch the application
        $COMMAND &
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
    ["rofi-combined"]="<Shift><Control><Alt><Super>g|Rofi Combined Menu|$HOME/.config/rofi/scripts/combined-menu.sh"
    ["terminal"]="<Shift><Control><Alt><Super>t|Switch to Terminal|$HOME/.config/gnome/setup-shortcuts.sh switch_to_terminal"
    ["browser"]="<Shift><Control><Alt><Super>b|Switch to Browser|$HOME/.config/gnome/setup-shortcuts.sh switch_to_app google-chrome Chrome"
    ["slack"]="<Shift><Control><Alt><Super>s|Switch to Slack|$HOME/.config/gnome/setup-shortcuts.sh switch_to_app slack Slack"
    ["spotify"]="<Shift><Control><Alt><Super>p|Switch to Spotify|$HOME/.config/gnome/setup-shortcuts.sh switch_to_app spotify Spotify"
    ["code"]="<Shift><Control><Alt><Super>k|Switch to Code|$HOME/.config/gnome/setup-shortcuts.sh switch_to_app code Code"
    ["files"]="<Shift><Control><Alt><Super>f|Switch to Files|$HOME/.config/gnome/setup-shortcuts.sh switch_to_app nautilus Files"
)

# Get current custom keybindings
current_bindings=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)

# Setup each shortcut
for id in "${!shortcuts[@]}"; do
    IFS='|' read -r binding name command <<< "${shortcuts[$id]}"
    path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/$id/"
    
    echo "Setting up: $name ($binding)"
    
    # Set the shortcut properties
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$path name "$name"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$path command "$command"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$path binding "$binding"
    
    # Add to custom-keybindings list if not already present
    if [[ ! "$current_bindings" =~ "$path" ]]; then
        new_bindings=$(echo "$current_bindings" | sed "s|\]|,'$path'\]|")
        gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$new_bindings"
        current_bindings="$new_bindings"
    fi
done

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