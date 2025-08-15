#!/bin/bash

# Enhanced clipboard manager with persistent history
# Requires xclip

HISTORY_FILE="$HOME/.cache/rofi-clipboard-history"
MAX_HISTORY=50

if ! command -v xclip &> /dev/null; then
    rofi -e "xclip is required for this script"
    exit 1
fi

# Create cache directory if it doesn't exist
mkdir -p "$(dirname "$HISTORY_FILE")"

# Function to add to history
add_to_history() {
    local content="$1"
    if [[ -n "$content" && ${#content} -gt 1 ]]; then
        # Remove duplicates and add to top
        grep -Fxv "$content" "$HISTORY_FILE" 2>/dev/null > "${HISTORY_FILE}.tmp" || true
        echo "$content" > "$HISTORY_FILE"
        head -n $((MAX_HISTORY-1)) "${HISTORY_FILE}.tmp" 2>/dev/null >> "$HISTORY_FILE" || true
        rm -f "${HISTORY_FILE}.tmp"
    fi
}

# Monitor clipboard and add new content to history
current_clip=$(xclip -o -selection clipboard 2>/dev/null)
if [[ -n "$current_clip" ]]; then
    add_to_history "$current_clip"
fi

# Build options from history
options="🗑️  Clear History\n"
if [[ -f "$HISTORY_FILE" ]]; then
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Show first 60 chars, replace newlines with ↵
            display_line=$(echo "$line" | tr '\n' '↵' | cut -c1-60)
            if [[ ${#line} -gt 60 ]]; then
                display_line="${display_line}..."
            fi
            options+="📋 $display_line\n"
        fi
    done < "$HISTORY_FILE"
fi

if [[ $(echo -e "$options" | wc -l) -eq 1 ]]; then
    rofi -e "No clipboard history found"
    exit 0
fi

chosen=$(echo -e "$options" | rofi -dmenu -i -p "Clipboard History" -format "s")

if [[ "$chosen" == "🗑️  Clear History" ]]; then
    rm -f "$HISTORY_FILE"
    rofi -e "Clipboard history cleared"
elif [[ "$chosen" == 📋* ]]; then
    # Extract the original content from history file
    display_text="${chosen#📋 }"
    # Find matching line in history file
    while IFS= read -r line; do
        line_display=$(echo "$line" | tr '\n' '↵' | cut -c1-60)
        if [[ ${#line} -gt 60 ]]; then
            line_display="${line_display}..."
        fi
        if [[ "$line_display" == "${display_text}" ]]; then
            echo -n "$line" | xclip -selection clipboard
            echo -n "$line" | xclip -selection primary
            break
        fi
    done < "$HISTORY_FILE"
fi