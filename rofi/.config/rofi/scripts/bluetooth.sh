#!/bin/bash

set -u

show_error() {
    rofi -e "$1" >&2 || printf '%s\n' "$1" >&2
}

if ! command -v bluetoothctl >/dev/null 2>&1; then
    show_error "bluetoothctl is required."
    exit 1
fi

if command -v systemctl >/dev/null 2>&1 &&
    ! systemctl is-active --quiet bluetooth; then
    start_service=$(printf '%s\n' "Yes" "No" | rofi -dmenu -p "Bluetooth service not running. Start it?")
    if [[ "$start_service" == "Yes" ]]; then
        if ! systemctl start bluetooth; then
            show_error "Unable to start the Bluetooth service."
            exit 1
        fi
    else
        exit 0
    fi
fi

get_bluetooth_status() {
    if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then
        echo "on"
    else
        echo "off"
    fi
}

declare -a device_mac=()
declare -a device_kind=()
declare -a device_options=()
device_id=0

add_device() {
    local kind="$1" mac="$2" name="$3" icon="$4"
    [[ "$mac" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] || return 0
    device_mac[device_id]="$mac"
    device_kind[device_id]="$kind"
    device_options+=("$icon [$device_id] [$mac]")
    ((device_id += 1))
}

get_devices() {
    local filter="$1" kind="$2" icon="$3" line _ mac name
    while IFS= read -r line; do
        read -r _ mac name <<< "$line"
        [[ -n "${mac:-}" ]] || continue
        add_device "$kind" "$mac" "${name:-Unknown device}" "$icon"
    done < <(bluetoothctl devices "$filter" 2>/dev/null)
}

scan_devices() {
    local scan_pid
    bluetoothctl --timeout=10 scan on >/dev/null 2>&1 &
    scan_pid=$!
    # Give discovery a bounded window, then stop and reap exactly this scanner.
    sleep 2
    if kill -0 "$scan_pid" 2>/dev/null; then
        kill "$scan_pid" 2>/dev/null || true
        wait "$scan_pid" 2>/dev/null || true
    fi
    bluetoothctl scan off >/dev/null 2>&1 || true

    local line _ mac name
    while IFS= read -r line; do
        read -r _ mac name <<< "$line"
        [[ -n "${mac:-}" ]] || continue
        if ! bluetoothctl devices Paired 2>/dev/null | awk '{print $2}' | grep -Fxq "$mac"; then
            add_device scan "$mac" "${name:-Unknown device}" "🔍"
        fi
    done < <(bluetoothctl devices 2>/dev/null)
}

bt_status=$(get_bluetooth_status)

if [[ "$bt_status" == "off" ]]; then
    options=("🔴 Bluetooth: OFF" "🔄 Turn On Bluetooth")
else
    device_options=()
    get_devices Connected connected "🔗"
    get_devices Paired paired "📱"
    options+=("${device_options[@]}")
fi

chosen=$(printf '%s\n' "${options[@]}" | rofi -dmenu -i -p "Bluetooth Manager")

case "$chosen" in
    "🔄 Turn On Bluetooth")
        if bluetoothctl power on; then
            rofi -e "Bluetooth enabled."
        else
            show_error "Unable to enable Bluetooth."
            exit 1
        fi
        ;;
    "⏹️  Turn Off Bluetooth")
        if bluetoothctl power off; then
            rofi -e "Bluetooth disabled."
        else
            show_error "Unable to disable Bluetooth."
            exit 1
        fi
        ;;
    "🔍 Scan for Devices")
        device_mac=()
        device_kind=()
        device_options=()
        device_id=0
        scan_devices
        new_devices=("${device_options[@]}")
        if ((${#new_devices[@]} == 0)); then
            show_error "No new devices found."
            exit 0
        fi
        selected=$(printf '%s\n' "${new_devices[@]}" | rofi -dmenu -i -p "New Devices Found")
        if [[ "$selected" =~ ^🔍[[:space:]]\[([0-9]+)\][[:space:]]\[([[:xdigit:]:]+)\]$ ]]; then
            id="${BASH_REMATCH[1]}"
            mac="${device_mac[$id]:-}"
            [[ "$mac" == "${BASH_REMATCH[2]}" ]] || {
                show_error "The selected Bluetooth device changed; nothing was paired."
                exit 1
            }
            action=$(printf '%s\n' "Pair" "Connect" "Cancel" | rofi -dmenu -p "Action for device")
            case "$action" in
                Pair)
                    if bluetoothctl pair "$mac"; then rofi -e "Device paired successfully."; else show_error "Pairing failed."; exit 1; fi
                    ;;
                Connect)
                    if bluetoothctl connect "$mac"; then rofi -e "Device connected successfully."; else show_error "Connection failed."; exit 1; fi
                    ;;
            esac
        fi
        ;;
    "🔄 Refresh")
        exec "$0"
        ;;
    *)
        if [[ "$chosen" =~ \[([0-9]+)\][[:space:]]\[(([[:xdigit:]]{2}:){5}[[:xdigit:]]{2})\]$ ]]; then
            id="${BASH_REMATCH[1]}"
            mac="${device_mac[$id]:-}"
            [[ "$mac" == "${BASH_REMATCH[2]}" ]] || {
                show_error "The selected Bluetooth device changed; nothing was done."
                exit 1
            }
            case "${device_kind[$id]:-}" in
                connected)
                    if bluetoothctl disconnect "$mac"; then rofi -e "Device disconnected."; else show_error "Disconnect failed."; exit 1; fi
                    ;;
                paired)
                    if bluetoothctl connect "$mac"; then rofi -e "Device connected."; else show_error "Connection failed."; exit 1; fi
                    ;;
            esac
        fi
        ;;
esac