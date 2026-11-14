local augroup = vim.api.nvim_create_augroup("UserConfig", { clear = true })

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup,
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
  end,
})

-- Remove trailing whitespace on save
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup,
  pattern = "*",
  callback = function(ev)
    -- Markdown / reStructuredText 的行尾空格可能有语义；diff 也需逐字保留。
    local ft = vim.bo[ev.buf].filetype
    if ft == "markdown" or ft == "rst" or ft == "diff" or not vim.bo[ev.buf].modifiable then
      return
    end
    local view = vim.fn.winsaveview()
    vim.cmd([[silent keepjumps keeppatterns %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})
