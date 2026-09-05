local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local lazy_commit = "85c7ff3711b730b4030d03144f6db6375044ae82"

local function bootstrap_error(message)
  error(("Unable to bootstrap lazy.nvim at %s:\n%s"):format(lazypath, message), 0)
end

local function valid_checkout()
  if vim.fn.isdirectory(lazypath) ~= 1 then
    return false
  end
  local git_dir = vim.fn.system({ "git", "-C", lazypath, "rev-parse", "--git-dir" })
  if vim.v.shell_error ~= 0 or vim.trim(git_dir) == "" then
    return false
  end
  return vim.fn.filereadable(lazypath .. "/lua/lazy/init.lua") == 1
end

if not valid_checkout() then
  if (vim.uv or vim.loop).fs_stat(lazypath) then
    bootstrap_error("the existing path is not a complete git checkout; remove it manually and retry")
  end

  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--no-checkout", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    bootstrap_error(out)
  end

  out = vim.fn.system({ "git", "-C", lazypath, "checkout", "--detach", lazy_commit })
  if vim.v.shell_error ~= 0 then
    bootstrap_error(out)
  end
  if not valid_checkout() then
    bootstrap_error("the pinned commit did not produce a complete checkout")
  end
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    -- add LazyVim and import its plugins
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- import/override with your plugins
    { import = "plugins" },
  },
  defaults = {
    -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
    -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
    lazy = false,
    -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
    -- have outdated releases, which may break your Neovim install.
    version = false, -- always use the latest git commit
    -- version = "*", -- try installing the latest stable version for plugins that support semver
  },
  install = { colorscheme = { "tokyonight", "habamax" } },
  checker = {
    enabled = true, -- check for plugin updates periodically
    notify = false, -- notify on update
  }, -- automatically check for plugin updates
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        "gzip",
        -- "matchit",
        -- "matchparen",
        -- "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})

