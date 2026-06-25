local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Window navigation
map("n", "<C-h>", "<C-w>h", opts)
map("n", "<C-j>", "<C-w>j", opts)
map("n", "<C-k>", "<C-w>k", opts)
map("n", "<C-l>", "<C-w>l", opts)

-- Window resize
map("n", "<C-Up>", ":resize -2<CR>", opts)
map("n", "<C-Down>", ":resize +2<CR>", opts)
map("n", "<C-Left>", ":vertical resize -2<CR>", opts)
map("n", "<C-Right>", ":vertical resize +2<CR>", opts)

-- Visual indent
map("v", "<", "<gv", opts)
map("v", ">", ">gv", opts)

-- Move lines in visual mode
map("v", "J", ":m '>+1<CR>gv=gv", opts)
map("v", "K", ":m '<-2<CR>gv=gv", opts)

-- Buffer navigation (1-9 jump)
for i = 1, 9 do
  map("n", tostring(i), ":BufferLineGoToBuffer " .. i .. "<CR>", opts)
end
map("n", "gt", ":BufferLineCycleNext<CR>", opts)
map("n", "gT", ":BufferLineCyclePrev<CR>", opts)

-- Quick save / quit
map("n", "w", ":w<CR>", opts)
map("n", "q", ":q<CR>", opts)

-- Comment (Ctrl+/)
map("n", "<C-_>", "gcc", { remap = true, silent = true })
map("v", "<C-_>", "gc", { remap = true, silent = true })

-- Nvim-tree: t 切换打开/关闭
map("n", "t", ":NvimTreeToggle<CR>", opts)

-- fzf-lua
map("n", "<leader>ff", ":FzfLua files<CR>", opts)
map("n", "<leader>fs", ":FzfLua live_grep<CR>", opts)
map("n", "<leader>fb", ":FzfLua buffers<CR>", opts)
map("n", "<leader>fh", ":FzfLua oldfiles<CR>", opts)
map("n", "<leader>fg", ":FzfLua git_status<CR>", opts)
map("n", "<leader>fc", ":FzfLua git_commits<CR>", opts)

-- Format (conform.nvim)
map("n", "<leader>af", function() require("conform").format({ async = true }) end, opts)

-- Gitsigns
map("n", "gn", ":Gitsigns next_hunk<CR>", opts)
map("n", "gp", ":Gitsigns prev_hunk<CR>", opts)
map("n", "<leader>gb", ":Gitsigns blame_line<CR>", opts)
map("n", "<leader>gp", ":Gitsigns preview_hunk<CR>", opts)
map("n", "<leader>gr", ":Gitsigns reset_hunk<CR>", opts)

-- Markdown preview
map("n", "<leader>mp", ":MarkdownPreview<CR>", opts)

-- Clear search highlight
map("n", "<Esc>", ":nohlsearch<CR>", opts)

-- Snippet jump (Ctrl+l / Ctrl+h)
map({ "i", "s" }, "<C-l>", function()
  local luasnip = require("luasnip")
  if luasnip.expand_or_jumpable() then
    luasnip.expand_or_jump()
  end
end, { silent = true })
map({ "i", "s" }, "<C-h>", function()
  local luasnip = require("luasnip")
  if luasnip.jumpable(-1) then
    luasnip.jump(-1)
  end
end, { silent = true })
