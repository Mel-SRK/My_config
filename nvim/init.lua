--加载文件
require('options') 
require('keymaps') 
require('plugins') 
require('treesitter') 
require('coc') 
require('lualine').setup()
require('colors')
require('tree')

--配置

--bufferline
vim.opt.termguicolors = true
require("bufferline").setup{
    options = {
        mode = "buffer",
        -- 显示id
        number = "ordinal"
    }
}

