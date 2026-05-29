local function diffview_open_prompt()
  vim.ui.input({
    prompt = "Diffview rev/range: ",
    default = "HEAD^!",
  }, function(input)
    if input and input ~= "" then
      vim.cmd("DiffviewOpen " .. input)
    end
  end)
end

return {
  {
    "sindrets/diffview.nvim",
    cmd = {
      "DiffviewClose",
      "DiffviewFileHistory",
      "DiffviewFocusFiles",
      "DiffviewLog",
      "DiffviewOpen",
      "DiffviewRefresh",
      "DiffviewToggleFiles",
    },
    keys = {
      { "<leader>gv", "<cmd>DiffviewOpen<cr>", desc = "Diffview Open" },
      { "<leader>gvc", diffview_open_prompt, desc = "Diffview Commit/Range" },
      { "<leader>gvf", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview File History" },
      { "<leader>gvh", "<cmd>DiffviewFileHistory<cr>", desc = "Diffview History" },
      { "<leader>gvq", "<cmd>DiffviewClose<cr>", desc = "Diffview Close" },
    },
  },
}
