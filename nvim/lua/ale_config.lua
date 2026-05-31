-- ALE配置 - 只用于格式化修复（:ALEFix），不做 lint（诊断交给 coc.nvim）
vim.g.ale_linters = {}

vim.g.ale_fixers = {
    python = {'black', 'isort'},
}

-- 禁用ALE的LSP功能
vim.g.ale_disable_lsp = 1

-- 禁用保存时自动修复
vim.g.ale_fix_on_save = 0

-- 关闭所有 lint 触发（诊断由 coc.nvim 处理）
vim.g.ale_lint_on_text_changed = 'never'
vim.g.ale_lint_on_insert_leave = 0
vim.g.ale_lint_on_save = 0
vim.g.ale_lint_on_enter = 0

-- 关闭 ALE 的 sign 和高亮（避免和 coc.nvim 重复）
vim.g.ale_set_signs = 0
vim.g.ale_set_highlights = 0
vim.g.ale_set_loclist = 0
vim.g.ale_set_quickfix = 0

-- 键盘映射（只保留格式化）
vim.keymap.set('n', '<leader>af', ':ALEFix<CR>', {noremap = true, silent = true})
