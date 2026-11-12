#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/base-test.sh"

for cmd in mktemp grep; do require_command "$cmd"; done
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo with spaces"
mkdir -p "$repo/migrations"
state="$tmp/state"

cat > "$repo/migrations/001-ok.sh" <<'EOF'
echo ok1
EOF
cat > "$repo/migrations/002-fail.sh" <<'EOF'
echo fail
exit 1
EOF
cat > "$repo/migrations/003-ok.sh" <<'EOF'
echo ok3
EOF

run() { MYCONFIG_REPO="$repo" MYCONFIG_STATE_DIR="$state" HOME="$tmp/home" "$ROOT/tool/mycfg-migrate" "$@"; }

run list >/dev/null && pass 'list 有待办时 exit 0' || fail 'list 有待办时 exit 0'
assert_eq '001-ok.sh 002-fail.sh 003-ok.sh' "$(run list | paste -sd' ' -)" 'list 按文件名顺序列出待办'
run run >/dev/null
[[ ! -e $state ]] || fail 'run 默认 dry-run 不建状态目录'
pass 'run 默认 dry-run 不建状态目录'

if out=$(run run --apply); then
  fail '失败的迁移让 run --apply 退出非 0'
fi
pass '失败的迁移让 run --apply 退出非 0'
[[ -e "$state/001-ok.sh" ]] || fail '成功的迁移写入 marker'
pass '成功的迁移写入 marker'
[[ ! -e "$state/002-fail.sh" ]] || fail '失败的迁移不写 marker'
pass '失败的迁移不写 marker'
[[ ! -e "$state/003-ok.sh" ]] || fail '失败后不执行后续迁移'
pass '失败后不执行后续迁移'

rm -f "$repo/migrations/002-fail.sh"
printf 'sentinel\n' >> "$state/001-ok.sh"
run run --apply >/dev/null || fail '修掉失败项后能跑完'
pass '修掉失败项后能跑完'
[[ -e "$state/003-ok.sh" ]] || fail '补跑未完成的迁移'
pass '补跑未完成的迁移'
grep -q sentinel "$state/001-ok.sh" || fail '已完成迁移不会重跑'
pass '已完成迁移不会重跑'
status=0
run list >/dev/null || status=$?
assert_eq 3 "$status" '无待办时 list exit 3'

# A real command failure, rather than an explicit exit, must stop the child.
printf 'false\nprintf should-not-run\\n\n' > "$repo/migrations/004-command-fails.sh"
status=0
run run --apply > "$tmp/failure.log" 2>&1 || status=$?
assert_eq 1 "$status" '迁移命令失败会停止 runner'
[[ ! -e "$state/004-command-fails.sh" && ! -d "$state/.lock" ]] || fail '失败后不记 marker 且释放锁'
pass '失败后不记 marker 且释放锁'

# Marker publication failure must stop later migrations and remove the temp file.
rm -- "$repo/migrations/004-command-fails.sh"
mkdir -p "$tmp/bin"
printf '#!/usr/bin/env bash\nprintf partial\nexit 1\n' > "$tmp/bin/date"
chmod +x "$tmp/bin/date"
printf ':\n' > "$repo/migrations/004-marker.sh"
printf ':\n' > "$repo/migrations/005-later.sh"
status=0
PATH="$tmp/bin:$PATH" run run --apply >/dev/null 2>&1 || status=$?
assert_eq 1 "$status" 'marker 写入失败会停止 runner'
[[ ! -e "$state/004-marker.sh" && ! -e "$state/005-later.sh" && ! -d "$state/.lock" ]] || fail 'marker 失败不留完成记录或锁'
[[ -z "$(find "$state" -name '.marker.*' -print -quit)" ]] || fail 'marker 失败清理临时文件'
pass 'marker 失败不留完成记录、锁或临时文件'

rm -- "$repo/migrations/004-marker.sh" "$repo/migrations/005-later.sh"
cat > "$repo/migrations/006-concurrent.sh" <<'EOF'
printf 'run\n' >> "$MYCONFIG_REPO/executions"
touch "$MYCONFIG_REPO/entered"
while [[ ! -e "$MYCONFIG_REPO/release" ]]; do sleep 0.02; done
EOF
runner_pid=''
trap 'touch "$repo/release"; [[ -z "$runner_pid" ]] || wait "$runner_pid" || true; rm -rf "$tmp"' EXIT
run run --apply > "$tmp/first.log" 2>&1 &
runner_pid=$!
for ((i=0; i<200; i++)); do
  [[ ! -e "$repo/entered" ]] || break
  sleep 0.02
done
[[ -e "$repo/entered" ]] || fail '并发测试的首个 runner 已进入迁移'
status=0
run run --apply > "$tmp/second.log" 2>&1 || status=$?
touch "$repo/release"
wait "$runner_pid" || fail '首个 runner 成功'
runner_pid=''
assert_eq 1 "$status" '并发 runner 被锁拒绝'
assert_eq run "$(cat "$repo/executions")" '并发迁移只执行一次'
[[ -s "$state/006-concurrent.sh" && ! -d "$state/.lock" ]] || fail '并发完成后 marker 完整且释放锁'
pass '并发完成后 marker 完整且释放锁'

violations=0
for file in "$ROOT"/migrations/*.sh; do
  [[ "$(stat -c %a -- "$file")" == 644 ]] || { echo "权限不是 644：$file" >&2; violations=$((violations+1)); }
  head -n 1 -- "$file" | grep -q '^#!' && { echo "带了 shebang：$file" >&2; violations=$((violations+1)); }
done
[[ "$violations" -eq 0 ]] || fail '仓库里的迁移都是 0644 且无 shebang'
pass '仓库里的迁移都是 0644 且无 shebang'
