local M = {}

local FALLBACK_COLORSCHEME = "tokyonight-night"
local BUILTIN_FALLBACK_COLORSCHEME = "habamax"
local watcher
local watcher_generation = 0
local reload_generation = 0
local reload_scheduled = false
local augroup
local last_spec
local last_fingerprint
local spec_fingerprints = setmetatable({}, { __mode = "k" })

local function nonempty_string(value)
  return type(value) == "string" and value ~= ""
end

local function notify(message, level)
  vim.schedule(function()
    vim.notify(message, level)
  end)
end

local function config_root()
  if nonempty_string(vim.env.XDG_CONFIG_HOME) then
    return vim.env.XDG_CONFIG_HOME
  end

  local config_dir = vim.fn.stdpath("config")
  return vim.fn.fnamemodify(config_dir, ":h")
end

function M.provider_path()
  return vim.fs.joinpath(config_root(), "omarchy", "current", "theme", "neovim.lua")
end
local function provider_fingerprint(path)
  if vim.fn.filereadable(path) ~= 1 then
    return "<missing>"
  end
  local file = io.open(path, "rb")
  if not file then
    return "<unreadable>"
  end
  local content = file:read("*a") or ""
  file:close()
  return content
end


local function fallback_spec()
  return {
    {
      "folke/tokyonight.nvim",
      priority = 1000,
    },
    {
      "LazyVim/LazyVim",
      opts = {
        colorscheme = FALLBACK_COLORSCHEME,
      },
    },
  }
end

local function valid_spec(spec)
  if type(spec) ~= "table" then
    return false
  end

  local count = 0
  local has_colorscheme = false
  for _, plugin in ipairs(spec) do
    count = count + 1
    if type(plugin) ~= "table" then
      return false
    end

    local source = plugin[1]
    if not nonempty_string(source) and not nonempty_string(plugin.dir) then
      return false
    end

    if source == "LazyVim/LazyVim" and type(plugin.opts) == "table" then
      has_colorscheme = has_colorscheme or nonempty_string(plugin.opts.colorscheme)
    end
  end

  return count > 0 and has_colorscheme
end

function M.load()
  local path = M.provider_path()
  local fingerprint = provider_fingerprint(path)
  local spec

  if vim.fn.filereadable(path) ~= 1 then
    spec = fallback_spec()
  else
    local ok, loaded = pcall(dofile, path)
    if not ok or not valid_spec(loaded) then
      notify("Failed to load Omarchy Neovim theme; using fallback", vim.log.levels.WARN)
      spec = fallback_spec()
    else
      spec = loaded
    end
  end

  spec_fingerprints[spec] = fingerprint
  return spec
end

function M.colorscheme(spec)
  spec = spec or M.load()
  for _, plugin in ipairs(spec) do
    if plugin[1] == "LazyVim/LazyVim" and type(plugin.opts) == "table" then
      if nonempty_string(plugin.opts.colorscheme) then
        return plugin.opts.colorscheme
      end
    end
  end
  return FALLBACK_COLORSCHEME
end

function M.spec()
  local loaded = M.load()
  local result = {}
  for _, plugin in ipairs(loaded) do
    if plugin[1] == "LazyVim/LazyVim" then
      local copy = vim.deepcopy(plugin)
      copy.opts = copy.opts or {}
      -- LazyVim invokes this once during setup; route that initial apply
      -- through the same adapter used by the reload watcher.
      copy.opts.colorscheme = function()
        return M.apply(loaded)
      end
      result[#result + 1] = copy
    else
      result[#result + 1] = plugin
    end
  end
  return result
end

local function apply_transparency()
  local path = vim.fs.joinpath(vim.fn.stdpath("config"), "plugin", "after", "transparency.lua")
  if vim.fn.filereadable(path) ~= 1 then
    return true
  end

  local ok, err = pcall(vim.cmd, { cmd = "source", args = { path } })
  if not ok then
    notify("Failed to apply Neovim transparency: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  return true
end
local function apply_changed_configs(spec, previous)
  if not previous then
    return true
  end

  local configs_ok = true
  for _, plugin in ipairs(spec) do
    local ok, err
    if type(plugin.config) == "function" then
      ok, err = pcall(plugin.config, plugin, plugin.opts)
    elseif plugin[1] ~= "LazyVim/LazyVim" and type(plugin.opts) == "table" then
      local module_name = plugin.main or plugin.name
      if nonempty_string(module_name) then
        local loaded, module = pcall(require, module_name)
        if loaded and type(module) == "table" and type(module.setup) == "function" then
          ok, err = pcall(module.setup, plugin.opts)
        end
      end
    end
    if ok == false then
      configs_ok = false
      notify("Failed to apply Omarchy Neovim theme plugin config: " .. tostring(err), vim.log.levels.ERROR)
    end
  end
  return configs_ok
end


function M.apply(spec)
  spec = spec or M.load()
  local fingerprint = spec_fingerprints[spec]
  if last_spec and ((fingerprint and fingerprint == last_fingerprint) or (not fingerprint and vim.deep_equal(spec, last_spec))) then
    return true
  end

  local previous = last_spec
  local configs_ok = apply_changed_configs(spec, previous)
  local requested = M.colorscheme(spec)
  local need_colorscheme = vim.g.colors_name ~= requested or previous ~= nil
  local ok, err = true, nil
  if need_colorscheme then
    ok, err = pcall(vim.cmd.colorscheme, requested)
  end
  if not ok then
    if requested ~= FALLBACK_COLORSCHEME then
      notify("Failed to apply Omarchy Neovim theme; using fallback", vim.log.levels.WARN)
    end
    ok, err = pcall(vim.cmd.colorscheme, FALLBACK_COLORSCHEME)
  end

  if not ok then
    notify("Failed to apply Neovim fallback theme: " .. tostring(err), vim.log.levels.ERROR)
    ok = pcall(vim.cmd.colorscheme, BUILTIN_FALLBACK_COLORSCHEME)
  end

  if not ok then
    notify("No usable Neovim colorscheme is available", vim.log.levels.ERROR)
    return false
  end
  if not apply_transparency() or not configs_ok then
    return false
  end
  last_spec = vim.deepcopy(spec)
  last_fingerprint = fingerprint
  return true
end

function M.reload()
  return M.apply(M.load())
end

local function queue_reload()
  reload_generation = reload_generation + 1
  if reload_scheduled then
    return
  end

  reload_scheduled = true
  vim.schedule(function()
    reload_scheduled = false
    local generation = reload_generation
    M.reload()
    if generation ~= reload_generation then
      queue_reload()
    end
  end)
end

function M.stop_watcher()
  watcher_generation = watcher_generation + 1
  if watcher then
    pcall(watcher.stop, watcher)
    pcall(watcher.close, watcher)
    watcher = nil
  end
end

function M.start_watcher()
  M.stop_watcher()
  local uv = vim.uv or vim.loop
  if not uv or not uv.new_fs_event then
    return false
  end

  local current_dir = vim.fn.fnamemodify(M.provider_path(), ":h:h")
  if not uv.fs_stat(current_dir) then
    return false
  end

  local handle = uv.new_fs_event()
  if not handle then
    notify("Failed to create Omarchy theme watcher", vim.log.levels.WARN)
    return false
  end
  local generation = watcher_generation
  local ok, started, start_error = pcall(handle.start, handle, current_dir, {}, function(event_error)
    if generation ~= watcher_generation then
      return
    end
    if event_error then
      notify("Omarchy theme watcher failed: " .. tostring(event_error), vim.log.levels.WARN)
      return
    end
    queue_reload()
  end)
  if not ok or not started then
    local reason = start_error or started or "unknown error"
    pcall(handle.close, handle)
    notify("Failed to watch Omarchy theme changes: " .. tostring(reason), vim.log.levels.WARN)
    return false
  end
  augroup = vim.api.nvim_create_augroup("DotfilesThemeAdapter", { clear = true })
  watcher = handle
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = augroup,
    once = true,
    callback = M.stop_watcher,
  })
  return true
end

function M.setup()
  M.start_watcher()
end

return M
