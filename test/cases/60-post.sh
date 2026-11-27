#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/base-test.sh"

for cmd in mktemp stat readlink gsettings; do require_command "$cmd"; done
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat > "$tmp/bin/systemctl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SYSTEMCTL_LOG"
exit 0
STUB
chmod +x "$tmp/bin/systemctl"
export SYSTEMCTL_LOG="$tmp/systemctl.log"
export PATH="$tmp/bin:$PATH"
export GSETTINGS_BACKEND=keyfile XDG_CONFIG_HOME="$tmp/config"
recent_files_key=(org.gnome.desktop.privacy remember-recent-files)
gsettings set "${recent_files_key[@]}" true

HOME="$tmp/home" "$ROOT/install.sh" --apply >/dev/null || fail 'install --apply 成功'
pass 'install --apply 成功'
chmod 644 "$tmp/home/.local/bin/ctfrun"

out=$(HOME="$tmp/home" "$ROOT/tool/mycfg-post") || fail 'post dry-run 成功'
pass 'post dry-run 成功'
grep -q 'chmod +x .*ctfrun' <<< "$out" || fail 'dry-run 列出需要修的 chmod' "$out"
pass 'dry-run 列出需要修的 chmod'
assert_eq 644 "$(stat -c %a "$tmp/home/.local/bin/ctfrun")" 'dry-run 不改文件权限'
[[ ! -L "$tmp/home/.tmux.conf" ]] || fail 'dry-run 不建符号链接'
pass 'dry-run 不建符号链接'
grep -q '^gsettings set org\.gnome\.desktop\.privacy remember-recent-files false$' <<< "$out" ||
  fail 'dry-run 列出 GTK 设置步骤' "$out"
pass 'dry-run 列出 GTK 设置步骤'
assert_eq true "$(gsettings get "${recent_files_key[@]}")" 'dry-run 保留最近文件记录设置'

HOME="$tmp/home" "$ROOT/tool/mycfg-post" --apply >/dev/null || fail 'post --apply 成功'
pass 'post --apply 成功'
assert_eq false "$(gsettings get "${recent_files_key[@]}")" '--apply 关闭最近文件记录'
assert_eq 755 "$(stat -c %a "$tmp/home/.local/bin/ctfrun")" '--apply 修好可执行位'
assert_eq "$tmp/home/.config/tmux/.tmux.conf" "$(readlink -m -- "$tmp/home/.tmux.conf")" '--apply 建 .tmux.conf 链接'
assert_eq "$tmp/home/.config/tmux/.tmux.conf.local" "$(readlink -m -- "$tmp/home/.tmux.conf.local")" '--apply 建 .tmux.conf.local 链接'
[[ ! -e "$SYSTEMCTL_LOG" ]] || fail '--apply 不执行 systemctl' "$(cat "$SYSTEMCTL_LOG")"
pass '--apply 不执行 systemctl'

out=$(HOME="$tmp/home" "$ROOT/tool/mycfg-post")
if grep -qE '^(chmod |ln )' <<< "$out"; then fail '收尾后不该还有 chmod 或链接步骤' "$out"; fi
pass '收尾后不再列出可执行位和链接'
if grep -q '^gsettings set ' <<< "$out"; then fail '关闭后不再列出 GTK 设置步骤' "$out"; fi
pass '关闭后不再列出 GTK 设置步骤'

mkdir -p "$tmp/empty-schemas"
(
  export XDG_DATA_DIRS="$tmp/empty-schemas" GSETTINGS_SCHEMA_DIR="$tmp/empty-schemas"
  if gsettings get "${recent_files_key[@]}" >/dev/null 2>&1; then fail '测试目录应缺少 GTK 设置'; fi
  out=$(HOME="$tmp/home" "$ROOT/tool/mycfg-post" --apply) || fail '缺少 GTK 设置时仍可执行收尾'
  if grep -q '^gsettings set ' <<< "$out"; then fail '缺少 GTK 设置时跳过该步骤' "$out"; fi
  pass '缺少 GTK 设置时跳过该步骤'
)

mkdir -p "$tmp/directory-home/.tmux.conf"
status=0
HOME="$tmp/directory-home" "$ROOT/tool/mycfg-post" --apply >/dev/null 2>&1 || status=$?
assert_eq 1 "$status" 'tmux 入口为真实目录时失败而不在其中建链接'
[[ -z "$(find "$tmp/directory-home/.tmux.conf" -mindepth 1 -print -quit)" ]] || fail '原有 tmux 目录保持不变'
pass '原有 tmux 目录保持不变'

conflict_home="$tmp/conflict-home"
mkdir -p "$conflict_home/.config/tmux" "$conflict_home/.local/bin"
cp -- "$ROOT/tmux/.tmux.conf" "$ROOT/tmux/.tmux.conf.local" "$conflict_home/.config/tmux/"
printf 'custom-config\n' > "$conflict_home/.tmux.conf.local"
: > "$conflict_home/.local/bin/screenshot-annotate"
chmod 644 "$conflict_home/.local/bin/screenshot-annotate"
HOME="$conflict_home" "$ROOT/tool/mycfg-post" > "$tmp/plan" 2> "$tmp/conflict" || fail 'tmux 冲突时仍可打印安装计划'
grep -q '请先备份并移走' "$tmp/conflict" || fail '安装计划给出处理冲突的说明'
pass 'tmux 冲突时仍可打印安装计划'
status=0
HOME="$conflict_home" "$ROOT/tool/mycfg-post" --apply >/dev/null 2>"$tmp/conflict" || status=$?
assert_eq 1 "$status" '已有 tmux 配置文件时返回部分完成'
[[ -f "$conflict_home/.tmux.conf.local" && ! -L "$conflict_home/.tmux.conf.local" ]] || fail '保留普通 tmux 配置文件'
assert_eq custom-config "$(cat "$conflict_home/.tmux.conf.local")" '原有 tmux 配置文件内容不变'
[[ ! -L "$conflict_home/.tmux.conf" ]] || fail '有冲突时两个入口均未更改'
pass '有冲突时两个入口均未更改'
assert_eq 755 "$(stat -c %a "$conflict_home/.local/bin/screenshot-annotate")" 'tmux 冲突时仍修复脚本权限'

mv -- "$conflict_home/.tmux.conf.local" "$conflict_home/custom-config"
ln -s -- custom-config "$conflict_home/.tmux.conf.local"
status=0
HOME="$conflict_home" "$ROOT/tool/mycfg-post" --apply >/dev/null 2>&1 || status=$?
assert_eq 1 "$status" '已有其他 tmux 链接时收尾失败'
assert_eq custom-config "$(readlink -- "$conflict_home/.tmux.conf.local")" '保留其他 tmux 链接的原始目标'

missing_home="$tmp/missing-home"
mkdir -p "$missing_home/.config/tmux"
cp -- "$ROOT/tmux/.tmux.conf" "$missing_home/.config/tmux/"
status=0
HOME="$missing_home" "$ROOT/tool/mycfg-post" --apply >/dev/null 2>"$tmp/missing" || status=$?
assert_eq 1 "$status" 'tmux 配置未全部安装时收尾失败'
grep -q '请先运行 .*install.sh --apply' "$tmp/missing" || fail '缺少配置时提示先安装'
[[ ! -L "$missing_home/.tmux.conf" && ! -L "$missing_home/.tmux.conf.local" ]] || fail '目标文件不全时不创建链接'
pass '目标文件不全时不创建链接'
