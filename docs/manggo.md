# Manggo：niri 下的中英翻译

当前使用 AUR `manggo`，程序名是大小写敏感的 `Manggo`。2026-11-17 核验版本为 1.2.2-2。

## 安装与恢复

```sh
sudo pacman -S --needed xdg-desktop-portal xdg-desktop-portal-gtk \
    xdg-desktop-portal-gnome xdg-desktop-portal-wlr
yay -S manggo
```

随后按仓库根目录的装机流程运行 `./install.sh --apply`。MANIFEST 包含 niri 快捷键、Portal 路由和 Manggo 自启文件。

翻译服务、OCR 服务和语言偏好在 Manggo 内设置。日常使用简体中文为默认目标语言、英语为备用目标语言。完整的 `~/.config/Manggo/Manggo.conf` 包含应用及服务配置，由应用管理，不整体覆盖或收录到仓库。

## 退役 Crow Translate

翻译入口已统一为 Manggo，仓库的快捷键、包清单和自启配置均不再引用 Crow Translate。本机原有的 `~/.config/crow-translate` 已移出配置目录。软件包由用户手动卸载：

```sh
sudo pacman -Rns crow-translate
```

该命令由 pacman 一并处理不再需要的依赖。Manggo 和截图所需的 Portal 配置继续保留。

## 快捷键

`Super` 是 Win 键，niri 配置中写作 `Mod`。

| 按键 | 操作 | Manggo 动作 |
|---|---|---|
| `Super+A` | 选中文字后翻译 | `selection-translation` |
| `Super+S` | 框选屏幕区域后翻译 | `screenshot-translation` |
| `Super+Shift+A` | 打开输入翻译窗口，输入或粘贴文字 | `input-translation` |

这些键由 niri 注册，通过 `Manggo --action <动作>` 调用；Manggo 未运行时会自动启动，已运行时转发给现有实例。应用内无需重复注册这些快捷键。`Manggo --list-actions` 可查看安装版本实际支持的动作。

原有的 `Super+Shift+O` 继续通过 niri 截图和本地 Tesseract 识别中英文字，结果复制到剪贴板；`Super+Shift+S` 继续用于截图标注。

## 登录自启

在 Manggo 内开启开机自启后，应用生成 `~/.config/autostart/Manggo.desktop`。niri 会话通过 `xdg-desktop-autostart.target` 加载它，systemd 生成 `app-Manggo@autostart.service`。这是登录桌面时启动，无需再添加 `spawn-at-startup "Manggo"`。

仓库保存了当前自启文件，并在 MANIFEST 中标记为 `state`：普通安装保留已有文件，缺失时初始化。之后在 Manggo 内开关自启，仍由应用管理该文件。

如需登录后只在托盘运行，关闭 Manggo 的“启动时打开设置”。本机核验时，该设置对应 `[startup]` 下的 `openSettings=false`。

自启配置在下次登录时加载，检查方法：

```sh
cat ~/.config/autostart/Manggo.desktop
systemctl --user is-active niri.service xdg-desktop-autostart.target
# 下次登录后检查实际的自启服务：
systemctl --user status app-Manggo@autostart.service
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

可用 `Manggo --action capture-area` 检查选区截图是否打开，按 Esc 取消。查看错误日志：

```sh
journalctl --user -b -u xdg-desktop-portal.service \
    -u xdg-desktop-portal-wlr.service -u xdg-desktop-portal-gtk.service
```

2026-11-17 已验证 wlr 后端实际返回成功并生成 2560×1440 截图，测试图片随即删除；Manggo 的“选区截图”窗口也能正常打开并关闭。翻译结果仍取决于应用内配置的翻译服务。
