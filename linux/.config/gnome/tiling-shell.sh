#!/bin/bash

set -u

extension="tilingshell@ferrarodomenico.com"
config_file="${XDG_CONFIG_HOME:-$HOME/.config}/gnome/tilingshell.conf"

if ! command -v gnome-extensions >/dev/null 2>&1; then
    printf 'gnome-extensions is required; install the %s extension manually.\n' \
        "$extension" >&2
    exit 1
fi
if ! gnome-extensions info "$extension" >/dev/null 2>&1; then
    printf 'The %s extension is not installed. Install it manually, then rerun this script.\n' \
        "$extension" >&2
    exit 1
fi
if ! command -v dconf >/dev/null 2>&1; then
    printf 'dconf is required to load %s.\n' "$config_file" >&2
    exit 1
fi
if [[ ! -r "$config_file" ]]; then
    printf 'Tiling Shell settings file not found: %s\n' "$config_file" >&2
    exit 1
fi

gnome-extensions enable "$extension"
dconf load /org/gnome/shell/extensions/tilingshell/ < "$config_file"