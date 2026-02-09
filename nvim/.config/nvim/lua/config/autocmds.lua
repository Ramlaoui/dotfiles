-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here with `vim.api.nvim_create_autocmd`.

-- Don't auto-insert comment leader on new lines.
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    vim.opt.formatoptions:remove({ "c", "r", "o" })
  end,
  desc = "Disable new line comment",
})

-- Wrap for prose-ish filetypes.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "org", "tex", "text", "rst" },
  callback = function(ev)
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.spell = false

    -- Markdown preview toggle (only if the command exists).
    if vim.bo[ev.buf].filetype == "markdown" and vim.fn.exists(":MarkdownPreviewToggle") == 2 then
      vim.keymap.set("n", "<leader>lm", "<cmd>MarkdownPreviewToggle<CR>", { buffer = ev.buf, desc = "Markdown preview" })
    end
  end,
})

