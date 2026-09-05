return {
  {
    "lervag/vimtex",
    ft = { "tex", "plaintex", "context" },
    init = function()
      vim.g.vimtex_view_method = "sioyek"
      vim.g.vimtex_quickfix_mode = 0
      vim.g.tex_flavor = "latex"
      vim.g.vimtex_mappings_enabled = 1
      vim.g.vimtex_context_pdf_viewer = "sioyek"
    end,
    config = function()
      local default_compiler_options = {
        "-verbose",
        "-file-line-error",
        "-synctex=1",
        "-interaction=nonstopmode",
        "-shell-escape",
      }
      local lualatex_compiler_options = {
        "-verbose",
        "-pdflatex=lualatex",
        "-file-line-error",
        "-synctex=1",
        "-interaction=nonstopmode",
        "-shell-escape",
      }

      local function figures_dir(bufnr)
        local vimtex = vim.b[bufnr].vimtex
        if type(vimtex) ~= "table" or type(vimtex.root) ~= "string" or vimtex.root == "" then
          vim.notify("VimTeX project root is unavailable", vim.log.levels.ERROR)
          return nil
        end
        return vim.fs.joinpath(vimtex.root, "figures")
      end

      local function create_figure(bufnr)
        vim.cmd.stopinsert()
        local directory = figures_dir(bufnr)
        if not directory then
          return
        end
        local output = vim.fn.system({
          "inkscape-figures",
          "create",
          vim.api.nvim_get_current_line(),
          directory,
        })
        if vim.v.shell_error ~= 0 then
          vim.notify(output, vim.log.levels.ERROR)
          return
        end
        vim.cmd.write()
      end

      local function edit_figures(bufnr)
        local directory = figures_dir(bufnr)
        if not directory then
          return
        end
        local job = vim.fn.jobstart({ "inkscape-figures", "edit", directory }, { detach = true })
        if job <= 0 then
          vim.notify("Failed to launch inkscape-figures", vim.log.levels.ERROR)
        end
      end

      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "tex", "plaintex", "context" },
        callback = function(ev)
          local bufnr = ev.buf

          vim.keymap.set("n", "<localleader>lcd", function()
            vim.g.vimtex_compiler_latexmk = { options = default_compiler_options }
            vim.cmd("VimtexCompile")
          end, { buffer = bufnr, silent = true, desc = "Vimtex compile (pdflatex)" })

          vim.keymap.set("n", "<localleader>lcl", function()
            vim.g.vimtex_compiler_latexmk = { options = lualatex_compiler_options }
            vim.cmd("VimtexCompile")
          end, { buffer = bufnr, silent = true, desc = "Vimtex compile (lualatex)" })

          if vim.fn.executable("inkscape-figures") == 1 then
            vim.keymap.set("i", "<C-f>", function()
              create_figure(bufnr)
            end, { buffer = bufnr, silent = true, desc = "Inkscape figure create" })

            vim.keymap.set("n", "<C-f>", function()
              edit_figures(bufnr)
            end, { buffer = bufnr, silent = true, desc = "Inkscape figure edit" })
          end
        end,
      })
    end,
  },
}

