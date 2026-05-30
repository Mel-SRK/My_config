#!/usr/bin/env bash
# niri-auto-edp.sh — 外接显示器时自动关闭笔记本内屏，断开时恢复
# 用法: niri-auto-edp.sh [内屏名称]
#   内屏名称默认 eDP-1，可通过参数或环境变量 INTERNAL_OUTPUT 覆盖
#
# 原理: udevadm monitor 监听 DRM HOTPLUG 事件 → 查询 niri 输出状态 → 自动开关内屏
# 运行: systemctl --user enable --now niri-auto-edp.service

set -euo pipefail

INTERNAL="${1:-${INTERNAL_OUTPUT:-eDP-1}}"
COOLDOWN=2  # 防抖：秒数内不重复切换

log() {
    echo "[$(date '+%H:%M:%S')] $*"
    systemd-cat -t "niri-auto-edp" echo "$*" 2>/dev/null || true
}

# 检查 niri 是否在运行
if ! niri msg version &>/dev/null; then
    log "ERROR: niri IPC 不可用，退出"
    exit 1
fi

last_toggle=0

# 一次 niri msg 调用同时获取外接显示器数量和内屏状态
toggle_internal() {
    local now
    now=$(date +%s)
    if (( now - last_toggle < COOLDOWN )); then
        return
    fi

    local result
    result=$(niri msg -j outputs 2>/dev/null | jq --arg internal "$INTERNAL" -r '
        (to_entries | map(select(.key != $internal and .value.logical != null)) | length) as $ext |
        (.[$internal].logical != null) as $int_on |
        "\($ext) \($int_on)"
    ') || return

    local ext_count int_on
    read -r ext_count int_on <<< "$result"

    last_toggle=$now

    if (( ext_count > 0 )) && [[ "$int_on" == "true" ]]; then
        log "检测到 ${ext_count} 个外接显示器，关闭内屏 ${INTERNAL}"
        niri msg output "$INTERNAL" off
    elif (( ext_count == 0 )) && [[ "$int_on" == "false" ]]; then
        log "无外接显示器，恢复内屏 ${INTERNAL}"
        niri msg output "$INTERNAL" on
    fi
}

log "启动，监控内屏: ${INTERNAL}"

# 启动时检查一次
toggle_internal

# 用 process substitution 避免管道子 shell 问题
while IFS= read -r line; do
    if [[ "$line" =~ HOTPLUG=1 ]]; then
        sleep 1.5  # 等 niri 完成输出枚举
        toggle_internal
    fi
done < <(udevadm monitor --subsystem-match=drm --property 2>/dev/null)
