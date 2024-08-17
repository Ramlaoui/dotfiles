return {
	"nvim-orgmode/orgmode",
	-- For org-roam: https://github.com/chipsenkbeil/org-roam.nvim
	event = "VeryLazy",
	ft = { "org" },
	config = function()
		-- Setup orgmode
		require("orgmode").setup({
			org_agenda_files = "~/org/**/*",
			org_default_notes_file = "~/org/refile.org",
			org_capture_templates = {
				-- General Task capture for inbox
				t = {
					description = "Task",
					template = "* TODO %?\n  %u\n  %a", -- Capture task with timestamp and context
					target = "~/org/refile.org",
				},

				-- PhD Task capture
				p = {
					description = "PhD Task",
					template = "* TODO %?\n  DEADLINE: %^{Deadline}T\n  Added: %u\n  %a",
					target = "~/org/phd.org",
					headline = "PhD Tasks",
				},

				-- Development Notes capture
				d = {
					description = "Development Note",
					template = "* %^{Project Name}\n  Created: %U\n  %? \nLinks: %^{References}",
					target = "~/org/dev.org",
					headline = "Quick Capture",
				},

				-- Machine Learning Concepts capture
				m = {
					description = "ML Concept",
					template = "* %^{Concept Name}\n  Date: %u\n  Summary: %?\n Links: %^{References}",
					target = "~/org/ml.org",
					headline = "Quick Capture",
				},

				-- Scientific Notes capture
				s = {
					description = "Scientific Note",
					template = "* %^{Concept or Discovery}\n  Date: %U\n  Details: %?\n  Links: %^{References}",
					target = "~/org/science.org",
					headline = "Quick Capture",
				},

				-- Calendar Event or Deadline capture for calendar.org
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
		-- https://github.com/nvim-orgmode/orgmode/blob/master/DOCS.md#org_capture_templates

		-- NOTE: If you are using nvim-treesitter with ~ensure_installed = "all"~ option
		-- add ~org~ to ignore_install
		-- require('nvim-treesitter.configs').setup({
		--   ensure_installed = 'all',
		--   ignore_install = { 'org' },
		-- })
	end,
}
