#!/bin/bash

# System monitor using rofi
# Shows CPU, memory, disk usage and running processes.
#
# Process rows include the kernel start-time counter as well as the PID.  The
# counter lets us refuse a kill if the PID was reused while the menu was open.

process_start_time() {
    local pid="$1" stat rest
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    [[ -r "/proc/$pid/stat" ]] || return 1
    stat=$(<"/proc/$pid/stat") || return 1
    # /proc/<pid>/stat field 2 is parenthesised and may contain spaces.  After
    # the final ") " the first token is field 3, so field 22 is token 20.
    rest=${stat##*) }
    set -- $rest
    [[ -n "${20:-}" ]] || return 1
    printf '%s\n' "${20}"
}

get_system_info() {
    cpu_usage=$(top -bn1 | awk '/Cpu\(s\)/ {gsub(/%/,"",$2); print $2; exit}')
    memory_info=$(free -h | awk 'NR==2{printf "%.1f/%.1fG (%.0f%%)", $3,$2,$3*100/$2}')
    disk_usage=$(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')
    uptime_info=$(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')
    load_avg=$(uptime | awk -F'load average:' '{print $2}')
}

show_processes() {
    local pid comm cpu mem start
    while read -r pid comm cpu mem; do
        [[ "$pid" =~ ^[0-9]+$ ]] || continue
        start=$(process_start_time "$pid") || continue
        printf '🔧 [%s:%s] %s (%s%% CPU, %s%% MEM)\n' \
            "$pid" "$start" "$comm" "$cpu" "$mem"
    done < <(ps -eo pid=,comm=,pcpu=,pmem= --sort=-pcpu | head -20)
}

kill_selected_process() {
    local selected="$1" pid expected_start current_start process_name confirm
    if [[ "$selected" =~ ^🔧[[:space:]]\[([0-9]+):([0-9]+)\][[:space:]] ]]; then
        pid="${BASH_REMATCH[1]}"
        expected_start="${BASH_REMATCH[2]}"
        process_name="${selected#*] }"
        process_name="${process_name%% (*}"
    else
        rofi -e "The selected process identity is invalid; nothing was stopped."
        return 1
    fi

    case "$process_name" in
        rofi*|bash*|system-monitor.sh*)
            rofi -e "Refusing to stop the menu process."
            return 1
            ;;
    esac

    confirm=$(printf '%s\n' "Yes" "No" | rofi -dmenu -p "Kill PID $pid ($process_name)?")
    [[ "$confirm" == "Yes" ]] || return 0

    current_start=$(process_start_time "$pid") || {
        rofi -e "PID $pid is no longer running."
        return 1
    }
    if [[ "$current_start" != "$expected_start" ]]; then
        rofi -e "PID $pid changed; refusing to stop a reused PID."
        return 1
    fi

    local kill_command
    kill_command=$(type -P kill 2>/dev/null || true)
    [[ -n "$kill_command" ]] || kill_command=kill
    if "$kill_command" -TERM -- "$pid"; then
        rofi -e "Process $process_name (PID $pid) asked to exit."
    else
        rofi -e "Unable to stop process $process_name (PID $pid)."
        return 1
    fi
}

action="$1"

case "$action" in
    processes)
        processes=$(show_processes)
        chosen=$(printf '%s\n' "$processes" | rofi -dmenu -i -p "Top Processes" -format s)
        if [[ -n "$chosen" ]]; then
            kill_selected_process "$chosen"
        fi
        ;;
    *)
        get_system_info

        options="📊 CPU Usage: ${cpu_usage}%
💾 Memory: $memory_info
💿 Disk: $disk_usage
⏱️  Uptime: $uptime_info
📈 Load Average:$load_avg
🔧 Show Processes
🔄 Refresh
📱 System Info"

        chosen=$(printf '%s\n' "$options" | rofi -dmenu -i -p "System Monitor")

        case "$chosen" in
            "🔧 Show Processes")
                "$0" processes
                ;;
            "🔄 Refresh")
                exec "$0"
                ;;
            "📱 System Info")
                info="$(uname -a)
$(lsb_release -a 2>/dev/null || true)"
                rofi -e "$info"
                ;;
        esac
        ;;
esac