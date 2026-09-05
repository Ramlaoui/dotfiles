local tabpilot_dir = vim.env.TABPILOT_NVIM_DIR
if not tabpilot_dir or tabpilot_dir == "" or vim.fn.isdirectory(tabpilot_dir) ~= 1 then
  return {}
end

return {
  {
    dir = tabpilot_dir,
    name = "tabpilot.nvim",
    config = function()
      require("tabpilot").setup()
    end,
  },
}
