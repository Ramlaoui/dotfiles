#!/bin/bash

set -u

# NetworkManager's terse output escapes ':' and '\'.  Splitting on ':' with
# IFS loses literal SSIDs, so parse the escaped fields before displaying them.
split_nmcli_fields() {
    local line="$1" field="" escaped=0 ch i
    NMCLI_FIELDS=()
    for ((i = 0; i < ${#line}; i++)); do
        ch="${line:i:1}"
        if ((escaped)); then
            field+="$ch"
            escaped=0
        elif [[ "$ch" == '\' ]]; then
            escaped=1
        elif [[ "$ch" == ':' ]]; then
            NMCLI_FIELDS+=("$field")
            field=""
        else
            field+="$ch"
        fi
    done
    ((escaped)) && field+='\'
    NMCLI_FIELDS+=("$field")
}

show_error() {
    rofi -e "$1" >&2 || printf '%s\n' "$1" >&2
}

if ! command -v nmcli >/dev/null 2>&1; then
    show_error "NetworkManager (nmcli) is required."
    exit 1
fi

if ! wifi_data=$(nmcli --terse --fields SSID,SECURITY,SIGNAL device wifi list 2>/dev/null); then
    show_error "Unable to list WiFi networks."
    exit 1
fi

options=("🔄 Refresh" "📶 Current connections")
declare -a network_ssid=()
declare -a network_security=()
declare -a network_signal=()
network_id=0
while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    split_nmcli_fields "$line"
    [[ ${#NMCLI_FIELDS[@]} -ge 3 ]] || continue
    ssid="${NMCLI_FIELDS[0]}"
    security="${NMCLI_FIELDS[1]}"
    signal="${NMCLI_FIELDS[2]}"
    [[ -n "$ssid" ]] || continue
    network_ssid[network_id]="$ssid"
    network_security[network_id]="$security"
    network_signal[network_id]="$signal"
    if [[ "$security" == "--" || -z "$security" ]]; then
        icon="🔓"
    else
        icon="🔒"
    fi
    display_ssid=${ssid//$'\n'/↵}
    options+=("$icon [$network_id] $display_ssid (${signal}%)")
    ((network_id += 1))
done <<< "$wifi_data"

chosen=$(printf '%s\n' "${options[@]}" | rofi -dmenu -i -p "WiFi Networks")

case "$chosen" in
    "🔄 Refresh")
        if ! nmcli device wifi rescan; then
            show_error "WiFi scan refresh failed."
            exit 1
        fi
        exec "$0"
        ;;
    "📶 Current connections")
        if ! nmcli connection show --active; then
            show_error "Unable to show active connections."
            exit 1
        fi
        ;;
    🔓*|🔒*)
        if [[ "$chosen" =~ ^(🔓|🔒)[[:space:]]\[([0-9]+)\][[:space:]] ]]; then
            id="${BASH_REMATCH[2]}"
        else
            show_error "The selected network identity is invalid."
            exit 1
        fi
        if [[ -z "${network_ssid[$id]+set}" ]]; then
            show_error "The selected network is no longer available."
            exit 1
        fi
        ssid="${network_ssid[$id]}"
        security="${network_security[$id]}"
        if [[ "$security" == "--" || -z "$security" ]]; then
            if ! nmcli device wifi connect "$ssid"; then
                show_error "Unable to connect to the selected open network."
                exit 1
            fi
        else
            password=$(rofi -dmenu -password -p "Password for $ssid")
            if [[ -z "$password" ]]; then
                exit 0
            fi
            # --ask reads the secret from stdin; it never appears in nmcli's
            # process arguments or shell history.
            if ! printf '%s\n' "$password" | nmcli --ask device wifi connect "$ssid"; then
                show_error "Unable to connect to the selected secured network."
                exit 1
            fi
        fi
        ;;
esac