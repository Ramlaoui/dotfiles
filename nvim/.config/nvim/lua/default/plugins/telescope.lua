return {
	"nvim-telescope/telescope.nvim",
	branch = "0.1.x",
	dependencies = {
		"nvim-telescope/telescope-bibtex.nvim",
		"nvim-lua/plenary.nvim",
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		"nvim-tree/nvim-web-devicons",
	},
	config = function()
		local telescope = require("telescope")
		local actions = require("telescope.actions")

		telescope.load_extension("bibtex")

		telescope.setup({
			pickers = {
				find_files = {
					hidden = true,
				},
			},
			defaults = {
				path_display = { "truncate " },
				mappings = {
					i = {
						["<C-k>"] = actions.move_selection_previous, -- move to prev result
						["<C-j>"] = actions.move_selection_next, -- move to next result
						["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
					},
				},
			},
			extensions = {
				-- Telescope bibtex
				bibtex = {
					depth = 1,
					custom_formats = {
						{
							id = "zettel",
							cite_marker = "#%s",
						},
					},
					format = "zettel",
					citation_max_auth = 2,
					context = false,
					context_fallback = true,
					wrap = false,
					global_files = {
						"~/Library/Mobile Documents/com~apple~CloudDocs/zotero/bibs/references.bib",
					},
				},
			},
		})

		telescope.load_extension("fzf")

		-- set keymaps
		local keymap = vim.keymap -- for conciseness

		keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Fuzzy find files in cwd" })
		keymap.set("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>", { desc = "Fuzzy find recent files" })
		keymap.set("n", "<leader>fs", "<cmd>Telescope live_grep<cr>", { desc = "Find string in cwd" })
		keymap.set("n", "<leader>fc", "<cmd>Telescope grep_string<cr>", { desc = "Find string under cursor in cwd" })
	end,
}
