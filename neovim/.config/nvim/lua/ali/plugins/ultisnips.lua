return {
	"SirVer/ultisnips",
	config = function()
		vim.g.UltiSnipsExpandTrigger = "<tab>"
		vim.g.UltiSnipsJumpForwardTrigger = "<tab>"
		vim.g.UltiSnipsJumpBackwardTrigger = "<s-tab>"
		vim.g.UltiSnipsSnippetDirectories = { "~/.config/nvim/my_snippets" }
	end,
}
