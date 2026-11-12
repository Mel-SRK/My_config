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

# All behavioral checks use a fake package database, never the host's pacman.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo with spaces"
mkdir -p "$repo/packages" "$tmp/bin" "$tmp/work"
cat > "$tmp/bin/pacman" <<'EOF'
#!/usr/bin/env bash
case "${PKG_MODE:-normal}:$1" in
  fail:-Qem) echo 'database error' >&2; exit 1 ;;
  partial:-Qem) printf 'partial 1\n'; exit 2 ;;
  empty:*) exit 1 ;;
  large:-Qen) for ((i=0; i<10000; i++)); do printf 'pkg%05d 1\n' "$i"; done ;;
  *:-Qen) printf 'extra 2\nbase 1\n' ;;
  *:-Qem) printf 'aur 1\n' ;;
  *) exit 2 ;;
esac
EOF
for cmd in sudo yay paru; do
  cat > "$tmp/bin/$cmd" <<'EOF'
#!/usr/bin/env bash
touch "$COMMAND_LOG"
exit 1
EOF
done
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH" COMMAND_LOG="$tmp/executed" TMPDIR="$tmp/work"
run() { MYCONFIG_REPO="$repo" "$ROOT/tool/mycfg-pkgs" "$@"; }
printf 'base\nmissing\n' > "$repo/packages/official.txt"
printf 'aur\naur-missing\n' > "$repo/packages/foreign.txt"

status=0
out=$(run check --summary) || status=$?
assert_eq 1 "$status" '缺包时 check exit 1'
grep -q '^包：缺 2，未记录 1' <<< "$out" || fail 'check 正确汇总缺包和未记录包' "$out"
pass 'check 正确汇总缺包和未记录包'
status=0
out=$(run) || status=$?
assert_eq 1 "$status" '无参数默认为 check 而不是用法错误'
grep -q '^缺（official）' <<< "$out" || fail '无参数 check 输出详情'
pass '无参数 check 输出详情'

before=$(sha256sum "$repo/packages/"*.txt)
run write > "$tmp/preview" || fail 'write dry-run 成功'
grep -q '^  [+-]' "$tmp/preview" || fail 'write dry-run 打印 diff'
assert_eq "$before" "$(sha256sum "$repo/packages/"*.txt)" 'write dry-run 不改清单'
out=$(run install) || fail 'install 打印缺包命令并 exit 0'
pass 'install 打印缺包命令并 exit 0'
grep -q '^sudo pacman -S --needed missing$' <<< "$out" || fail 'install 打印官方补包命令' "$out"
grep -q '^yay -S --needed aur-missing$' <<< "$out" || fail 'install 优先打印 yay 补包命令' "$out"
[[ ! -e "$COMMAND_LOG" ]] || fail 'install 不执行 sudo 或 AUR helper'
pass 'install 不执行 sudo 或 AUR helper'

for mode in fail partial; do
  for args in 'check --summary' 'write --apply' install; do
    status=0
    PKG_MODE="$mode" run $args > "$tmp/failure" 2>&1 || status=$?
    assert_eq 1 "$status" "$mode 查询失败使 $args 失败"
    assert_eq "$before" "$(sha256sum "$repo/packages/"*.txt)" "$mode 查询失败不覆盖任一清单"
  done
done
PKG_MODE=large run write >/dev/null || fail '大 diff 预览不会被 head 的 SIGPIPE 中断'
pass '大 diff 预览不会被 head 的 SIGPIPE 中断'
run write --apply >/dev/null || fail 'write --apply 成功'
assert_eq $'base\nextra' "$(cat "$repo/packages/official.txt")" '--apply 写入排序后的官方包名'
assert_eq aur "$(cat "$repo/packages/foreign.txt")" '--apply 写入 foreign 包名'
run check --summary >/dev/null || fail '无缺包时 check exit 0'
pass '无缺包时 check exit 0'
assert_eq '没有缺的包' "$(run install)" 'install 无缺包时正常返回'

repo="$tmp/absent packages"
mkdir -p "$repo"
run write >/dev/null || fail '无 packages 目录也能预览'
[[ ! -e "$repo/packages" ]] || fail 'dry-run 不创建 packages 目录'
pass 'dry-run 不创建 packages 目录'
PKG_MODE=empty run write --apply >/dev/null || fail 'pacman 静默 exit 1 表示合法空集合'
[[ -f "$repo/packages/official.txt" && ! -s "$repo/packages/official.txt" && -f "$repo/packages/foreign.txt" && ! -s "$repo/packages/foreign.txt" ]] || fail '空包集合写入空清单'
pass '空包集合写入空清单'
[[ -z "$(find "$TMPDIR" -mindepth 1 -print -quit)" ]] || fail '所有分支清理临时目录'
pass '所有分支清理临时目录'
