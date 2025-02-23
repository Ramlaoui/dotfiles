return {
	"lervag/vimtex",
	-- event = { "BufReadPre", "BufNewFile" },
	config = function()
		-- PDF Viewer:
		-- http://manpages.ubuntu.com/manpages/trusty/man5/zathurarc.5.html

		vim.g.vimtex_view_method = "sioyek"
		vim.g.vimtex_quickfix_mode = 0
		-- for synctex, install xdotool
		--
		vim.g.tex_flavor = "latex"

		vim.g.vimtex_mappings_enabled = 1

		-- Error suppression:
		-- https://github.com/lervag/vimtex/blob/master/doc/vimtex.txt

		-- vim.g["vimtex_log_ignore"] = {
		-- 	"Underfull",
		-- 	"Overfull",
		-- 	"specifier changed to",
		-- 	"Token not allowed in a PDF string",
		-- }

		vim.g["vimtex_context_pdf_viewer"] = "sioyek"

		-- Define two sets of compiler options:
		-- 1. Default options (typically use pdflatex)
		local default_compiler_options = {
			"-verbose",
			"-file-line-error",
			"-synctex=1",
			"-interaction=nonstopmode",
			"-shell-escape",
		}
		-- 2. Options for lualatex (adds the -pdflatex=lualatex flag)
		local lualatex_compiler_options = {
			"-verbose",
			"-pdflatex=lualatex",
			"-file-line-error",
			"-synctex=1",
			"-interaction=nonstopmode",
			"-shell-escape",
		}

		-- (Optional) Set the global compiler options to the default ones.
		vim.g.vimtex_compiler_latexmk = { options = default_compiler_options }

		-- Helper function to compile using the default compiler (pdfLaTeX)
		local function compile_default()
			vim.g.vimtex_compiler_latexmk.options = default_compiler_options
			vim.cmd("VimtexCompile")
		end

		-- Helper function to compile using lualatex
		local function compile_lualatex()
			vim.g.vimtex_compiler_latexmk.options = lualatex_compiler_options
			vim.cmd("VimtexCompile")
		end

		-- Map a key for default compilation
		vim.api.nvim_set_keymap(
			"n",
			"<localleader>lcd",
			"<cmd>lua compile_default()<CR>",
			{ noremap = true, silent = true, desc = "Compile with default pdflatex" }
		)

		-- Map a key for lualatex compilation
		vim.api.nvim_set_keymap(
			"n",
			"<localleader>lcl",
			"<cmd>lua compile_lualatex()<CR>",
			{ noremap = true, silent = true, desc = "Compile with lualatex" }
		)

		-- vim.g['vimtex_complete_enabled'] = 1
		-- vim.g['vimtex_compiler_progname'] = 'nvr'
		-- vim.g['vimtex_complete_close_braces'] = 1
		--

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

		-- keymap.set("n", "<leader>ll", "<plug>(vimtex-compile)", { desc = "Toggle compile of .tex file" }) -- toggle file explorer
	end,
}
