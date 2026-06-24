vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt

-- Clipboard
opt.clipboard = "unnamedplus"
opt.completeopt = { "menu", "menuone", "noselect" }
opt.mouse = "a"

-- Tab / Indent
opt.tabstop = 2
opt.softtabstop = 2
opt.shiftwidth = 2
opt.expandtab = true

-- UI
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.splitbelow = true
opt.splitright = true
opt.termguicolors = true
opt.showmode = false
opt.scrolloff = 10
opt.signcolumn = "yes"
opt.laststatus = 3  -- global statusline

-- Search
opt.incsearch = true
opt.hlsearch = false
opt.ignorecase = true
opt.smartcase = true

-- LSP / File
opt.backup = false
opt.writebackup = false
opt.updatetime = 300
opt.undofile = true
opt.swapfile = false

-- Disable netrw (using nvim-tree)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Diagnostic display: hide warnings, show errors only (hints via K/float)
vim.diagnostic.config({
  virtual_text = { severity = { min = vim.diagnostic.severity.ERROR } },
  signs = { severity = { min = vim.diagnostic.severity.ERROR } },
  underline = { severity = { min = vim.diagnostic.severity.ERROR } },
  float = { severity = { min = vim.diagnostic.severity.HINT } },
})
