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

while IFS=$'\t' read -r src dst mode desc extra; do
  case "${src:-}" in ''|'#'*) continue ;; esac
  cls="${extra:-config}"
  dst_exp="${dst/#\~/$HOME}"
  if [ "$mode" = "root" ]; then
    count_root=$((count_root+1))
    if [ -d "$REPO/$src" ]; then
      root_cmds+=("sudo cp -a '$REPO/$src/.' '$dst/'")
    else
      root_cmds+=("sudo install -Dm644 '$REPO/$src' '$dst'")
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
if [ "$APPLY" -eq 0 ]; then
  echo "以上只是计划。要落地：$0 --apply"
  exit 0
fi

echo
echo "===== 还需要手动做的 ====="
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
  echo "sudo systemctl restart greetd    # 只在改了 /etc/greetd 或 /etc/pam.d/greetd 时需要"
fi
