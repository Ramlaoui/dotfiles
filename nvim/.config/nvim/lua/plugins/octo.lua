return {
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>gp", false },
      { "<leader>gP", false },
    },
  },
  {
    "pwntester/octo.nvim",
    cmd = "Octo",
    event = { { event = "BufReadCmd", pattern = "octo://*" } },
    opts = {
      picker = "snacks",
      enable_builtin = true,
      use_local_fs = true,
      mappings = {
        submit_win = {
          approve_review = { lhs = "<localleader>va", desc = "approve review", mode = { "n" } },
          comment_review = { lhs = "<localleader>vc", desc = "comment review", mode = { "n" } },
          request_changes = { lhs = "<localleader>vR", desc = "request changes review", mode = { "n" } },
        },
      },
    },
    keys = {
      { "<leader>ghi", "<cmd>Octo issue list<cr>", desc = "Octo Issues" },
      { "<leader>gp", "<cmd>Octo pr list<cr>", desc = "Octo Pull Requests" },
      { "<leader>gP", "<cmd>Octo pr search<cr>", desc = "Octo Search Pull Requests" },
      { "<leader>ghp", "<cmd>Octo pr list<cr>", desc = "Octo Pull Requests" },
      { "<leader>ghs", "<cmd>Octo search<cr>", desc = "Octo Search" },
      { "<leader>ghn", "<cmd>Octo notification list<cr>", desc = "Octo Notifications" },

      { "<localleader>a", "", desc = "+assignee (Octo)", ft = "octo" },
      { "<localleader>c", "", desc = "+comment/code (Octo)", ft = "octo" },
      { "<localleader>g", "", desc = "+goto issue (Octo)", ft = "octo" },
      { "<localleader>i", "", desc = "+issue (Octo)", ft = "octo" },
      { "<localleader>l", "", desc = "+label (Octo)", ft = "octo" },
      { "<localleader>p", "", desc = "+pr (Octo)", ft = "octo" },
      { "<localleader>pr", "", desc = "+rebase (Octo)", ft = "octo" },
      { "<localleader>ps", "", desc = "+squash (Octo)", ft = "octo" },
      { "<localleader>r", "", desc = "+react/resolve (Octo)", ft = "octo" },
      { "<localleader>v", "", desc = "+review (Octo)", ft = "octo" },
    },
    dependencies = {
      "folke/snacks.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
    },
  },
}
