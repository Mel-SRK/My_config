return {
  -- Git signs in gutter
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "│" },
        change = { text = "│" },
        delete = { text = "_" },
        topdelete = { text = "‾" },
        changedelete = { text = "~" },
      },
      current_line_blame = false,
      current_line_blame_opts = {
        delay = 500,
      },
    },
  },

  -- Inline git blame
  {
    "f-person/git-blame.nvim",
    opts = {
      enabled = false,  -- off by default, toggle with :GitBlameToggle
      date_format = "%Y-%m-%d",
    },
  },
}
