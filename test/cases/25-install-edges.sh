#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/base-test.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo with 'quote"
mkdir -p "$repo/tool" "$tmp/bin" "$tmp/home with spaces"
cp -- "$ROOT/install.sh" "$repo/install.sh"
cp -- "$ROOT/tool/mycfg-post" "$repo/tool/mycfg-post"
for name in mycfg-migrate mycfg-pkgs; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$repo/tool/$name"
  chmod +x "$repo/tool/$name"
done
export HOME="$tmp/home with spaces"
run() { "$repo/install.sh" "$@"; }

: > "$repo/MANIFEST.tsv"
run > "$tmp/empty.log" || fail '空 MANIFEST dry-run 成功'
grep -q 'user 条目 0 个，root 条目 0 个' "$tmp/empty.log" || fail '空 MANIFEST 计数为零'
[[ -z "$(find "$HOME" -mindepth 1 -print -quit)" ]] || fail 'dry-run 不写入 HOME'
pass '空 MANIFEST dry-run 成功且不写入 HOME'
for args in --unknown '--apply extra'; do
  status=0
  # Intentional word splitting exercises both invalid argument lists.
  run $args > /dev/null 2>&1 || status=$?
  assert_eq 2 "$status" "安装器拒绝参数：$args"
done

printf payload > "$repo/source file"
# No final newline: the last record must still be processed.
printf 'source file\t~/.config/dest file\tuser\tfixture' > "$repo/MANIFEST.tsv"
run --apply >/dev/null || fail '空格路径和无末尾换行的条目可安装'
cmp -s "$repo/source file" "$HOME/.config/dest file" || fail '空格路径内容一致'
pass '空格路径和无末尾换行的条目可安装'

printf '#!/usr/bin/env bash\nexit 9\n' > "$tmp/bin/cp"
chmod +x "$tmp/bin/cp"
status=0
PATH="$tmp/bin:$PATH" run --apply > "$tmp/copy.log" 2>&1 || status=$?
assert_eq 9 "$status" '复制失败保留失败退出码'
! grep -q '^copy ' "$tmp/copy.log" || fail '复制失败不打印成功'
pass '复制失败不打印成功'

printf 'source file\t/etc/myconfig quote\troot\tfixture\n' > "$repo/MANIFEST.tsv"
run > "$tmp/root.log"
root_command=$(sed -n '/^sudo install /p' "$tmp/root.log")
cat > "$tmp/bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$ARGV_LOG"
EOF
chmod +x "$tmp/bin/sudo"
ARGV_LOG="$tmp/argv" PATH="$tmp/bin:$PATH" bash -c "$root_command"
assert_eq "$repo/source file" "$(sed -n '4p' "$tmp/argv")" 'root 打印命令正确引用空格和单引号路径'
assert_eq '/etc/myconfig quote' "$(sed -n '5p' "$tmp/argv")" 'root 打印命令保留目的路径'

printf 'missing\t~/.config/missing\tuser\tfixture\n' > "$repo/MANIFEST.tsv"
status=0
run --apply >/dev/null 2>&1 || status=$?
assert_eq 1 "$status" '缺失源文件返回失败'
printf 'source file\t~/.config/wrong-mode\trot\tfixture\n' > "$repo/MANIFEST.tsv"
status=0
run --apply >/dev/null 2>&1 || status=$?
assert_eq 1 "$status" '非法 mode 返回失败'
[[ ! -e "$HOME/.config/wrong-mode" ]] || fail '非法 mode 不写入目标'
pass '非法 mode 不写入目标'
