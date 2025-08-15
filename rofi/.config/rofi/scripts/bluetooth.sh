#!/bin/bash

# Bluetooth manager using rofi and bluetoothctl

if ! command -v bluetoothctl &> /dev/null; then
    rofi -e "bluetoothctl is required"
    exit 1
fi

# Check if bluetooth service is running
if ! systemctl is-active --quiet bluetooth; then
    start_service=$(echo -e "Yes\nNo" | rofi -dmenu -p "Bluetooth service not running. Start it?")
    if [[ "$start_service" == "Yes" ]]; then
        systemctl start bluetooth
    else
        exit 0
    fi
fi

get_bluetooth_status() {
    if bluetoothctl show | grep -q "Powered: yes"; then
        echo "on"
    else
        echo "off"
    fi
}

get_connected_devices() {
    bluetoothctl devices Connected | while read -r line; do
        mac=$(echo "$line" | awk '{print $2}')
        name=$(echo "$line" | awk '{for(i=3;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ $//')
        echo "🔗 $name [$mac]"
    done
}

get_paired_devices() {
    bluetoothctl devices Paired | while read -r line; do
        mac=$(echo "$line" | awk '{print $2}')
        name=$(echo "$line" | awk '{for(i=3;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ $//')
        if ! bluetoothctl info "$mac" | grep -q "Connected: yes"; then
            echo "📱 $name [$mac]"
        fi
    done
}

scan_devices() {
    bluetoothctl --timeout=10 scan on >/dev/null 2>&1 &
    sleep 2
    bluetoothctl devices | while read -r line; do
        mac=$(echo "$line" | awk '{print $2}')
        name=$(echo "$line" | awk '{for(i=3;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ $//')
        if ! bluetoothctl devices Paired | grep -q "$mac"; then
            echo "🔍 $name [$mac]"
        fi
    done
}

bt_status=$(get_bluetooth_status)

if [[ "$bt_status" == "off" ]]; then
    options="🔴 Bluetooth: OFF\n🔄 Turn On Bluetooth"
else
    options="🟢 Bluetooth: ON\n⏹️  Turn Off Bluetooth\n🔍 Scan for Devices\n🔄 Refresh"
    
    connected=$(get_connected_devices)
    if [[ -n "$connected" ]]; then
        options+="\n--- Connected Devices ---\n$connected"
    fi
    
    paired=$(get_paired_devices)
    if [[ -n "$paired" ]]; then
        options+="\n--- Paired Devices ---\n$paired"
    fi
fi

chosen=$(echo -e "$options" | rofi -dmenu -i -p "Bluetooth Manager")

case $chosen in
    "🔄 Turn On Bluetooth")
        bluetoothctl power on
        rofi -e "Bluetooth enabled"
        ;;
    "⏹️  Turn Off Bluetooth")
        bluetoothctl power off
        rofi -e "Bluetooth disabled"
        ;;
    "🔍 Scan for Devices")
        rofi -e "Scanning for devices..."
        new_devices=$(scan_devices)
        if [[ -n "$new_devices" ]]; then
            selected=$(echo -e "$new_devices" | rofi -dmenu -i -p "New Devices Found")
            if [[ -n "$selected" ]]; then
                mac=$(echo "$selected" | grep -o '\[.*\]' | tr -d '[]')
                action=$(echo -e "Pair\nConnect\nCancel" | rofi -dmenu -p "Action for device")
                case $action in
                    "Pair")
                        bluetoothctl pair "$mac" && rofi -e "Device paired successfully"
                        ;;
                    "Connect")
                        bluetoothctl connect "$mac" && rofi -e "Device connected successfully"
                        ;;
                esac
            fi
        else
            rofi -e "No new devices found"
        fi
        ;;
    "🔄 Refresh")
        exec "$0"
        ;;
    🔗*)
        # Connected device - disconnect
        mac=$(echo "$chosen" | grep -o '\[.*\]' | tr -d '[]')
        bluetoothctl disconnect "$mac" && rofi -e "Device disconnected"
        ;;
    📱*)
        # Paired device - connect
        mac=$(echo "$chosen" | grep -o '\[.*\]' | tr -d '[]')
        bluetoothctl connect "$mac" && rofi -e "Device connected"
        ;;
esac