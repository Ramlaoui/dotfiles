return {
	"epwalsh/obsidian.nvim",
	lazy = true,
	event = {
		-- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
		-- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/**.md"
		"BufReadPre /Users/aliramlaoui/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault/**.md",
		"BufNewFile /Users/aliramlaoui/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault/**.md",
	},
	dependencies = {
		-- Required.
		"nvim-lua/plenary.nvim",

		-- see below for full list of optional dependencies 👇
	},
	opts = {
		workspaces = {
			{
				name = "personal",
				path = "/Users/aliramlaoui/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault",
			},
			{
				name = "work",
				path = "~/vaults/work",
			},
		},

		-- see below for full list of options 👇
	},
}
