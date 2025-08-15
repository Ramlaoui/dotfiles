#!/bin/bash

# System monitor using rofi
# Shows CPU, memory, disk usage and running processes

get_system_info() {
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
    memory_info=$(free -h | awk 'NR==2{printf "%.1f/%.1fG (%.0f%%)", $3,$2,$3*100/$2}')
    disk_usage=$(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')
    uptime_info=$(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')
    load_avg=$(uptime | awk -F'load average:' '{print $2}')
}

show_processes() {
    ps aux --sort=-%cpu | head -20 | awk 'NR>1{printf "🔧 %s (%.1f%% CPU, %.1f%% MEM)\n", $11, $3, $4}'
}

action="$1"

case $action in
    "processes")
        processes=$(show_processes)
        chosen=$(echo -e "$processes" | rofi -dmenu -i -p "Top Processes" -format "s")
        if [[ -n "$chosen" ]]; then
            # Extract process name and show kill option
            process_name=$(echo "$chosen" | sed 's/🔧 \([^ ]*\).*/\1/')
            if [[ "$process_name" != "rofi" && "$process_name" != "bash" ]]; then
                confirm=$(echo -e "Yes\nNo" | rofi -dmenu -p "Kill $process_name?")
                if [[ "$confirm" == "Yes" ]]; then
                    pkill "$process_name" && rofi -e "Process $process_name killed"
                fi
            fi
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

        chosen=$(echo -e "$options" | rofi -dmenu -i -p "System Monitor")
        
        case $chosen in
            "🔧 Show Processes")
                "$0" processes
                ;;
            "🔄 Refresh")
                exec "$0"
                ;;
            "📱 System Info")
                info="$(uname -a)\n$(lsb_release -a 2>/dev/null)"
                rofi -e "$info"
                ;;
        esac
        ;;
esac