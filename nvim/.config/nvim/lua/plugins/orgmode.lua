return {
  {
    "nvim-orgmode/orgmode",
    ft = { "org" },
    config = function()
      require("orgmode").setup({
        org_agenda_files = "~/org/**/*",
        org_default_notes_file = "~/org/refile.org",
        mappings = {},
        org_capture_templates = {
          t = {
            description = "Task",
            template = "* TODO %?\n  %u\n  %a",
            target = "~/org/refile.org",
          },
          p = {
            description = "PhD Task",
            template = "* TODO %?\n  DEADLINE: %^{Deadline}T\n  Added: %u\n  %a",
            target = "~/org/phd.org",
            headline = "PhD Tasks",
          },
          d = {
            description = "Development Note",
            template = "* %^{Project Name}\n  Created: %U\n  %? \nLinks: %^{References}",
            target = "~/org/dev.org",
            headline = "Quick Capture",
          },
          m = {
            description = "ML Concept",
            template = "* %^{Concept Name}\n  Date: %u\n  Summary: %?\n Links: %^{References}",
            target = "~/org/ml.org",
            headline = "Quick Capture",
          },
          s = {
            description = "Scientific Note",
            template = "* %^{Concept or Discovery}\n  Date: %U\n  Details: %?\n  Links: %^{References}",
            target = "~/org/science.org",
            headline = "Quick Capture",
          },
          c = {
            description = "Calendar Event or Deadline",
            template = "* %^{Event Title}\n  SCHEDULED: %^{Event Date}T\n  %?\n  Notes: %^{Additional notes}",
            target = "~/Org/calendar.org",
            headline = "Deadlines",
          },
          j = {
            description = "Social Entry",
            template = "\n*** %<%Y-%m-%d> %<%A>\n**** %U\n\n%?",
            target = "~/org/social.org",
          },
        },
      })

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "org",
        callback = function(ev)
          vim.keymap.set("i", "<S-CR>", function()
            require("orgmode").action("org_mappings.meta_return")
          end, { buffer = ev.buf, silent = true, desc = "Org meta return" })
        end,
      })
    end,
  },
  {
    "akinsho/org-bullets.nvim",
    ft = { "org" },
    config = function()
      require("org-bullets").setup()
    end,
  },
  {
    "lukas-reineke/headlines.nvim",
    ft = { "markdown", "org" },
    dependencies = "nvim-treesitter/nvim-treesitter",
    config = function()
      require("headlines").setup()
    end,
  },
}

