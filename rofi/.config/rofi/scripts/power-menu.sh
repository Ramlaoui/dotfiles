#!/bin/bash

options="🔒 Lock\n🚪 Logout\n🔄 Restart\n⛔ Shutdown\n💤 Suspend\n🛌 Hibernate"

chosen=$(echo -e "$options" | rofi -dmenu -i -p "Power Menu")

case $chosen in
    "🔒 Lock")
        if command -v gnome-screensaver-command &> /dev/null; then
            gnome-screensaver-command -l
        elif command -v loginctl &> /dev/null; then
            loginctl lock-session
        else
            systemctl suspend
        fi
        ;;
    "🚪 Logout")
        if command -v gnome-session-quit &> /dev/null; then
            gnome-session-quit --logout --no-prompt
        elif command -v loginctl &> /dev/null; then
            loginctl terminate-session $(loginctl show-user $(whoami) -p Sessions --value | tr ' ' '\n' | head -1)
        else
            pkill -KILL -u $(whoami)
        fi
        ;;
    "🔄 Restart")
        systemctl reboot
        ;;
    "⛔ Shutdown")
        systemctl poweroff
        ;;
    "💤 Suspend")
        systemctl suspend
        ;;
    "🛌 Hibernate")
        systemctl hibernate
        ;;
esac