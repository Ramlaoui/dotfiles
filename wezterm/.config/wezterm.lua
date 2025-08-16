-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices.

-- For example, changing the initial geometry for new windows:
config.initial_cols = 120
config.initial_rows = 28

-- or, changing the font size and color scheme.
config.font_size = 10
config.color_scheme = "Catppuccin Mocha"

config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true

-- Make URLs clickable without needing Cmd
config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- Keybindings
config.keys = {
    -- Make Ctrl+h work with tmux navigator
    {
        key = 'h',
        mods = 'CTRL',
        action = wezterm.action.SendString('\x1b[104;5u')
    },
}

-- Finally, return the configuration to wezterm:
return config
