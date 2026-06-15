-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Load core settings FIRST (before plugins)
require("core.options")
require("core.keymaps")
require("core.autocmd")

-- Load plugins (lazy.nvim will handle setup)
require("lazy").setup("plugins", {
  change_detection = { notify = false },
})

-- Colorscheme (must be after lazy loads plugins)
vim.cmd.colorscheme("kanagawa-dragon")
