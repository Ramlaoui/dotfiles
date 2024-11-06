local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local isn = ls.indent_snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local c = ls.choice_node
local d = ls.dynamic_node
local r = ls.restore_node
local events = require("luasnip.util.events")
local ai = require("luasnip.nodes.absolute_indexer")
local extras = require("luasnip.extras")
local l = extras.lambda
local rep = extras.rep
local p = extras.partial
local m = extras.match
local n = extras.nonempty
local dl = extras.dynamic_lambda
local fmt = require("luasnip.extras.fmt").fmt
local fmta = require("luasnip.extras.fmt").fmta
local conds = require("luasnip.extras.expand_conditions")
local postfix = require("luasnip.extras.postfix").postfix
local types = require("luasnip.util.types")
local parse = require("luasnip.util.parser").parse_snippet
local ms = ls.multi_snippet
local autosnippet = ls.extend_decorator.apply(s, { snippetType = "autosnippet" })

M = {
	-- Code Block
	s(
		{
			trig = "code",
			name = "code",
			dscr = "Code block",
		},
		fmta(
			[[
            #+BEGIN_SRC <>
            <>
            #+END_SRC
    ]],
			{ i(1, "language"), i(2) }
		)
	),

	-- Table Creating

	-- Link
	s({
		trig = "link",
		name = "link",
		dscr = "link",
	}, fmta("[[<>][<>]]", { i(1, "link"), i(2, "description") })),

	-- Math
	autosnippet(
		{
			trig = "mk",
			name = "math",
			dscr = "Math inline",
		},
		fmta(
			[[
            $$<>$$
            ]],
			{ i(1) }
		)
	),

	-- Math Block
	autosnippet(
		{
			trig = "dm",
			name = "math block",
			dscr = "Math block",
		},
		fmta(
			[[
            \begin{equation}
            <>
            \end{equation}
            ]],
			{ i(1) }
		)
	),

	-- Heading
	autosnippet(
		{
			trig = "h1",
			name = "heading",
			dscr = "Heading",
		},
		fmta(
			[[
            * <>
            ]],
			{ i(1) }
		)
	),

	autosnippet(
		{
			trig = "h2",
			name = "heading",
			dscr = "Heading",
		},
		fmta(
			[[
            ** <>
            ]],
			{ i(1) }
		)
	),

	autosnippet(
		{
			trig = "h3",
			name = "heading",
			dscr = "Heading",
		},
		fmta(
			[[
            *** <>
            ]],
			{ i(1) }
		)
	),

	-- Blockquote and example
	autosnippet(
		{
			trig = "bq",
			name = "blockquote",
			dscr = "Blockquote",
		},
		fmta(
			[[
            #+BEGIN_QUOTE
            <>
            #+END_QUOTE
            ]],
			{ i(1) }
		)
	),

	s(
		{
			trig = "ex",
			name = "example",
			dscr = "Example",
		},
		fmta(
			[[
            #+BEGIN_EXAMPLE
            <>
            #+END_EXAMPLE
            ]],
			{ i(1) }
		)
	),

	-- Image
	autosnippet({
		trig = "img",
		name = "image",
		dscr = "Image",
	}, fmta("[[file:<>]]", { i(1, "image.png") })),

	s({
		trig = "file",
		name = "file",
		dscr = "File",
	}, fmta("[[file:<>][<>]]", { i(1, "image.png"), i(2, "description") })),
}

return M
