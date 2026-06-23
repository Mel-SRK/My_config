return {
  -- File explorer
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      sort = { sorter = "case_sensitive" },
      view = {
        side = "left",
        width = 30,
        number = false,
        relativenumber = false,
        signcolumn = "yes",
      },
      renderer = { group_empty = true },
      filters = {
        dotfiles = true,
        custom = { "node_modules" },
      },
      git = { enable = true },
    },
  },
}
