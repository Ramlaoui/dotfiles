"""Exercise dotfiles-owned Neovim seams without installing plugins."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import textwrap
import unittest


REPO = Path(__file__).resolve().parents[1]
LUA_ROOT = REPO / "nvim/.config/nvim/lua"
SNIPPETS_LOADER = LUA_ROOT / "plugins/snippets-loader.lua"
TABPILOT_PLUGIN = LUA_ROOT / "plugins/tabpilot.lua"


LUA_SNIPPET_STUBS = r"""
local function node(...)
  return { args = { ... } }
end

local ls = {
  snippet = node,
  snippet_node = node,
  indent_snippet_node = node,
  text_node = node,
  insert_node = node,
  function_node = node,
  choice_node = node,
  dynamic_node = node,
  restore_node = node,
  multi_snippet = node,
  extend_decorator = {
    apply = function()
      return node
    end,
  },
}
package.preload["luasnip"] = function()
  return ls
end
package.preload["luasnip.extras"] = function()
  return setmetatable({}, { __index = function() return node end })
end
package.preload["luasnip.extras.fmt"] = function()
  return { fmt = node, fmta = node }
end
package.preload["luasnip.extras.conditions.expand"] = function()
  return { line_begin = function() return true end }
end
package.preload["luasnip.extras.expand_conditions"] = function()
  return { line_begin = function() return true end }
end
package.preload["luasnip.extras.conditions"] = function()
  return {
    make_condition = function(condition)
      return setmetatable({}, {
        __call = function(_, ...) return condition(...) end,
        __mul = function(_, other)
          return function(...) return condition(...) and other(...) end
        end,
      })
    end,
  }
end
package.preload["luasnip.extras.postfix"] = function()
  return { postfix = node }
end
package.preload["luasnip.util.events"] = function()
  return {}
end
package.preload["luasnip.util.absolute_indexer"] = function()
  return {}
end
package.preload["luasnip.nodes.absolute_indexer"] = function()
  return {}
end
package.preload["luasnip.util.types"] = function()
  return {}
end
package.preload["luasnip.util.parser"] = function()
  return { parse_snippet = node }
end
"""


@unittest.skipUnless(shutil.which("nvim"), "Neovim is required for these tests")
class NeovimTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.config_home = self.root / "config"
        self.home = self.root / "home"
        self.env = dict(
            os.environ,
            HOME=str(self.home),
            XDG_CONFIG_HOME=str(self.config_home),
            XDG_DATA_HOME=str(self.root / "data"),
            XDG_STATE_HOME=str(self.root / "state"),
            XDG_CACHE_HOME=str(self.root / "cache"),
        )

    def tearDown(self):
        self.tmp.cleanup()

    def run_lua(self, body):
        script = self.root / "test.lua"
        script.write_text(
            textwrap.dedent(
                f"""\
                package.path = {json.dumps(str(LUA_ROOT / "?.lua"))} .. ";" .. package.path
                package.path = {json.dumps(str(LUA_ROOT / "?/init.lua"))} .. ";" .. package.path
                {body}
                vim.api.nvim_command("qa!")
                """
            )
        )
        result = subprocess.run(
            ["nvim", "--headless", "-u", "NONE", "-l", str(script)],
            env=self.env,
            capture_output=True,
            text=True,
            timeout=15,
        )
        if result.returncode:
            self.fail(f"Neovim script failed:\n{result.stdout}\n{result.stderr}")
        return result.stdout + result.stderr

    def test_fraction_unmatched_input_is_preserved(self):
        output = self.run_lua(
            r"""
            local fraction = require("snippets.tex.utils.fraction")
            local prefix, numerator = fraction.split("2+(x)")
            assert(prefix == "2+" and numerator == "(x)")
            assert(fraction.split("x)") == nil)
            print("fraction-ok")
            """
        )
        self.assertIn("fraction-ok", output)

    def test_subfig_condition_uses_tex_text_condition(self):
        output = self.run_lua(
            LUA_SNIPPET_STUBS
            + r"""
            vim.api.nvim_eval = function() return 0 end
            local snippets = require("snippets.tex.environments")
            local subfig
            for _, snippet in ipairs(snippets) do
              if snippet.args[1] and snippet.args[1].trig == "subfig" then
                subfig = snippet
                break
              end
            end
            assert(subfig and subfig.args[3] and subfig.args[3].condition)
            assert(subfig.args[3].condition("subfig", "subfig", {}))
            vim.api.nvim_eval = function() return 1 end
            assert(not subfig.args[3].condition("subfig", "subfig", {}))
            print("subfig-ok")
            """
        )

        self.assertIn("subfig-ok", output)

    def test_theme_fallback_and_reload_are_idempotent(self):
        output = self.run_lua(
            r"""
            local theme = require("config.theme")
            local spec = theme.spec()
            local lazyvim = spec[2]
            assert(lazyvim and lazyvim.opts and type(lazyvim.opts.colorscheme) == "function")
            local calls = 0
            vim.cmd = {
              colorscheme = function() calls = calls + 1 end,
              source = function() end,
            }
            assert(lazyvim.opts.colorscheme())
            assert(theme.reload())
            assert(calls == 1)
            print("theme-ok")
            """
        )

        self.assertIn("theme-ok", output)

    def test_theme_same_colorscheme_change_reapplies(self):
        provider = self.config_home / "omarchy/current/theme/neovim.lua"
        provider.parent.mkdir(parents=True)
        provider.write_text(
            'return { { "catppuccin/nvim", name = "catppuccin", opts = { flavour = "base" } }, { "LazyVim/LazyVim", opts = { colorscheme = "catppuccin", variant = "base" } } }\n'
        )
        output = self.run_lua(
            r"""
            local theme = require("config.theme")
            local calls = 0
            vim.cmd = {
              colorscheme = function(name) calls = calls + 1; vim.g.colors_name = name end,
              source = function() end,
            }
            package.preload["catppuccin"] = function()
              return { setup = function(opts) vim.g.theme_flavour = opts.flavour end }
            end
            assert(theme.reload())
            assert(theme.reload())
            assert(calls == 1)
            assert(vim.g.theme_flavour == nil)
            local file = assert(io.open(theme.provider_path(), "w"))
            file:write('return { { "catppuccin/nvim", name = "catppuccin", opts = { flavour = "latte" } }, { "LazyVim/LazyVim", opts = { colorscheme = "catppuccin", variant = "night" } } }\n')
            file:close()
            assert(theme.reload())
            assert(calls == 2)
            assert(vim.g.theme_flavour == "latte")
            print("theme-change-ok")
            """
        )
        self.assertIn("theme-change-ok", output)

    def test_theme_provider_config_runs_before_reapply(self):
        provider = self.config_home / "omarchy/current/theme/neovim.lua"
        provider.parent.mkdir(parents=True)
        provider.write_text(
            'return { { "gthelding/monokai-pro.nvim", config = function() vim.g.theme_callback = (vim.g.theme_callback or 0) + 1 end }, { "LazyVim/LazyVim", opts = { colorscheme = "monokai-pro" } } }\n'
        )
        output = self.run_lua(
            r"""
            local theme = require("config.theme")
            local calls = 0
            vim.cmd = {
              colorscheme = function(name) calls = calls + 1; vim.g.colors_name = name end,
              source = function() end,
            }
            assert(theme.reload())
            assert(theme.reload())
            assert(calls == 1)
            assert((vim.g.theme_callback or 0) == 0)
            local file = assert(io.open(theme.provider_path(), "w"))
            file:write('return { { "gthelding/monokai-pro.nvim", config = function() vim.g.theme_callback = (vim.g.theme_callback or 0) + 1 end }, { "LazyVim/LazyVim", opts = { colorscheme = "monokai-pro", variant = "changed" } } }\n')
            file:close()
            assert(theme.reload())
            assert(calls == 2)
            assert(vim.g.theme_callback == 1)
            print("theme-config-ok")
            """
        )
        self.assertIn("theme-config-ok", output)

    def test_malformed_theme_provider_falls_back(self):
        provider = self.config_home / "omarchy/current/theme/neovim.lua"
        provider.parent.mkdir(parents=True)
        provider.write_text("return { { 'not-a-valid-spec' } }\n")
        output = self.run_lua(
            r"""
            local theme = require("config.theme")
            assert(theme.colorscheme(theme.load()) == "tokyonight-night")
            print("fallback-ok")
            """
        )
        self.assertIn("fallback-ok", output)

    def test_optional_tabpilot_absence_does_not_break_setup(self):
        output = self.run_lua(
            f"""
            vim.env.TABPILOT_NVIM_DIR = ""
            local specs = dofile({json.dumps(str(TABPILOT_PLUGIN))})
            assert(next(specs) == nil)
            print("tabpilot-optional-ok")
            """
        )
        self.assertIn("tabpilot-optional-ok", output)

    def test_tex_entrypoint_loads_all_snippet_modules(self):
        output = self.run_lua(
            LUA_SNIPPET_STUBS
            + r"""
            vim.api.nvim_eval = function() return 0 end
            local snippets = require("snippets.tex")
            local seen = {}
            for _, snippet in ipairs(snippets) do
              local spec = snippet.args[1]
              if type(spec) == "table" and type(spec.trig) == "string" then
                seen[spec.trig] = true
              end
            end
            assert(seen.mk and seen.subfig and seen.alab)
            print("tex-entry-ok")
            """
        )
        self.assertIn("tex-entry-ok", output)


if __name__ == "__main__":
    unittest.main()
