-- Fork: https://github.com/evesdropper/luasnip-latex-snippets.nvim

-- [
-- snip_env + autosnippets
-- ]
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

--[
-- personal imports
--]
local tex = require("snippets.tex.utils.conditions")
local make_condition = require("luasnip.extras.conditions").make_condition
local in_bullets_cond = make_condition(tex.in_bullets)
local line_begin = require("luasnip.extras.conditions.expand").line_begin

M = {
	-- Header
	autosnippet(
		{
			trig = "header",
			trigEngine = "plain",
			name = "latex header",
			dscr = "Inserts a basic LaTeX header",
			snippettype = "autosnippet",
		},
		fmta(
			[[
        \documentclass[a4paper]{article}

        \usepackage[utf8]{inputenc}
        \usepackage[T1]{fontenc}
        \usepackage{textcomp}
        \usepackage[dutch]{babel}
        \usepackage{amsmath, amsthm, amssymb, calrsfs, wasysym, verbatim, bbm, color, graphics, geometry}
        \usepackage{import} % for importing pdfs
        \usepackage{xifthen} % provides \isempty test
        \usepackage{pdfpages} % for including pdfs
        \usepackage{transparent} % for including pdfs
        \usepackage{xcolor}
        \usepackage{float} % for H in figure
        \usepackage{enumitem}
        \usepackage{subfig} % for subfigures

        \geometry{tmargin=.75in, bmargin=.75in, lmargin=.75in, rmargin = .75in}  

        \newtheorem{theorem}{Theorem}
        \newtheorem{definition}{Definition}
        \newtheorem{conv}{Convention}
        \newtheorem{remark}{Remark}
        \newtheorem{lem}{Lemma}
        \newtheorem{cor}{Corollary}
        \newtheorem{prop}{Proposition}

        \newcommand{\R}{\mathbb{R}}
        \newcommand{\C}{\mathbb{C}}
        \newcommand{\Z}{\mathbb{Z}}
        \newcommand{\N}{\mathbb{N}}
        \newcommand{\Q}{\mathbb{Q}}
        \newcommand{\Cdot}{\boldsymbol{\cdot}}
        \newcommand{\Cov}{\mathrm{Cov}}
        \newcommand{\Var}{\mathrm{Var}}

        \begin{document}
            <>
        \end{document}
        ]],
			{ i(1) }
		),
		{ condition = tex.in_preamble }
	),

	-- Columns
	s(
		{ trig = "col", name = "columns", trigEngine = "plain", snippetType = "autosnippet" },
		fmta(
			[[
            \begin{columns}
                \column{<>\textwidth}
                <>

                \column{<>\textwidth}
                <>
            \end{columns}
            ]],
			{
				i(1),
				i(2),
				rep(1),
				i(3),
			}
		),
		{
			condition = function(line_to_cursor, matched_trigger, captures)
				return M.in_text() and line_begin(line_to_cursor, matched_trigger, captures)
			end,
		}
	),

	-- Figures
	s(
		{ trig = "fig", name = "figure", trigEngine = "plain", snippetType = "autosnippet" },
		fmta(
			[[
            \begin{figure}[<>]
                \centering
                \includegraphics[width=<>\textwidth]{<>}
                \caption{<>}
                \label{fig:<>}
            \end{figure}
            ]],
			{
				t("htbp"),
				t("0.8"),
				i(1),
				i(2),
				rep(1),
			}
		),
		{
			condition = function(line_to_cursor, matched_trigger, captures)
				return M.in_text() and line_begin(line_to_cursor, matched_trigger, captures)
			end,
		}
	),

	s(
		{ trig = "subfig", name = "multifigure", trigEngine = "plain", snippetType = "autosnippet" },
		fmta(
			[[
            \begin{figure}[htbp]
                \centering
                \begin{subfigure}{0.5\textwidth}
                    \centering
                    \includegraphics[width=1\textwidth]{<>}
                    \caption{<>}
                    \label{fig:}
                \end{subfigure}
                \hfill
                \begin{subfigure}{0.5\textwidth}
                    \centering
                    \includegraphics[width=1\textwidth]{<>}
                    \caption{<>}
                    \label{fig:}
                \end{subfigure}
                \caption{<>}
                \label{fig:}
            \end{figure}
            ]],
			{
				i(1),
				i(2),
				i(3),
				i(4),
				i(5),
			}
		),
		{
			condition = function(line_to_cursor, matched_trigger, captures)
				return M.in_text() and line_begin(line_to_cursor, matched_trigger, captures)
			end,
		}
	),

	autosnippet(
		{ trig = "beg", name = "begin/end", dscr = "begin/end environment (generic)" },
		fmta(
			[[
    \begin{<>}
    <>
    \end{<>}
    ]],
			{ i(1), i(0), rep(1) }
		),
		{ condition = tex.begin_text, show_condition = tex.begin_text }
	),

	autosnippet(
		{ trig = "item", name = "itemize", dscr = "bullet points (itemize)" },
		fmta(
			[[ 
    \begin{itemize}
    \item <>
    \end{itemize}
    ]],
			{
				c(1, {
					i(0),
					sn(
						nil,
						fmta(
							[[
        [<>] <>
        ]],
							{ i(1), i(0) }
						)
					),
				}),
			}
		),
		{ condition = tex.begin_text, show_condition = tex.begin_text }
	),

	-- requires enumitem
	autosnippet(
		{ trig = "enum", name = "enumerate", dscr = "numbered list (enumerate)" },
		fmta(
			[[ 
    \begin{enumerate}<>
    \item <>
    \end{enumerate}
    ]],
			{
				c(1, {
					t(""),
					sn(
						nil,
						fmta(
							[[
        [label=<>]
        ]],
							{ c(1, { t("(\\alph*)"), t("(\\roman*)"), i(1) }) }
						)
					),
				}),
				c(2, {
					i(0),
					sn(
						nil,
						fmta(
							[[
        [<>] <>
        ]],
							{ i(1), i(0) }
						)
					),
				}),
			}
		),
		{ condition = tex.begin_text, show_condition = tex.begin_text }
	),

	-- generate new bullet points
	autosnippet(
		{ trig = "--", hidden = true },
		{ t("\\item") },
		{ condition = in_bullets_cond * line_begin, show_condition = in_bullets_cond * line_begin }
	),
	autosnippet(
		{ trig = "!-", name = "bullet point", dscr = "bullet point with custom text" },
		fmta(
			[[ 
    \item [<>]<>
    ]],
			{ i(1), i(0) }
		),
		{ condition = in_bullets_cond * line_begin, show_condition = in_bullets_cond * line_begin }
	),
}

return M
