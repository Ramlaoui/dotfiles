#!/bin/bash

# Combined rofi menu - choose which mode to use

options="🚀 Applications (drun)\n🪟 Windows\n⚡ Run Command\n📁 Files\n💻 SSH\n🔌 Power Menu\n📶 WiFi\n📋 Clipboard\n🧮 Calculator\n😀 Emoji Picker\n📊 System Monitor\n🔵 Bluetooth\n⚙️  Settings"

chosen=$(echo -e "$options" | rofi -dmenu -i -p "Rofi Menu" -theme-str 'window { width: 400px; }')

case $chosen in
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
        ~/.config/rofi/scripts/power-menu.sh
        ;;
    "📶 WiFi")
        ~/.config/rofi/scripts/wifi-menu.sh
        ;;
    "📋 Clipboard")
        ~/.config/rofi/scripts/clipboard.sh
        ;;
    "🧮 Calculator")
        ~/.config/rofi/scripts/calculator.sh
        ;;
    "😀 Emoji Picker")
        ~/.config/rofi/scripts/emoji.sh
        ;;
    "📊 System Monitor")
        ~/.config/rofi/scripts/system-monitor.sh
        ;;
    "🔵 Bluetooth")
        ~/.config/rofi/scripts/bluetooth.sh
        ;;
    "⚙️  Settings")
        # Open system settings
        if command -v gnome-control-center &> /dev/null; then
            gnome-control-center
        elif command -v systemsettings5 &> /dev/null; then
            systemsettings5
        elif command -v unity-control-center &> /dev/null; then
            unity-control-center
        else
            rofi -e "No settings application found"
        fi
        ;;
esac