return {
	"iamcco/markdown-preview.nvim",
	config = function()
		vim.fn["mkdp#util#install"]()
		vim.api.nvim_set_keymap("n", "<localleader>lm", "<Plug>MarkdownPreview", { noremap = false })
	end,
}
