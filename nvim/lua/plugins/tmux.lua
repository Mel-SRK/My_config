return {
  -- Seamless nvim <-> tmux navigation and integration
  {
    "aserowy/tmux.nvim",
    event = "VeryLazy",
    opts = {
      -- Ctrl-hjkl 在 nvim 窗口和 tmux pane 之间无缝切换
      navigation = {
        enable_default_keybindings = true,
      },
      -- Ctrl-方向键 调整大小（同时适配 nvim 和 tmux）
      resize = {
        enable_default_keybindings = true,
      },
      -- 剪贴板同步
      copy_sync = {
        enable = true,
      },
    },
  },
}
