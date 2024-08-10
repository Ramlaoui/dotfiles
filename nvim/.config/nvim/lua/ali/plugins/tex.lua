return {
	"lervag/vimtex",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		-- PDF Viewer:
		-- http://manpages.ubuntu.com/manpages/trusty/man5/zathurarc.5.html
		vim.g["vimtex_view_method"] = "sioyek"
		vim.g["vimtex_quickfix_mode"] = 0

		-- Ignore mappings
		vim.g["vimtex_mappings_enabled"] = 0

		-- Auto Indent
		vim.g["vimtex_indent_enabled"] = 0

		-- Syntax highlighting
		vim.g["vimtex_syntax_enabled"] = 1

		-- Error suppression:
		-- https://github.com/lervag/vimtex/blob/master/doc/vimtex.txt

		vim.g["vimtex_log_ignore"] = {
			"Underfull",
			"Overfull",
			"specifier changed to",
			"Token not allowed in a PDF string",
		}

		vim.g["vimtex_context_pdf_viewer"] = "okular"

		-- vim.g['vimtex_complete_enabled'] = 1
		-- vim.g['vimtex_compiler_progname'] = 'nvr'
		-- vim.g['vimtex_complete_close_braces'] = 1
		--
		local keymap = vim.keymap -- for conciseness

		vim.api.nvim_set_keymap(
			"i",
			"<C-f>",
			"<Esc>: silent exec '.!inkscape-figures create \"'.getline('.').'\" \"'.b:vimtex.root.'/figures/\"'<CR><CR>:w<CR>",
			{ noremap = true }
		)

		vim.api.nvim_set_keymap(
			"n",
			"<C-f>",
			": silent exec '!inkscape-figures edit \"'.b:vimtex.root.'/figures/\" > /dev/null 2>&1 &'<CR><CR>:redraw!<CR>",
			{ noremap = true }
		)

		keymap.set("n", "<leader>ll", "<plug>(vimtex-compile)", { desc = "Toggle compile of .tex file" }) -- toggle file explorer
	end,
}
