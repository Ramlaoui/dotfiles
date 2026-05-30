return {
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = function()
      require("lazy").load({ plugins = { "markdown-preview.nvim" } })
      vim.fn["mkdp#util#install"]()
    end,
    keys = {
      { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", ft = "markdown", desc = "Markdown Preview (browser)" },
    },
    config = function()
      vim.g.mkdp_echo_preview_url = 1

      if not vim.env.SSH_CONNECTION then
        return
      end

      vim.g.mkdp_port = "8080"
      vim.g.mkdp_browser = "true"

      local sender = vim.fn.exepath("tmux-opener-send")
      if sender == "" then
        local repo_sender = vim.fn.expand("~/projects/tmux-opener/scripts/tmux-opener-send")
        if vim.fn.executable(repo_sender) == 1 then
          sender = repo_sender
        end
      end

      if sender == "" then
        return
      end

      vim.g.mkdp_tmux_opener_send = sender
      vim.g.mkdp_browserfunc = "MkdpOpenWithTmuxOpener"
      vim.cmd([[
        function! MkdpOpenWithTmuxOpener(url) abort
          let l:sender = get(g:, 'mkdp_tmux_opener_send', '')
          if empty(l:sender)
            return
          endif
          call jobstart([l:sender, a:url, '--fallback', 'none'], {'detach': v:true})
        endfunction
      ]])
    end,
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-mini/mini.icons",
    },
    ft = { "markdown" },
    opts = {
      code = {
        sign = false,
        width = "block",
        right_pad = 1,
      },
      heading = {
        sign = false,
        icons = {},
      },
      checkbox = {
        enabled = false,
      },
    },
    config = function(_, opts)
      require("render-markdown").setup(opts)
      Snacks.toggle({
        name = "Render Markdown",
        get = require("render-markdown").get,
        set = require("render-markdown").set,
      }):map("<leader>mr")
    end,
  },
}
