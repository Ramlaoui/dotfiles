return {
  {
    "christoomey/vim-tmux-navigator",
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
    },
    keys = {
      -- NOTE: `<cmd>...<cr>` mappings do not interpret `<C-U>` like `:...<CR>` does.
      -- Including it inserts a literal ^U (0x15) into the Ex command and causes:
      --   E492: Not an editor command: ^UTmuxNavigateLeft
      { "<C-h>", "<cmd>TmuxNavigateLeft<cr>" },
      { "<C-j>", "<cmd>TmuxNavigateDown<cr>" },
      { "<C-k>", "<cmd>TmuxNavigateUp<cr>" },
      { "<C-l>", "<cmd>TmuxNavigateRight<cr>" },
      { "<C-\\>", "<cmd>TmuxNavigatePrevious<cr>" },
    },
    init = function()
      vim.g.tmux_navigator_no_mappings = 1
    end,
  },
}
