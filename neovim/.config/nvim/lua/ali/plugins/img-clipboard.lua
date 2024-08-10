return {
	"ekickx/clipboard-image.nvim",
	config = function()
		local keymap = vim.keymap -- for conciseness

		keymap.set("n", "<leader>lm", "<Plug>MarkdownPreviewToggle", { desc = "Toggle compile of .md file" }) -- toggle file explorer

		local img = require("clipboard-image")

		img.setup({
			default = {
				img_dir = "figures",
				img_dir_txt = "figures",
				img_name = function()
					vim.fn.inputsave()
					local name = vim.fn.input("Name: ")
					vim.fn.inputrestore()
					return name
				end,
			},
		})
	end,
}
