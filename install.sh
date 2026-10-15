#!/usr/bin/env bash
# 按 MANIFEST.tsv 把仓库里的配置装回实机。
# 默认只打印计划；确认无误后加 --apply 才真正写入。
# root 权限的那些条目永远只打印 sudo 命令，不自己执行。
set -u
REPO="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
MANIFEST="$REPO/MANIFEST.tsv"
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

[ -f "$MANIFEST" ] || { echo "找不到 $MANIFEST"; exit 1; }

root_cmds=()
user_units=()
count_user=0
count_root=0
greetd_changed=0

while IFS=$'\t' read -r src dst mode desc extra; do
  case "${src:-}" in ''|'#'*) continue ;; esac
  dst_exp="${dst/#\~/$HOME}"
  if [ "$mode" = "root" ]; then
    count_root=$((count_root+1))
    if [ -d "$REPO/$src" ]; then
      root_cmds+=("sudo cp -a '$REPO/$src/.' '$dst/'")
    else
      root_cmds+=("sudo install -Dm644 '$REPO/$src' '$dst'")
      # /etc/greetd 或 /etc/pam.d/greetd 这次要动的话，下面得配一句警告
      case "$dst" in
        /etc/greetd/*|/etc/pam.d/greetd)
          cmp -s "$REPO/$src" "$dst_exp" 2>/dev/null || greetd_changed=1
          ;;
      esac
    fi
    continue
  fi
  count_user=$((count_user+1))
  if [ "$APPLY" -eq 1 ]; then
    mkdir -p "$(dirname "$dst_exp")"
    if [ -d "$REPO/$src" ]; then
      mkdir -p "$dst_exp"
      cp -a "$REPO/$src/." "$dst_exp/"
      echo "copy  $src  ->  $dst_exp/"
    else
      cp -a "$REPO/$src" "$dst_exp"
      echo "copy  $src  ->  $dst_exp"
    fi
  else
    echo "计划  $src  ->  $dst_exp"
  fi
  case "$dst_exp" in
    */.config/systemd/user/*.service) user_units+=("$(basename "$dst_exp")") ;;
  esac
done < "$MANIFEST"

echo
echo "user 条目 $count_user 个，root 条目 $count_root 个。"

echo
echo "===== 装完还要自己做的 ====="
if [ "${#user_units[@]}" -gt 0 ]; then
  echo "systemctl --user daemon-reload"
  for u in "${user_units[@]}"; do echo "systemctl --user enable --now $u"; done
fi
echo "chmod +x ~/.local/bin/ctfdbg ~/.local/bin/ctfrun ~/.local/bin/hmcl-bin ~/.local/bin/micmute-led-sync.sh"
echo "ln -sf ~/.config/tmux/.tmux.conf ~/.tmux.conf"
echo "ln -sf ~/.config/tmux/.tmux.conf.local ~/.tmux.conf.local"
echo "niri msg action load-config-file    # 重载 niri 配置"
echo "重新登录，environment.d/ 里的环境变量才生效"

if [ "$count_root" -gt 0 ]; then
  echo
  echo "===== root 条目（自己跑，需要 sudo） ====="
  for c in "${root_cmds[@]}"; do echo "$c"; done
  echo "sudo udevadm control --reload-rules && sudo udevadm trigger --subsystem-match=leds"
  echo "sudo systemctl daemon-reload"
fi

if [ "$greetd_changed" -eq 1 ]; then
  echo
  echo "===== 这次动了 greetd 的文件，读这段 ====="
  echo "两个文件都不需要为生效去重启 greetd：/etc/pam.d/greetd 每次认证都重读，"
  echo "/etc/greetd/config.toml 下次 greetd 起来时读（下次开机即可）。"
  echo
  echo "千万别在图形会话里跑 systemctl restart greetd。greeter 会去抢 vt=1，"
  echo "把当前 niri 会话挤成 inactive：桌面消失但进程还在，再登录会被 niri-session 的"
  echo "\"A niri session is already running.\" 挡在门外。"
  echo "真要立刻生效：登出到登录界面之后再重启，或者干脆等下次开机。"
  echo
  echo "万一已经踩了：loginctl list-sessions  找到自己那个 seat0 会话号，"
  echo "  另一块 VT 上跑 loginctl activate <会话号>；同一块 VT 被 greeter 占着就先 sudo systemctl stop greetd。"
fi

if [ "$APPLY" -eq 0 ]; then
  echo
  echo "以上只是计划。要落地：$0 --apply"
fi
