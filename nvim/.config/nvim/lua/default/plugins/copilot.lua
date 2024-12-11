return {
	"github/copilot.vim",
	-- "zbirenbaum/copilot.lua",
	-- cmd = "Copilot",
	-- event = "InsertEnter",
	config = function()
		vim.g.copilot_filetypes = {
			-- Set markdown support to true
			markdown = true,
		}
		-- require("copilot").setup({
		-- 	panel = {
		-- 		auto_refresh = true,
		-- 	},
		-- 	suggestion = {
		-- 		auto_trigger = true,
		-- 	},
		-- })

		-- Fallback completion keymap to Alt-<Tab>
		vim.api.nvim_set_keymap("i", "<A-Tab>", "v:lua.copilot_tab()", { expr = true })
	end,
}
