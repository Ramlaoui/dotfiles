return {
  -- Load custom LuaSnip snippets from `lua/snippets/` if LuaSnip is installed.
  {
    name = "custom-snippets-loader",
    -- Make this a "local plugin" so Lazy accepts the spec.
    dir = vim.fn.stdpath("config"),
    event = "VeryLazy",
    config = function()
      local ok = pcall(require, "luasnip")
      if not ok then
        return
      end

      require("luasnip.loaders.from_lua").lazy_load({
        paths = vim.fn.stdpath("config") .. "/lua/snippets",
      })
    end,
  },
}
