return {
	"catppuccin/nvim",
	name = "catppuccin",
	priority = 1000,
	config = function()
		local catppuccin = require("catppuccin")

		vim.cmd.colorscheme("catppuccin-mocha")

		-- catppuccin.setup({
		-- 	transparency = false,
		-- 	styles = {
		-- 		comments = "italic",
		-- 		functions = "italic",
		-- 		keywords = "italic",
		-- 		strings = "italic",
		-- 		variables = "italic",
		-- 	},
		-- })
	end,
}
