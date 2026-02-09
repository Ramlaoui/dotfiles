return {
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      {
        "nvim-telescope/telescope-bibtex.nvim",
        config = function()
          require("telescope").load_extension("bibtex")
        end,
      },
    },
    opts = function(_, opts)
      opts.extensions = opts.extensions or {}
      opts.extensions.bibtex = opts.extensions.bibtex or {}

      local icloud_bib = vim.fn.expand(
        "~/Library/Mobile Documents/com~apple~CloudDocs/zotero/bibs/references.bib"
      )

      opts.extensions.bibtex = vim.tbl_deep_extend("force", opts.extensions.bibtex, {
        depth = 1,
        custom_formats = {
          {
            id = "zettel",
            cite_marker = "#%s",
          },
        },
        format = "zettel",
        citation_max_auth = 2,
        context = false,
        context_fallback = true,
        wrap = false,
        global_files = vim.loop.fs_stat(icloud_bib) and { icloud_bib } or {},
      })
    end,
  },
}

