#!/bin/bash

set -u

show_error() {
    rofi -e "$1" >&2 || printf '%s\n' "$1" >&2
}

run_system_action() {
    local action="$1" label="$2"
    if ! command -v systemctl >/dev/null 2>&1; then
        show_error "$label is unavailable: systemctl was not found."
        return 1
    fi
    if ! systemctl "$action"; then
        show_error "$label failed."
        return 1
    fi
}

current_session_id() {
    [[ -n "${XDG_SESSION_ID:-}" ]] || return 1
    printf '%s\n' "$XDG_SESSION_ID"
}

lock_screen() {
    local desktop_hint session_type session_id
    desktop_hint="${XDG_CURRENT_DESKTOP:-}:${XDG_SESSION_DESKTOP:-}:${DESKTOP_SESSION:-}"
    desktop_hint="${desktop_hint,,}"
    session_type="${XDG_SESSION_TYPE:-}"

    # Pick an adapter for the active desktop, not merely the first installed
    # helper.  Omarchy's lock command is the native Hyprland adapter there.
    if [[ "$desktop_hint" == *hyprland* || -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        if command -v omarchy >/dev/null 2>&1; then
            if ! omarchy system lock; then
                show_error "Omarchy lock failed."
                return 1
            fi
            return 0
        fi
        if command -v hyprlock >/dev/null 2>&1; then
            if ! hyprlock; then
                show_error "Hyprlock failed."
                return 1
            fi
            return 0
        fi
        if command -v swaylock >/dev/null 2>&1; then
            if ! swaylock; then
                show_error "Swaylock failed."
                return 1
            fi
            return 0
        fi
        show_error "Lock is unavailable: install hyprlock or swaylock for Hyprland."
        return 1
    fi

    if [[ "$desktop_hint" == *sway* ]]; then
        if command -v swaylock >/dev/null 2>&1; then
            if ! swaylock; then
                show_error "Swaylock failed."
                return 1
            fi
            return 0
        fi
        show_error "Lock is unavailable: swaylock was not found."
        return 1
    fi

    if [[ "$desktop_hint" == *gnome* ]] &&
        command -v gnome-screensaver-command >/dev/null 2>&1; then
        if gnome-screensaver-command -l; then
            return 0
        fi
        show_error "GNOME screen lock failed."
        return 1
    fi

    if [[ "$desktop_hint" == *kde* || "$desktop_hint" == *plasma* ]]; then
        if command -v qdbus6 >/dev/null 2>&1; then
            if qdbus6 org.freedesktop.ScreenSaver /ScreenSaver Lock; then
                return 0
            fi
        elif command -v qdbus >/dev/null 2>&1 &&
            qdbus org.freedesktop.ScreenSaver /ScreenSaver Lock; then
            return 0
        fi
        show_error "KDE screen lock failed or is unavailable."
        return 1
    fi

    if [[ "$session_type" == "x11" ]] &&
        command -v xdg-screensaver >/dev/null 2>&1; then
        if xdg-screensaver lock; then
            return 0
        fi
        show_error "X11 screen lock failed."
        return 1
    fi

    session_id=$(current_session_id) || {
        show_error "Lock is unavailable: no current desktop session was identified."
        return 1
    }
    if ! command -v loginctl >/dev/null 2>&1; then
        show_error "Lock is unavailable: no supported desktop locker was found."
        return 1
    fi
    if [[ "$(loginctl show-session "$session_id" -p CanLock --value 2>/dev/null)" != "yes" ]]; then
        show_error "Lock is unavailable for session $session_id."
        return 1
    fi
    if ! loginctl lock-session "$session_id"; then
        show_error "Locking session $session_id failed."
        return 1
    fi
}

logout_session() {
    if command -v gnome-session-quit >/dev/null 2>&1 &&
        gnome-session-quit --logout --no-prompt; then
        return 0
    fi

    local session_id
    session_id=$(current_session_id) || {
        show_error "Logout is unavailable: no current session was identified."
        return 1
    }
    if ! command -v loginctl >/dev/null 2>&1; then
        show_error "Logout is unavailable: no supported session adapter was found."
        return 1
    fi
    if ! loginctl terminate-session "$session_id"; then
        show_error "Logout of session $session_id failed."
        return 1
    fi
}

options="🔒 Lock
🚪 Logout
🔄 Restart
⛔ Shutdown
💤 Suspend
🛌 Hibernate"

chosen=$(printf '%s\n' "$options" | rofi -dmenu -i -p "Power Menu")

case "$chosen" in
    "🔒 Lock")
        lock_screen
        ;;
    "🚪 Logout")
        logout_session
        ;;
    "🔄 Restart")
        run_system_action reboot "Restart"
        ;;
    "⛔ Shutdown")
        run_system_action poweroff "Shutdown"
        ;;
    "💤 Suspend")
        run_system_action suspend "Suspend"
        ;;
    "🛌 Hibernate")
        run_system_action hibernate "Hibernate"
        ;;
esac