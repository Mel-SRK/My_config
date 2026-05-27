-- ALE配置 - 只用于语法检查，不用于LSP
vim.g.ale_linters = {
    python = {'pylint'},
}

vim.g.ale_python_flake8_options = '--ignore=F403,F401,E501'

vim.g.ale_fixers = {
    python = {'black', 'isort'},
}

vim.g.ale_sign_error = '✖'
vim.g.ale_sign_warning = '⚠'
vim.g.ale_sign_info = 'ℹ'

vim.g.ale_python_flake8_executable = 'flake8'
vim.g.ale_python_pylint_executable = 'pylint'

-- 禁用ALE的LSP功能，使用coc.nvim的LSP
vim.g.ale_disable_lsp = 1

-- 禁用保存时自动修复
vim.g.ale_fix_on_save = 0

-- 优化延迟
vim.g.ale_lint_delay = 500
vim.g.ale_lint_on_text_changed = 'normal'
vim.g.ale_lint_on_insert_leave = 1

-- 显示行号
vim.g.ale_set_signs = 1
vim.g.ale_set_highlights = 1

-- 键盘映射
vim.keymap.set('n', '<leader>af', ':ALEFix<CR>', {noremap = true, silent = true})
vim.keymap.set('n', '<leader>al', ':ALELint<CR>', {noremap = true, silent = true})
vim.keymap.set('n', '[a', ':ALEPrevious<CR>', {noremap = true, silent = true})
vim.keymap.set('n', ']a', ':ALENext<CR>', {noremap = true, silent = true})
