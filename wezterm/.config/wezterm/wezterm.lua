-- Pull in the wezterm API
local wezterm = require("wezterm")
local act = wezterm.action

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices.

-- For example, changing the initial geometry for new windows:
config.initial_cols = 120
config.initial_rows = 28

-- or, changing the font size and color scheme.
config.font_size = 10
config.color_scheme = "Catppuccin Mocha (Gogh)"
config.font = wezterm.font('Google Sans Code')

config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true

-- Make URLs clickable without needing Cmd
config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- Window appearance
config.window_background_opacity = 1.0
config.macos_window_background_blur = 5

-- SSH domains show up in the launcher and can be used by wezterm ssh.
-- These names should match hosts resolvable by ssh (eg: via ~/.ssh/config).
config.ssh_domains = {
	{ name = "ogre", remote_address = "ogre" },
	{ name = "margaret", remote_address = "margaret" },
}

-- Keybindings
config.keys = {
	-- Make Ctrl+h work with tmux navigator
	{
		key = "h",
		mods = "CTRL",
		action = wezterm.action.SendString("\x1b[104;5u"),
	},
	-- Quick workspaces (creates the workspace if it doesn't exist)
	{
		key = "W",
		mods = "CMD|SHIFT",
		action = act.PromptInputLine({
			description = "Switch/Create workspace",
			action = wezterm.action_callback(function(window, pane, line)
				if line and line ~= "" then
					window:perform_action(act.SwitchToWorkspace({ name = line }), pane)
				end
			end),
		}),
	},
	-- Launcher (fuzzy): switch workspaces, open ssh domains, and more.
	{
		key = "L",
		mods = "CMD|SHIFT",
		action = act.ShowLauncherArgs({
			flags = "FUZZY|WORKSPACES|DOMAINS|LAUNCH_MENU_ITEMS|KEY_ASSIGNMENTS",
		}),
	},
	-- Make Cmd+T "smart": open the launcher instead of always creating a new tab.
	{
		key = "t",
		mods = "CMD",
		action = act.ShowLauncherArgs({
			flags = "FUZZY|WORKSPACES|DOMAINS|LAUNCH_MENU_ITEMS|KEY_ASSIGNMENTS",
		}),
	},
	-- SSH + auto tmux attach/create in a new tab
	{
		key = "O",
		mods = "CMD|SHIFT",
		action = act.SpawnCommandInNewTab({
			args = { "ssh", "-t", "ogre", "tmux new -A -s main" },
		}),
	},
	{
		key = "M",
		mods = "CMD|SHIFT",
		action = act.SpawnCommandInNewTab({
			args = { "ssh", "-t", "margaret", "tmux new -A -s main" },
		}),
	},
}

-- Finally, return the configuration to wezterm:
return config
