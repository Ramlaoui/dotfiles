return {
  {
    "L3MON4D3/LuaSnip",
    version = "v2.4.1",
    build = "make install_jsregexp",
    config = function(_, opts)
      require("luasnip").setup(opts)
      require("luasnip.loaders.from_lua").lazy_load({
        paths = vim.fn.stdpath("config") .. "/lua/snippets",
      })
    end,
  },
}
