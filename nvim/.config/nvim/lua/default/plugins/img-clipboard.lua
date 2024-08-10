return {
	"dfendr/clipboard-image.nvim",
	config = function()
		local keymap = vim.keymap -- for conciseness

		keymap.set("n", "<leader>lm", "<Plug>MarkdownPreviewToggle", { desc = "Toggle compile of .md file" }) -- toggle file explorer
	end,
}
