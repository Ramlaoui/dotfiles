return {
	"L3MON4D3/LuaSnip", -- snippet engine
	-- 	dependencies = {
	--		"iurimateus/luasnip-latex-snippets.nvim",
	--	},
	build = "make install_jsregexp", -- using ecma regex in snippets
	lazy = true,
	config = function()
		require("luasnip.loaders.from_lua").lazy_load({
			paths = "~/.config/nvim/lua/snippets/",
			fs_event_providers = { autocmd = true, libuv = true },
		})

		local luasnip = require("luasnip")

		vim.cmd([[
            " " Currently set in cmp for Super-Tab
            " " Expand or jump in insert mode
            " imap <silent><expr> <Tab> luasnip#expand_or_jumpable() ? '<Plug>luasnip-expand-or-jump' : '<Tab>'
            "
            " " Jump forward through tabstops in visual mode
            " smap <silent><expr> <Tab> luasnip#jumpable(1) ? '<Plug>luasnip-jump-next' : '<Tab>'
            "
            " " Jump backward through snippet tabstops with Shift-Tab (for example)
            " imap <silent><expr> <S-Tab> luasnip#jumpable(-1) ? '<Plug>luasnip-jump-prev' : '<S-Tab>'
            " smap <silent><expr> <S-Tab> luasnip#jumpable(-1) ? '<Plug>luasnip-jump-prev' : '<S-Tab>'

            " Cycle forward through choice nodes with Control-f (for example)
            imap <silent><expr> <C-f> luasnip#choice_active() ? '<Plug>luasnip-next-choice' : '<C-f>'
            smap <silent><expr> <C-f> luasnip#choice_active() ? '<Plug>luasnip-next-choice' : '<C-f>'

            " Menu-like selection of choice nodes
            inoremap <c-u> <cmd>lua require("luasnip.extras.select_choice")()<cr>

            ]])

		luasnip.setup({
			history = true,
			enable_autosnippets = true,
			store_selection_keys = "<Tab>",
		})
		-- require("luasnip-latex-snippets").setup()
	end,
}
-- --
-- return {}
