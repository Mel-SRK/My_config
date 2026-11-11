#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/base-test.sh"

if command -v niri >/dev/null 2>&1; then
  require_command niri
  niri validate -c "$ROOT/niri/config.kdl" || fail 'niri 配置语法'
  pass 'niri 配置语法'
else
  skip 'niri 配置语法' '缺少命令：niri'
fi
require_command git
files=$(git -C "$ROOT" ls-files '*.sh') || fail '取得 git 跟踪的 shell 文件'
while IFS= read -r file; do
  case "$file" in ''|archive/*) continue ;; esac
  bash -n "$ROOT/$file" || fail 'bash 语法' "$file"
  pass "bash 语法：$file"
done <<< "$files"
# tool/ 下的脚本没有 .sh 后缀，git ls-files '*.sh' 扫不到
for file in "$ROOT"/tool/mycfg-*; do
  bash -n "$file" || fail 'bash 语法' "tool/${file##*/}"
  pass "bash 语法：tool/${file##*/}"
done
if command -v zsh >/dev/null 2>&1; then
  for file in home/.zshrc p10k/.p10k.zsh; do
    zsh -n "$ROOT/$file" || fail 'zsh 语法' "$file"
    pass "zsh 语法：$file"
  done
else
  skip 'zsh 语法' '缺少命令：zsh'
fi
for file in "$ROOT/kanshi/config" "$ROOT"/systemd/user/*.service; do
  [[ -f "$file" && -s "$file" ]] || fail '配置存在且非空' "$file"
  pass "配置存在且非空：${file#"$ROOT/"}"
done
