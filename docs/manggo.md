# Manggo：niri 下的中英翻译

本机使用本地打包的 Manggo 1.3.9，命令为小写的 `manggo`。截至 2026-11-25，AUR 的 `manggo` 仍是 1.2.2。仓库提供的 `PKGBUILD` 会下载官方 Linux x86_64 发布包并校验 SHA-256。 [Manggo 更新清单](https://manggo.pylogmon.cn/assets/update-linux-amd64.json) · [AUR 版本](https://aur.archlinux.org/rpc/v5/info/manggo)

## 安装与恢复

```sh
sudo pacman -S --needed base-devel xdg-desktop-portal xdg-desktop-portal-gtk \
    xdg-desktop-portal-gnome xdg-desktop-portal-wlr wl-clipboard libnotify \
    tesseract tesseract-data-chi_sim tesseract-data-eng
(cd packages/manggo && makepkg -si)
manggo --version
```

如果已有 `manggo-1.3.9-0.1-x86_64.pkg.tar.zst`，也可用 `sudo pacman -U` 安装这份包。

随后按仓库根目录的装机流程运行 `./install.sh --apply`。MANIFEST 包含 niri 快捷键、截图翻译脚本、Portal 路由和 Manggo 自启文件。

在 Manggo 内设置翻译服务和目标语言。本机使用简体中文为默认目标语言、英语为备用目标语言。应用设置和服务凭据由 Manggo 管理，恢复时在应用内配置。

## 退役 Crow Translate

翻译入口已统一为 Manggo，仓库的快捷键、包清单和自启配置均不再引用 Crow Translate。本机原有的 `~/.config/crow-translate` 已移出配置目录。软件包由用户手动卸载：

```sh
sudo pacman -Rns crow-translate
```

该命令由 pacman 一并处理不再需要的依赖。Manggo 和截图所需的 Portal 配置继续保留。

## 快捷键

`Super` 是 Win 键，niri 配置中写作 `Mod`。

| 按键 | 操作 | 处理方式 |
|---|---|---|
| `Super+A` | 选中文字后翻译 | 优先读取 Wayland 主选区，必要时交给 `selection-translation` |
| `Super+S` | 框选屏幕区域后翻译 | 冻结画面，使用本地 Tesseract 识别中英文字，再交给 Manggo |
| `Super+Shift+A` | 打开输入翻译窗口，输入或粘贴文字 | `input-translation` |

这些键由 niri 注册，通过 `manggo --action <动作>` 调用。Manggo 未运行时会自动启动，已运行时转发给现有实例。应用内无需重复注册热键。

截图翻译会优先使用 `~/.local/bin/still` 或 `PATH` 里的 `still`，并要求同时安装 `grim` 和 `slurp`。缺少这些工具时，脚本会使用 niri 自带的冻结选区。niri 会把截图放入剪贴板，按 Esc 后脚本最多等待 60 秒。两条路径都可通过 `OCR_LANG` 指定识别语言。 [still 项目](https://github.com/faergeek/still)

`Super+Shift+O` 通过 niri 截图，并把 Tesseract 识别结果复制到剪贴板。`Super+Shift+S` 用于截图标注。

## 登录自启

在 Manggo 内开启开机自启后，应用生成 `~/.config/autostart/com.pylogmon.Manggo.desktop`。niri 会话通过 `xdg-desktop-autostart.target` 加载它，systemd 生成 `app-com.pylogmon.Manggo@autostart.service`。

仓库保存了当前自启文件，并在 MANIFEST 中标记为 `state`：普通安装保留已有文件，缺失时初始化。之后在 Manggo 内开关自启，仍由应用管理该文件。

如需登录后只在托盘运行，在 Manggo 设置中关闭启动时打开设置窗口的选项。

自启配置在下次登录时加载，检查方法：

```sh
cat ~/.config/autostart/com.pylogmon.Manggo.desktop
systemctl --user is-active niri.service xdg-desktop-autostart.target
# 下次登录后检查实际的自启服务：
systemctl --user status app-com.pylogmon.Manggo@autostart.service
```

## 截图 Portal

配置文件是 [`xdg-desktop-portal/niri-portals.conf`](../xdg-desktop-portal/niri-portals.conf)，安装到 `~/.config/xdg-desktop-portal/niri-portals.conf`。

| 接口 | 后端 | 用途 |
|---|---|---|
| Screenshot | wlr | Manggo 等应用请求桌面截图 |
| ScreenCast | GNOME | niri 屏幕共享、录屏 |
| Access | GTK | 桌面访问授权对话框 |
| Notification | GTK | 桌面通知 |

原配置把 Screenshot 和 Access 交给 GNOME，当前 niri 会话因此出现 `Unknown method 'InteractiveScreenshot'`、`Failed to show access dialog`，Manggo 提示“桌面拒绝了截图请求，或截图失败”。修复后 Screenshot 使用 wlr、Access 使用 GTK，屏幕共享仍使用 GNOME。

修改路由后，在当前桌面会话执行：

```sh
systemctl --user restart xdg-desktop-portal.service
```

可以从 Manggo 界面发起一次截图来检查 Portal。`Super+S` 使用上文的本地截图链路。查看 Portal 错误日志：

```sh
journalctl --user -b -u xdg-desktop-portal.service \
    -u xdg-desktop-portal-wlr.service -u xdg-desktop-portal-gtk.service
```

翻译结果取决于应用内配置的翻译服务。
