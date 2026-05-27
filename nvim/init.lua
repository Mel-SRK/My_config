--加载文件
require('options') 
require('keymaps') 
require('plugins') 
require('treesitter') 
require('coc') 
require('lualine').setup()
require('colors')
require('tree')
--require('lsp')

--配置
require'nvim-lastplace'.setup{}
-- 使用coc.nvim，禁用mason-lspconfig避免冲突
-- require("mason").setup()
-- require('lsp/setup')
require('ale_config')
--bufferline
vim.opt.termguicolors = true
require("bufferline").setup{
    options = {
        mode = "buffer",
        -- 显示id
        number = "ordinal"
    }
}

