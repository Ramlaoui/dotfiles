require("default.core.options")
require("default.core.keymaps")
require("default.core.colorscheme")
require("default.lazy")

vim.cmd([[
  autocmd VimEnter * set wrap
]])

-- Conceal links (probably something else too)
vim.opt.conceallevel = 2
vim.opt.concealcursor = "nc"

vim.g.python3_host_prog = "$XDG_DATA_HOME/nvim/py3/bin/python3"
-- node host
vim.g.node_host_prog = "$XDG_DATA_HOME/node/bin/node"

local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- General Settings
local general = augroup("General", { clear = true })

vim.api.nvim_create_autocmd("BufEnter", {
    callback = function()
        vim.opt.formatoptions:remove({ "c", "r", "o" })
    end,
    desc = "Disable New Line Comment",
})
