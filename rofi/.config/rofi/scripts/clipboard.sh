#!/bin/bash

set -u
set -o pipefail

# Retention is deliberately opt-in.  Opening this menu never records the
# current clipboard unless the user explicitly enables the variable.
RETENTION_ENABLED="${ROFI_CLIPBOARD_HISTORY:-0}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HISTORY_FILE="${ROFI_CLIPBOARD_HISTORY_FILE:-${XDG_CACHE_HOME:-$HOME/.cache}/rofi/clipboard-history.json}"
HISTORY_HELPER="$SCRIPT_DIR/clipboard-history.py"

show_error() {
    rofi -e "$1" >&2 || printf '%s\n' "$1" >&2
}

clipboard_reader() {
    if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-paste >/dev/null 2>&1; then
        wl-paste --no-newline
    elif command -v xclip >/dev/null 2>&1; then
        xclip -o -selection clipboard
    elif command -v xsel >/dev/null 2>&1; then
        xsel --clipboard --output
    else
        return 1
    fi
}

clipboard_writer() {
    if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy >/dev/null 2>&1; then
        wl-copy --type 'text/plain;charset=utf-8'
    elif command -v xclip >/dev/null 2>&1; then
        xclip -selection clipboard
    elif command -v xsel >/dev/null 2>&1; then
        xsel --clipboard --input
    else
        return 1
    fi
}

if [[ ! -x "$HISTORY_HELPER" ]]; then
    show_error "Clipboard history needs an executable Python 3 helper."
    exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
    show_error "python3 is required for private clipboard history."
    exit 1
fi
if [[ "$RETENTION_ENABLED" != "1" && ! -e "$HISTORY_FILE" ]]; then
    show_error "Clipboard history is empty (set ROFI_CLIPBOARD_HISTORY=1 to retain entries)."
    exit 0
fi

if [[ "$RETENTION_ENABLED" == "1" ]]; then
    if ! clipboard_reader | python3 "$HISTORY_HELPER" add "$HISTORY_FILE"; then
        show_error "Unable to read or retain the current clipboard."
        exit 1
    fi
fi

if ! history_output=$(python3 "$HISTORY_HELPER" list "$HISTORY_FILE"); then
    show_error "Unable to read clipboard history."
    exit 1
fi
history_entries=()
if [[ -n "$history_output" ]]; then
    mapfile -t history_entries <<< "$history_output"
fi

options=("🗑️  Clear History")
declare -A entry_tokens=()
for entry in "${history_entries[@]}"; do
    token="${entry%%$'\t'*}"
    display="${entry#*$'\t'}"
    [[ -n "$token" && "$entry" == *$'\t'* ]] || continue
    entry_tokens["$token"]=1
    options+=("📋 [$token] $display")
done

if ((${#options[@]} == 1)); then
    if [[ "$RETENTION_ENABLED" == "1" ]]; then
        show_error "No clipboard history found."
    else
        show_error "Clipboard history is empty (set ROFI_CLIPBOARD_HISTORY=1 to retain entries)."
    fi
    exit 0
fi

printf '%s\n' "${options[@]}" | rofi -dmenu -i -p "Clipboard History" -format s | {
    IFS= read -r chosen || exit 0
    if [[ "$chosen" == "🗑️  Clear History" ]]; then
        if python3 "$HISTORY_HELPER" clear "$HISTORY_FILE"; then
            rofi -e "Clipboard history cleared."
        else
            show_error "Unable to clear clipboard history."
            exit 1
        fi
        exit 0
    fi

    if [[ "$chosen" =~ ^📋[[:space:]]\[([0-9a-f]{64})\][[:space:]] ]]; then
        token="${BASH_REMATCH[1]}"
        [[ -n "${entry_tokens[$token]:-}" ]] || {
            show_error "The selected clipboard entry is no longer available."
            exit 1
        }
        if ! python3 "$HISTORY_HELPER" get "$HISTORY_FILE" "$token" | clipboard_writer; then
            show_error "The selected clipboard entry could not be copied."
            exit 1
        fi
    fi
}