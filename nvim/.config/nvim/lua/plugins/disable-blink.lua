return {
  {
    "saghen/blink.cmp",
    opts = function(_, opts)
      opts.completion = opts.completion or {}
      opts.completion.documentation = opts.completion.documentation or {}
      opts.completion.documentation.auto_show = false
      opts.completion.ghost_text = opts.completion.ghost_text or {}
      opts.completion.ghost_text.enabled = false
      opts.completion.menu = opts.completion.menu or {}
      opts.completion.menu.auto_show = false

      opts.cmdline = opts.cmdline or {}
      opts.cmdline.enabled = false

      opts.keymap = opts.keymap or {}
      opts.keymap["<Tab>"] = false
      opts.keymap["<S-Tab>"] = false

      opts.sources = opts.sources or {}
      opts.sources.default = {}
    end,
  },
}
