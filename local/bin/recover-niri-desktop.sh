#!/usr/bin/env bash
# 黑屏自救：清掉孤儿 niri，用当前 tty 会话重新拉起。不需要 root。
#
# 典型链：SDDM 登录后内核 VT_WAITACTIVE 卡满 30s → 会话被判死，但
# niri.service 在 user manager 里还活着（孤儿，DRM Permission denied）
# → 再登录被 niri-session「already running」守卫挡掉 → 全黑。
#
# 旧版看见 niri 在跑就 no-op，正好踩这个坑。自救 = 先停再起。
# 用法：Ctrl+C 三次清行，确认不在 tmux 里，然后:
#     recover-niri-desktop.sh

set -uo pipefail

if [[ -n "${TMUX:-}" ]]; then
    echo "当前在 tmux 里。命令会进会话而不是干净壳；先 Ctrl+C 或 tmux detach 再跑。" >&2
fi

me=$(id -un)
rawtty=$(tty 2>/dev/null || true)
if [[ "$rawtty" == /dev/* ]]; then
    mytty=${rawtty#/dev/}
else
    mytty=""
fi

# 优先：本机真实 VT（tty2/tty3）> Type=tty 的 getty 登录 > 第一个 user 会话
# pts / 「不是一个 tty」时不能拿第一行，那经常是已死的图形会话
sid=""; tty=""
fallback=""
while read -r s uid user seat leader class t rest; do
    [[ "$user" == "$me" && "$class" == "user" ]] || continue
    type=$(loginctl show-session "$s" -p Type --value 2>/dev/null || true)
    if [[ -n "$mytty" && "$t" == "$mytty" ]]; then
        sid=$s; tty=$t
        break
    fi
    if [[ -z "$sid" && "$type" == "tty" ]]; then
        sid=$s; tty=$t
        continue
    fi
    if [[ -z "$fallback" ]]; then
        fallback="$s $t"
    fi
done < <(loginctl list-sessions --no-legend 2>/dev/null)

if [[ -z "$sid" && -n "$fallback" ]]; then
    sid=${fallback%% *}
    tty=${fallback#* }
fi

if [[ -z "$sid" ]]; then
    echo "找不到你的 user 会话（loginctl list-sessions 里没有 CLASS=user 的行）" >&2
    loginctl list-sessions >&2 || true
    echo "先确认已经在某个 tty（Ctrl+Alt+F3）上登录成功" >&2
    exit 1
fi

vt=$(loginctl show-session "$sid" -p VTNr --value 2>/dev/null)
vt=${vt:-0}
active=$(loginctl show-session "$sid" -p Active --value 2>/dev/null)
echo "当前会话: id=$sid tty=$tty vt=$vt Active=$active"

# 1) 先停。niri 不在会话 cgroup 里，会话死后它还活着。
if systemctl --user is-active --quiet niri.service; then
    echo "停掉正在跑的 niri.service（多半是孤儿）..."
    systemctl --user stop niri.service || true
fi

# 2) 清掉指向死会话的环境，再写成当前 tty 会话。
systemctl --user unset-environment DISPLAY WAYLAND_DISPLAY NIRI_SOCKET \
    XDG_SESSION_PATH XDG_SEAT_PATH XDG_SESSION_TYPE XDG_CURRENT_DESKTOP \
    XDG_SESSION_ID XDG_VTNR >/dev/null 2>&1

systemctl --user set-environment \
    XDG_SESSION_ID="$sid" XDG_VTNR="$vt" \
    XDG_SESSION_TYPE=wayland XDG_SESSION_CLASS=user \
    XDG_CURRENT_DESKTOP=niri XDG_SESSION_DESKTOP=niri >/dev/null 2>&1

systemctl --user reset-failed >/dev/null 2>&1

echo "启动 niri.service ..."
if ! timeout 60 systemctl --user start niri.service; then
    echo "niri.service 启动失败或超时" >&2
    systemctl --user --no-pager --lines=15 status niri.service >&2 || true
    exit 1
fi

sleep 1
uid=$(id -u)
sock=$(ls /run/user/"$uid"/niri.wayland-*.sock 2>/dev/null | head -1 || true)
if [[ -z "$sock" ]]; then
    echo "没找到 niri socket，合成器可能没起来" >&2
    systemctl --user --no-pager --lines=12 status niri.service >&2 || true
    exit 1
fi

export NIRI_SOCKET=$sock
echo "NIRI_SOCKET=$NIRI_SOCKET"
niri msg outputs 2>/dev/null | grep -E '^Output |Current mode|Disabled' || niri msg outputs

echo "完成。画面还黑就切回图形 VT（通常 Ctrl+Alt+F2）。"
echo "有 sudo 且仍无桌面再: sudo systemctl restart sddm"
