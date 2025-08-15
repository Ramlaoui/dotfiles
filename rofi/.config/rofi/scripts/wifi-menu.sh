#!/bin/bash

# WiFi menu using rofi and nmcli

if ! command -v nmcli &> /dev/null; then
    rofi -e "NetworkManager (nmcli) is required"
    exit 1
fi

# Get available WiFi networks
wifi_list=$(nmcli -t -f active,ssid dev wifi | egrep '^yes' | cut -d':' -f2)
all_networks=$(nmcli -t -f ssid,security,signal dev wifi list | sort -t: -k3 -nr)

# Create menu options
options="🔄 Refresh\n📶 Current: $wifi_list\n"
while IFS=: read -r ssid security signal; do
    if [[ -n "$ssid" ]]; then
        if [[ "$security" == "--" ]]; then
            options+="🔓 $ssid ($signal%)\n"
        else
            options+="🔒 $ssid ($signal%)\n"
        fi
    fi
done <<< "$all_networks"

chosen=$(echo -e "$options" | rofi -dmenu -i -p "WiFi Networks")

case $chosen in
    "🔄 Refresh")
        nmcli dev wifi rescan
        exec "$0"
        ;;
    "📶 Current:"*)
        # Show current connection details
        nmcli connection show --active
        ;;
    🔓*)
        # Connect to open network
        ssid=$(echo "$chosen" | sed 's/🔓 \(.*\) ([0-9]*%)/\1/')
        nmcli dev wifi connect "$ssid"
        ;;
    🔒*)
        # Connect to secured network
        ssid=$(echo "$chosen" | sed 's/🔒 \(.*\) ([0-9]*%)/\1/')
        password=$(rofi -dmenu -password -p "Password for $ssid")
        if [[ -n "$password" ]]; then
            nmcli dev wifi connect "$ssid" password "$password"
        fi
        ;;
esac