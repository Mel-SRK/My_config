# My_config

# 预览

![预览图片.png](./预览图片.png)

# 安装

```shell
yay -S tmux neovim neovim-tree-lua-git niri alacritty fuzzel swaylock swayidle swaybg xwayland-satellite gdm noctalia-shell app2unit python-pynvim python-flake8 python-pylint python-isort//mako作为通知管理与noctalia shell功能重叠
非必要包(曾经使用的，现在无需理会)：mako nwg-clipman waybar
git clone https://github.com/Mel-SRK/My_config
cd ./My_config
git clone --depth 1 https://github.com/wbthomason/packer.nvim\
 ~/.local/share/nvim/site/pack/packer/start/packer.nvim
cp -r ./* ~/.config
cd ~/.config/nvim
nvim ./lua/plugins.lua
:w
:wq
cd ~/.config/coc/extensions
npm install coc-pyright --save
ln -s ~/.config/tmux/.tmux.conf ~/.tmux.conf
ln -s ~/.config/tmux/.tmux.conf.local ~/.tmux.conf.local
```

如想实现再次打开终端继续使用上次的shell,可将虚拟终端程序的启动shell改为`tmux a`(图片以kde的Konsole为例)
~~建议的sddm主题:[qylock](https://github.com/darkkal44/qylock)~~

建议的sddm主题:[noctalia-sddm-theme](https://github.com/mda-dev/noctalia-sddm-theme)（与noctalia-shell风格统一，支持颜色同步和壁纸同步）

![预览图片2.png](./预览图片2.png)

随后将`My_config/tmux/tmux.sh`加入开机自启(可自行搜索)

或者编辑`~/.bash_profile`或者`~/.zshrc`添加如下内容(推荐)

```shell
if [ -z "$TMUX" ]; then

    tmux attach -t default || tmux new -s default

fi
```

# 使用方式

## tmux

默认前置快捷键为：**Ctrl-x**

新建窗口：**Ctrl-x**+c

横向分割窗口：**Ctrl-x**+-

纵向分割窗口：**Ctrl-x**+—

默认开启鼠标支持，鼠标拖动选中文本后松开即可复制至系统剪切板

## nvim

提供了基于coc.nvim的Python自动补全（coc-pyright）及基于treesitter的语法高亮渲染

使用`t`打开目录树及回到目录树`T`打开或关闭目录树

会自动保存上次打开时光标位置

使用q和w快捷退出和保存

Python相关：
- 自动补全：输入时自动触发，Tab/Shift+Tab选择，Enter确认
- 语法检查：ALE + pylint（只在Normal模式下检查，延迟500ms）
- 代码格式化：手动执行`:Format`或`<leader>f`
- 自动格式化：默认禁用（如需启用，在coc-settings.json中设置`"coc.preferences.formatOnType": true`）

## Niri配置
Mod+T打开终端

~~Mod+B打开nwg-clipman(剪切板管理工具)~~

Mod+B打开noctalic-shell的剪切板管理工具

~~Mod+D启动fuzzel //主题配置参考https://draculatheme.com/fuzzel~~

Mod+D改为启动noctalic-shell的启动器

Ctrl+Alt+Right媒体播放下一首

Ctrl+Alt+Left媒体播放上一首

配置参考:https://kznleaf.top/2025/09/18/niri%E5%AE%89%E8%A3%85%E4%B8%8E%E9%85%8D%E7%BD%AE/;https://www.sakimidare.top/posts/niri-manual/等

## swayidle 自动锁屏配置

备份路径: `systemd/user/swayidle.service`

该文件是用户级 systemd service，用于在空闲时自动锁屏。使用 swayidle 监听空闲事件，锁屏命令为 noctalia-shell 的锁屏界面（而非 swaylock）。

恢复方式:

```shell
cp systemd/user/swayidle.service ~/.config/systemd/user/swayidle.service
systemctl --user daemon-reload
systemctl --user restart swayidle.service
```

逻辑:
- 600秒空闲 → 调用 noctalia-shell 锁屏
- 601秒 → 关闭显示器
- 睡眠前 → 调用 noctalia-shell 锁屏
