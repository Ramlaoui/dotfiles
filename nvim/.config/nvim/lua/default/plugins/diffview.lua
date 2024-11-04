return {
	"sindrets/diffview.nvim",
	config = function()
		local diffview = require("diffview")

		diffview.setup({
			diff_binaries = false,
		})

		-- Mappings
		local map = vim.api.nvim_set_keymap
		local opts = { noremap = true, silent = true }
		map("n", "<leader>gd", "<cmd>DiffviewOpen<cr>", opts)
		map("n", "<leader>gD", "<cmd>DiffviewClose<cr>", opts)
		map("n", "<leader>ge", "<cmd>DiffviewToggleFiles<cr>", opts)
	end,
}
