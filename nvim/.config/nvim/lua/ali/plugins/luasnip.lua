return {
	"L3MON4D3/LuaSnip", -- snippet engine
	-- 	dependencies = {
	--		"iurimateus/luasnip-latex-snippets.nvim",
	--	},
	config = function()
		local luasnip = require("luasnip")

		luasnip.config.setup({
			history = false,
			-- enable_autosnippets = true,
			store_selection_keys = "<Tab>",
		})
		-- require("luasnip-latex-snippets").setup()
	end,
}
