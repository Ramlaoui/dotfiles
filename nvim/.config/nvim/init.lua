require("default.core.options")
require("default.core.keymaps")
require("default.core.colorscheme")
require("default.lazy")

vim.cmd([[
  autocmd VimEnter * set wrap
]])

vim.g.python3_host_prog = "$XDG_DATA_HOME/nvim/py3/bin/python3"
