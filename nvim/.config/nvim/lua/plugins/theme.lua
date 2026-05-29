local fallback = {
  {
    "folke/tokyonight.nvim",
    priority = 1000,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight-night",
    },
  },
}

local omarchy_theme = vim.fn.expand("~/.config/omarchy/current/theme/neovim.lua")
if vim.fn.filereadable(omarchy_theme) ~= 1 then
  return fallback
end

local ok, spec = pcall(dofile, omarchy_theme)
if not ok or type(spec) ~= "table" then
  vim.schedule(function()
    vim.notify("Failed to load Omarchy Neovim theme; using fallback", vim.log.levels.WARN)
  end)
  return fallback
end

return spec
