-- Abbreviations used in this article and the LuaSnip docs
local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local d = ls.dynamic_node
local fmt = require("luasnip.extras.fmt").fmt
local fmta = require("luasnip.extras.fmt").fmta
local rep = require("luasnip.extras").rep

local get_visual = function(args, parent)
	if #parent.snippet.env.LS_SELECT_RAW > 0 then
		return sn(nil, i(1, parent.snippet.env.LS_SELECT_RAW))
	else -- If LS_SELECT_RAW is empty, return a blank insert node
		return sn(nil, i(1))
	end
end

local math = function()
	-- The `math` function requires the VimTeX plugin
	return vim.fn["vimtex#syntax#in_mathzone"]() == 1
end

local line_begin = require("luasnip.extras.expand_conditions").line_begin

return {
	s(
		{ trig = "beg", name = "begin", regTrig = true, wordTrig = false, snippetType = "autosnippet" },
		fmta(
			[[
        \begin{<>}
        <>
        \end{<>}
        ]],
			{ i(1), i(2), rep(1) }
		)
	),

	s(
		{ trig = "tit", dscr = "Expands 'tit' into LaTeX's textit{} command.", snippetType = "autosnippet" },
		fmta("\\textit{<>}", {
			d(1, get_visual),
		})
	),

	s(
		{ trig = "tbf", dscr = "Expands 'tbb' into LaTeX's textbf{} command.", snippetType = "autosnippet" },
		fmta("\\textbf{<>}", {
			d(1, get_visual),
		})
	),

	s(
		{ trig = "eq", name = "equation" },
		fmta(
			[[
        \begin{equation}
            <>
        .\end{equation}<>
        ]],
			{ i(1), i(2) }
		)
	),

	s(
		{ trig = "([%a%)%]%}])00", regTrig = true, wordTrig = false, snippetType = "autosnippet" },
		fmta("<>_{<>}", {
			f(function(_, snip)
				return snip.captures[1]
			end),
			t("0"),
		})
	),

	s(
		{ trig = "([^%a])ff", regTrig = true, wordTrig = false },
		fmta([[\frac{<>}{<>}]], {
			-- f(function(_, snip)
			-- 	return snip.captures[1]
			-- end),
			i(1),
			i(2),
		})
	),
}
