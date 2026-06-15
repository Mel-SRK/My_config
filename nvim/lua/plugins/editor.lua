return {
  -- Syntax highlighting (new API for nvim 0.12+)
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").setup({})

      local parsers = {
        "bash", "c", "cpp", "go", "gomod", "html", "css", "javascript",
        "typescript", "vue", "json", "lua", "python", "rust", "toml",
        "yaml", "markdown", "markdown_inline", "vim", "vimdoc", "query",
        "gitignore", "comment", "make",
      }
      for _, lang in ipairs(parsers) do
        if not vim.list_contains(require("nvim-treesitter").get_installed(), lang) then
          require("nvim-treesitter").install(lang)
        end
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("TreesitterHighlight", { clear = true }),
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
        end,
      })
    end,
  },

  -- Auto-close brackets
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {},
  },

  -- Comments
  {
    "numToStr/Comment.nvim",
    opts = {},
    lazy = false,
  },

  -- Restore cursor position
  { "ethanholz/nvim-lastplace", opts = {} },

  -- Highlight all occurrences of word under cursor
  {
    "RRethy/vim-illuminate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("illuminate").configure({
        delay = 100,
        filetypes_denylist = {
          "NvimTree", "Trouble", "TelescopePrompt", "fzf",
        },
      })
    end,
  },

  -- Markdown preview in browser
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
    ft = { "markdown" },
    build = "cd app && npm install",
    init = function()
      vim.g.mkdp_filetypes = { "markdown" }
      vim.g.mkdp_auto_start = 0
      vim.g.mkdp_auto_close = 1
      vim.g.mkdp_refresh_slow = 0
      vim.g.mkdp_browser = ""  -- 使用系统默认浏览器
    end,
  },
}
