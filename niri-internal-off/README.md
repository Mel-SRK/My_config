# niri-internal-off（已退役，2026-10-03）

**用途**：常驻守护进程，外接 `DP-1` 接入时用 niri IPC 熄灭内屏 `eDP-1`，拔掉后恢复，顺带把 `DP-1` 钉在 `2560x1440@200`。`niri-internal-off.service` 随图形会话启动。

**退役原因**：职责与 `kanshi/` 的 `docked` / `mobile` profile 完全重叠，实测数据（2026-10-03 核对）：

| 场景 | 实际由谁完成 |
|---|---|
| 插线（外接接入 → 熄内屏） | 两边都下发同一条命令；kanshi 事件驱动先到，本脚本是重复动作 |
| 拔线（恢复内屏） | 全部是 kanshi（09-22 之后 kanshi 应用 `mobile` 19 次，本脚本一次没点亮过内屏） |
| 登录瞬间 | 两边都做；内屏闪烁时长差异在毫秒级，不可观测 |
| 空闲熄屏后的唤醒 | 无需任何一方介入 |
| 手动执行 `niri msg output eDP-1 on` | 只有本脚本会做（2 秒内收回），kanshi 不管 |

代价与风险：

- 单核 0.6% 持续 CPU（每 2 秒 fork 一次 `niri msg`，约 4.3 万次/天），9.5MB 内存；kanshi 32 分钟累计 7.1ms CPU、643KB
- `DP-1` 物理连着但输出被关掉时，本脚本会把内屏一起熄掉 → 两个输出同时 Disabled，桌面无输出（已实测复现）
- 2026-09-23 起它一共动作 11 次，全部是登录瞬间随服务启动那一次，**运行中零补救**

kanshi 单线失败时的降级形态是可用的：niri 的 config 里两块输出都写着 `enable`，kanshi 不在时会内外屏同时亮，不是黑屏。

**脚本本体保留**，可当手动诊断工具：

```shell
~/.local/bin/niri-internal-off.py --status                      # 连接态 + niri 实际状态 + 目标模式
~/.local/bin/niri-internal-off.py --once --dry-run              # 只说要做什么
~/.local/bin/niri-internal-off.py --once --assume-external=no   # 演练"拔线恢复"分支
```

**恢复方式**（仅当 kanshi 日后失效）：

```shell
cp niri-internal-off/niri-internal-off.py ~/.local/bin/
cp niri-internal-off/niri-internal-off.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now niri-internal-off.service
```

原运行日志留档在 `~/.local/state/niri-internal-off.log`（09-11 起）。
