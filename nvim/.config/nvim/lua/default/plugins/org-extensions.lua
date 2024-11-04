return {
	"akinsho/org-bullets.nvim",
	dependencies = {
		{ "nvim-treesitter/nvim-treesitter", opt = true },
	},
	event = "VeryLazy",
	ft = { "org" },
	config = function()
		-- Setup extensions
		require("org-bullets").setup()
	end,
}
