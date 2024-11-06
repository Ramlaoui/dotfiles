-- From https://github.com/evesdropper/dotfiles/blob/main/nvim/lua/snippets/lua.lua

local ls = require("luasnip")
local s = ls.snippet
local c = ls.choice_node
local sn = ls.snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local d = ls.dynamic_node
local fmt = require("luasnip.extras.fmt").fmt
local fmta = require("luasnip.extras.fmt").fmta
local rep = require("luasnip.extras").rep

--[
-- Imports
--]
local autosnippet = ls.extend_decorator.apply(s, { snippetType = "autosnippet" })

--[
-- dynamic setup
--]

return {
	--[
	-- LuaSnip Snippets
	--]

	-- Lazy
	autosnippet(
		{ trig = "lazy", name = "lazy", dscr = "Lazy package" },
		fmta(
			[[ 
            return {
                "<>/",
                lazy = true,
                dependencies = {
                    "/", -- dependency 1
                },
                config = function()
                    local <> = require("<>")
                    <>
                end,
                }
            ]],
			{ i(1), rep(1), rep(2), i(2) }
		)
	),
}
