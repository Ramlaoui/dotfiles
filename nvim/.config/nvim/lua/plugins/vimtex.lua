return {
  {
    "lervag/vimtex",
    ft = { "tex" },
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

      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "tex", "plaintex", "latex" },
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
            vim.keymap.set(
              "i",
              "<C-f>",
              "<Esc>:silent exec '.!inkscape-figures create \"'.getline('.').'\" \"'.b:vimtex.root.'/figures/\"'<CR><CR>:w<CR>",
              { buffer = bufnr, noremap = true, silent = true, desc = "Inkscape figure create" }
            )

            vim.keymap.set(
              "n",
              "<C-f>",
              ":silent exec '!inkscape-figures edit \"'.b:vimtex.root.'/figures/\" > /dev/null 2>&1 &'<CR><CR>:redraw!<CR>",
              { buffer = bufnr, noremap = true, silent = true, desc = "Inkscape figure edit" }
            )
          end
        end,
      })
    end,
  },
}

