return {
	-- Separate headlines for makdown and org with visual backgrounds
	"lukas-reineke/headlines.nvim",
	dependencies = "nvim-treesitter/nvim-treesitter",
	lazy = true,
	config = true, -- or `opts = {}`
	setup = function()
		require("headlines").setup()
	end,
}
