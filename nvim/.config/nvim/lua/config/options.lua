-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.relativenumber = true
vim.opt.number = true

vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.autoindent = true

vim.opt.wrap = false

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.cursorline = true

vim.opt.signcolumn = "yes"

vim.opt.splitright = true
vim.opt.splitbelow = true

vim.opt.iskeyword:append("-")

-- Conceal (useful for markdown/org)
vim.opt.conceallevel = 2
vim.opt.concealcursor = "nc"

-- Use Neovim's stdpath for provider hosts when present.
do
  local python_host = vim.fn.stdpath("data") .. "/py3/bin/python3"
  if vim.fn.executable(python_host) == 1 then
    vim.g.python3_host_prog = python_host
  end

  local node_host = vim.fn.stdpath("data") .. "/node/bin/node"
  if vim.fn.executable(node_host) == 1 then
    vim.g.node_host_prog = node_host
  end
end

