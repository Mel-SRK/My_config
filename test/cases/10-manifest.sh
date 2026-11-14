#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/base-test.sh"

require_command git
manifest="$ROOT/MANIFEST.tsv"
assert_file "$manifest" 'MANIFEST 存在'
if LC_ALL=C grep -q $'\r' "$manifest"; then
  fail 'MANIFEST 没有 CRLF' '发现 CR 字符'
fi
pass 'MANIFEST 没有 CRLF'
[[ -s "$manifest" && "$(tail -c 1 -- "$manifest" | od -An -tu1)" =~ ^[[:space:]]*10[[:space:]]*$ ]] ||
  fail 'MANIFEST 以换行结尾'
pass 'MANIFEST 以换行结尾'

declare -A destinations=()
line_no=0
while IFS= read -r line; do
  line_no=$((line_no+1))
  case "$line" in ''|'#'*) continue ;; esac
  # Split explicitly: read with tab IFS would discard empty TSV fields.
  fields=()
  rest="$line"
  while [[ "$rest" == *$'\t'* ]]; do
    fields+=("${rest%%$'\t'*}")
    rest="${rest#*$'\t'}"
  done
  fields+=("$rest")
  label="MANIFEST 第 $line_no 行"
  [[ ${#fields[@]} -eq 4 || ${#fields[@]} -eq 5 ]] ||
    fail "$label 字段数为 4 或 5" "$line"
  for field in "${fields[@]}"; do
    [[ "$field" != ' '* && "$field" != *' ' ]] ||
      fail "$label 字段没有首尾空格" "$line"
  done
  src="${fields[0]}"
  dst="${fields[1]}"
  mode="${fields[2]}"
  extra="${fields[4]:-}"
  [[ "$mode" == user || "$mode" == root ]] || fail "$label mode 合法" "$mode"
  [[ -z "$extra" || "$extra" == state ]] || fail "$label extra 合法" "$extra"
  [[ -e "$ROOT/$src" ]] || fail "$label src 存在" "$src"
  # 新增配置应能在 git add 前测试，但不能被忽略而在提交时遗漏。
  git -C "$ROOT" ls-files --cached --others --exclude-standard --error-unmatch -- "$src" >/dev/null 2>&1 ||
    fail "$label src 被 git 跟踪或为非忽略的新文件" "$src"
  [[ "$src" != archive/* ]] || fail "$label src 不在 archive/" "$src"
  [[ "$dst" == '~/'* || "$dst" == /* ]] || fail "$label dst 为安装路径" "$dst"
  # A trailing slash or ~/ versus an absolute HOME path denotes the same destination.
  dst_key="${dst/#\~/$HOME}"
  while [[ "$dst_key" != / && "$dst_key" == */ ]]; do dst_key="${dst_key%/}"; done
  [[ -z "${destinations[$dst_key]+present}" ]] ||
    fail "$label dst 不重复" "$dst：${destinations[$dst_key]} 与 $src"
  destinations["$dst_key"]="$src"
  pass "$label：$src"
done < "$manifest"

# 活跃 systemd 配置必须进入部署清单，防止文件存在但恢复时遗漏。
while IFS= read -r -d '' file; do
  src="${file#"$ROOT/"}"
  awk -F '\t' -v src="$src" '$1 == src { found=1 } END { exit !found }' "$manifest" ||
    fail 'systemd 配置纳入 MANIFEST' "$src"
  pass "systemd 部署覆盖：$src"
done < <(find "$ROOT/systemd/user" -type f -print0)
