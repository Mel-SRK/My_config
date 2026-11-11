#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/base-test.sh"

for file in packages/official.txt packages/foreign.txt; do
  assert_file "$ROOT/$file" "$file 存在"
  [[ -s "$ROOT/$file" ]] || fail "$file 非空"
  pass "$file 非空"
  LC_ALL=C sort -c "$ROOT/$file" 2>/dev/null || fail "$file 按 C 排序"
  pass "$file 按 C 排序"
  dupes=$(LC_ALL=C sort "$ROOT/$file" | uniq -d)
  [[ -z "$dupes" ]] || fail "$file 没有重复" "$dupes"
  pass "$file 没有重复"
  bad=$(grep -nvE '^[a-z0-9@._+-]+$' "$ROOT/$file" || true)
  [[ -z "$bad" ]] || fail "$file 只含合法包名" "$bad"
  pass "$file 只含合法包名"
done
overlap=$(LC_ALL=C comm -12 "$ROOT/packages/official.txt" "$ROOT/packages/foreign.txt")
[[ -z "$overlap" ]] || fail '两份清单不重叠' "$overlap"
pass '两份清单不重叠'

# write 的默认模式必须只预览
before=$(sha256sum "$ROOT/packages/official.txt" "$ROOT/packages/foreign.txt")
MYCONFIG_REPO="$ROOT" "$ROOT/tool/mycfg-pkgs" write >/dev/null 2>&1 || fail 'mycfg-pkgs write 预览模式可运行'
pass 'mycfg-pkgs write 预览模式可运行'
assert_eq "$before" "$(sha256sum "$ROOT/packages/official.txt" "$ROOT/packages/foreign.txt")" '预览模式不改文件'

if command -v pacman >/dev/null 2>&1; then
  out=$(MYCONFIG_REPO="$ROOT" "$ROOT/tool/mycfg-pkgs" check --summary 2>&1) || true
  grep -q '^包：缺 [0-9]*，未记录 [0-9]*' <<< "$out" || fail 'check 输出汇总行' "$out"
  pass 'check 输出汇总行'
else
  skip 'check 输出汇总行' '缺少命令：pacman'
fi
