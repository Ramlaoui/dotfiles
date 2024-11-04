return {
	"akinsho/bufferline.nvim",
	version = "*",
	dependencies = "nvim-tree/nvim-web-devicons",
	config = function()
		local bufferline = require("bufferline")

		bufferline.setup({
			options = {
				numbers = "ordinal",
				mappings = true,
			},
		})

		-- Mappings
		local map = vim.api.nvim_set_keymap
		local opts = { noremap = true, silent = true }

		map("n", "<leader>1", ":BufferLineGoToBuffer 1<CR>", opts)
		map("n", "<leader>2", ":BufferLineGoToBuffer 2<CR>", opts)
		map("n", "<leader>3", ":BufferLineGoToBuffer 3<CR>", opts)
		map("n", "<leader>4", ":BufferLineGoToBuffer 4<CR>", opts)
		map("n", "<leader>5", ":BufferLineGoToBuffer 5<CR>", opts)
		map("n", "<leader>6", ":BufferLineGoToBuffer 6<CR>", opts)
		map("n", "<leader>7", ":BufferLineGoToBuffer 7<CR>", opts)
		map("n", "<leader>8", ":BufferLineGoToBuffer 8<CR>", opts)
		map("n", "<leader>9", ":BufferLineGoToBuffer 9<CR>", opts)
		map("n", "<leader>bl", ":BufferLineCycleNext<CR>", opts)
		map("n", "<leader>bh", ":BufferLineCyclePrev<CR>", opts)
		map("n", "<leader>bd", ":BufferLinePickClose<CR>", opts)
	end,
}
