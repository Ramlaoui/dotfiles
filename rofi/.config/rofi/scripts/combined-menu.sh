#!/bin/bash

set -u
ROFI_SCRIPTS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/scripts"

# Combined rofi menu - choose which mode to use.

options="🚀 Applications (drun)\n🪟 Windows\n⚡ Run Command\n📁 Files\n💻 SSH\n🔌 Power Menu\n📶 WiFi\n📋 Clipboard\n🧮 Calculator\n😀 Emoji Picker\n📊 System Monitor\n🔵 Bluetooth\n⚙️  Settings"

chosen=$(printf '%b\n' "$options" | rofi -dmenu -i -p "Rofi Menu" -theme-str 'window { width: 400px; }')

case "$chosen" in
    "🚀 Applications (drun)")
        rofi -show drun
        ;;
    "🪟 Windows")
        rofi -show window
        ;;
    "⚡ Run Command")
        rofi -show run
        ;;
    "📁 Files")
        rofi -show filebrowser
        ;;
    "💻 SSH")
        rofi -show ssh
        ;;
    "🔌 Power Menu")
        "$ROFI_SCRIPTS_DIR/power-menu.sh"
        ;;
    "📶 WiFi")
        "$ROFI_SCRIPTS_DIR/wifi-menu.sh"
        ;;
    "📋 Clipboard")
        "$ROFI_SCRIPTS_DIR/clipboard.sh"
        ;;
    "🧮 Calculator")
        "$ROFI_SCRIPTS_DIR/calculator.sh"
        ;;
    "😀 Emoji Picker")
        "$ROFI_SCRIPTS_DIR/emoji.sh"
        ;;
    "📊 System Monitor")
        "$ROFI_SCRIPTS_DIR/system-monitor.sh"
        ;;
    "🔵 Bluetooth")
        "$ROFI_SCRIPTS_DIR/bluetooth.sh"
        ;;
    "⚙️  Settings")
        # Open system settings.
        if command -v gnome-control-center >/dev/null 2>&1; then
            gnome-control-center
        elif command -v systemsettings5 >/dev/null 2>&1; then
            systemsettings5
        elif command -v unity-control-center >/dev/null 2>&1; then
            unity-control-center
        else
            rofi -e "No settings application found."
        fi
        ;;
esac