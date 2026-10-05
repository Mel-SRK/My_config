#!/usr/bin/env bash
# 按 MANIFEST.tsv 比对仓库与实机，只读，不改任何文件。
# 用法：tools/check-sync.sh [过滤关键字]
# 退出码 0 = 全部一致；1 = 有差异或实机缺失。
set -u
REPO="$(cd "$(dirname "$(realpath "$0")")/.." && pwd)"
MANIFEST="$REPO/MANIFEST.tsv"
filter="${1:-}"

same=0; diffn=0; missing=0

while IFS=$'\t' read -r src dst mode desc extra; do
  case "${src:-}" in ''|'#'*) continue ;; esac
  cls="${extra:-config}"
  [ -n "$filter" ] && case "$src" in *"$filter"*) ;; *) continue ;; esac
  dst_exp="${dst/#\~/$HOME}"
  if [ ! -e "$dst_exp" ]; then
    printf 'MISSING   %-48s -> %s\n' "$src" "$dst_exp"
    missing=$((missing+1))
    continue
  fi
  if [ -d "$REPO/$src" ]; then
    if diff -rq "$REPO/$src" "$dst_exp" >/dev/null 2>&1; then
      printf 'same      %-48s (%s 文件)\n' "$src" "$(find "$REPO/$src" -type f | wc -l)"
      same=$((same+1))
    else
      printf 'DIFF      %-48s -> %s\n' "$src" "$dst_exp"
      diff -rq "$REPO/$src" "$dst_exp" 2>&1 | sed 's/^/            /' | head -6
      diffn=$((diffn+1))
    fi
  else
    if cmp -s "$REPO/$src" "$dst_exp"; then
      printf 'same      %-48s\n' "$src"
      same=$((same+1))
    elif [ "$cls" = "state" ]; then
      printf 'drift     %-48s -> %s (%s 行差异；运行时状态，不计失败)\n' "$src" "$dst_exp" "$(diff "$REPO/$src" "$dst_exp" | grep -c '^[<>]')"
    else
      printf 'DIFF      %-48s -> %s (%s 行差异)\n' "$src" "$dst_exp" "$(diff "$REPO/$src" "$dst_exp" | grep -c '^[<>]')"
      diffn=$((diffn+1))
    fi
  fi
done < "$MANIFEST"

echo
echo "一致 $same / 有差异 $diffn / 实机缺失 $missing"
[ "$diffn" -eq 0 ] && [ "$missing" -eq 0 ] || exit 1
