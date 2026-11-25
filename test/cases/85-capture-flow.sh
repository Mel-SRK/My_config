#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/base-test.sh"

for cmd in mktemp find sort; do require_command "$cmd"; done
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/shots" "$tmp/work"
export CAPTURE_TEST_ROOT="$tmp" TMPDIR="$tmp/work"

# niri 桩：解析 --path，延迟写一张假图（模拟选区完成后落盘）
cat > "$tmp/bin/niri" <<'STUB'
#!/usr/bin/env bash
[[ "$1 $2" == 'msg action' && "$3" == screenshot ]] || exit 1
while [[ $# -gt 0 ]]; do
  [[ "$1" == --path ]] && out="$2"
  shift
done
[[ -n "${out:-}" ]] || exit 1
printf '%s\n' "$out" > "$CAPTURE_TEST_ROOT/capture-path"
case "${CAPTURE_MODE:-ok}" in
  cancel) exit 0 ;;
  fail) exit 7 ;;
esac
(sleep 0.2; printf 'fake-png' > "$out") >/dev/null 2>&1 &
STUB
# satty 桩：把输入原样留在输出位置
cat > "$tmp/bin/satty" <<'STUB'
#!/usr/bin/env bash
[[ "${SATTY_MODE:-ok}" != fail ]] || exit 8
while [[ $# -gt 0 ]]; do
  [[ "$1" == --filename || "$1" == --output-filename ]] && last="$2"
  [[ "$1" == --filename ]] && in="$2"
  [[ "$1" == --output-filename ]] && out="$2"
  shift
done
[[ -n "${in:-}" && -n "${out:-}" ]] || exit 1
printf 'annotated' > "$out"
STUB
printf '#!/usr/bin/env bash\ncat > "%s/clipboard"\n' "$tmp" > "$tmp/bin/wl-copy"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s/notify"\n' "$tmp" > "$tmp/bin/notify-send"
cat > "$tmp/bin/tesseract" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$CAPTURE_TEST_ROOT/tesseract-args"
case "${OCR_MODE:-ok}" in
  empty) printf '\n  \n'; exit 0 ;;
  fail) exit 9 ;;
  big) awk 'BEGIN{for(i=0;i<3000;i++) print "line " i}'; exit 0 ;;
esac
printf '\nOCR TEXT\n\n'
STUB
# Cancellation skips the 60-second polling budget without changing the scripts.
export REAL_SEQ="$(command -v seq)"
cat > "$tmp/bin/seq" <<'STUB'
#!/usr/bin/env bash
if [[ "${CAPTURE_MODE:-ok}" == cancel ]]; then exit 0; fi
exec "$REAL_SEQ" "$@"
STUB
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"

# 预置三张旧图，保留数设成 2
for i in 1 2 3; do
  printf 'old' > "$tmp/shots/shot-$i.png"
  touch -d "-$((10 - i)) minutes" "$tmp/shots/shot-$i.png"
done

export SCREENSHOT_DIR="$tmp/shots" SCREENSHOT_KEEP=2
"$ROOT/local/bin/screenshot-annotate" || fail 'screenshot-annotate 跑通'
pass 'screenshot-annotate 跑通'
count=$(find "$tmp/shots" -name '*.png' | wc -l)
assert_eq 2 "$count" '按 SCREENSHOT_KEEP 保留张数'
[[ -e "$tmp/shots/shot-3.png" ]] || fail '最新的旧图被保留'
pass '最新的旧图被保留'
[[ ! -e "$tmp/shots/shot-1.png" ]] || fail '最旧的图被清掉'
pass '最旧的图被清掉'
newest=$(find "$tmp/shots" -name '*.png' ! -name 'shot-*' | head -1)
[[ -n "$newest" ]] || fail '产生了新截图'
pass '产生了新截图'
assert_eq annotated "$(cat "$newest")" 'satty 的输出写回同一张图'

"$ROOT/local/bin/ocr-region" || fail 'ocr-region 跑通'
pass 'ocr-region 跑通'
[[ "$(cat "$tmp/clipboard")" == 'OCR TEXT' ]] || fail 'OCR 结果进剪贴板'
pass 'OCR 结果进剪贴板'
grep -q 'OCR 已复制到剪贴板' "$tmp/notify" || fail 'OCR 弹通知'
pass 'OCR 弹通知'
[[ ! -e "$(cat "$tmp/capture-path")" ]] || fail 'OCR 成功后清理临时图'
pass 'OCR 成功后清理临时图'

for mode in empty fail; do
  rm -- "$tmp/clipboard"
  status=0
  OCR_MODE="$mode" "$ROOT/local/bin/ocr-region" || status=$?
  assert_eq 1 "$status" "OCR $mode 返回失败"
  [[ ! -e "$tmp/clipboard" && ! -e "$(cat "$tmp/capture-path")" ]] || fail "OCR $mode 不复制且清理临时图"
  pass "OCR $mode 不复制且清理临时图"
  # Leave a sentinel so the next iteration can remove the same path.
  : > "$tmp/clipboard"
done
OCR_LANG=eng "$ROOT/local/bin/ocr-region" || fail '支持 OCR_LANG 覆盖'
assert_eq eng "$(sed -n '4p' "$tmp/tesseract-args")" 'OCR_LANG 传给 tesseract'
assert_eq 6 "$(sed -n '6p' "$tmp/tesseract-args")" 'tesseract 使用 psm 6'

for script in screenshot-annotate ocr-region; do
  for mode in cancel fail; do
    status=0
    CAPTURE_MODE="$mode" SCREENSHOT_DIR="$tmp/$script-$mode" "$ROOT/local/bin/$script" || status=$?
    if [[ "$mode" == cancel ]]; then expected=0; else expected=1; fi
    assert_eq "$expected" "$status" "$script 的 $mode 退出码"
    [[ ! -e "$(cat "$tmp/capture-path")" ]] || fail "$script 的 $mode 不留截图"
    pass "$script 的 $mode 不留截图"
  done
done

status=0
SATTY_MODE=fail SCREENSHOT_DIR="$tmp/satty-failure" "$ROOT/local/bin/screenshot-annotate" || status=$?
assert_eq 8 "$status" 'satty 失败保留退出码'
assert_eq fake-png "$(cat "$(cat "$tmp/capture-path")")" 'satty 失败仍保留原图'

# 大文本 OCR：预览长度截断必须走 bash 变量，不能 head -c（会 SIGPIPE 打断脚本）
rm -f "$tmp/clipboard"
OCR_MODE=big "$ROOT/local/bin/ocr-region" || fail '大文本 OCR 不因 SIGPIPE 失败'
pass '大文本 OCR 不因 SIGPIPE 失败'
[[ -s "$tmp/clipboard" ]] || fail '大文本 OCR 仍写入剪贴板'
pass '大文本 OCR 仍写入剪贴板'

# 文件名含空格：旧实现用 xargs 会把路径拆成多个参数，误删 cwd 里的同名文件
mkdir -p "$tmp/spadecoy" "$tmp/work2"
printf old > "$tmp/spadecoy/old image.png"
touch -d '-10 minutes' "$tmp/spadecoy/old image.png"
printf new > "$tmp/spadecoy/new.png"
touch -d '-1 minute' "$tmp/spadecoy/new.png"
: > "$tmp/work2/old"
: > "$tmp/work2/image.png"
(cd "$tmp/work2" && SCREENSHOT_KEEP=1 SCREENSHOT_DIR="$tmp/spadecoy" "$ROOT/local/bin/screenshot-annotate") ||
  fail '含空格文件名的清理跑通'
pass '含空格文件名的清理跑通'
[[ ! -e "$tmp/spadecoy/old image.png" ]] || fail '含空格文件名被正确删除'
pass '含空格文件名被正确删除'
[[ -e "$tmp/work2/old" && -e "$tmp/work2/image.png" ]] || fail '不误删当前目录的无关文件'
pass '不误删当前目录的无关文件'

mkdir -p "$tmp/shots with spaces"
printf old > "$tmp/shots with spaces/old image.png"
SCREENSHOT_KEEP=0 SCREENSHOT_DIR="$tmp/shots with spaces" "$ROOT/local/bin/screenshot-annotate" || fail '禁用清理时支持含空格目录'
assert_eq 2 "$(find "$tmp/shots with spaces" -name '*.png' | wc -l)" 'SCREENSHOT_KEEP=0 不删旧图'

# Run translation in an isolated PATH so host optional packages cannot affect the fallback.
mkdir -p "$tmp/translate-bin" "$tmp/translate-home/.local/bin"
for cmd in bash dirname mktemp rm sed sleep; do
  ln -s "$(command -v "$cmd")" "$tmp/translate-bin/$cmd"
done
for cmd in niri notify-send seq tesseract wl-copy; do
  ln -s "$tmp/bin/$cmd" "$tmp/translate-bin/$cmd"
done
cat > "$tmp/translate-bin/manggo" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$CAPTURE_TEST_ROOT/translation"
STUB
chmod +x "$tmp/translate-bin/manggo"
translate() {
  HOME="$tmp/translate-home" PATH="$tmp/translate-bin" "$ROOT/local/bin/manggo-screenshot-translate"
}

rm -f -- "$tmp/clipboard"
translate || fail '缺少 still 时截图翻译跑通'
assert_eq $'--action\ninput-translation\n--text\nOCR TEXT' "$(cat "$tmp/translation")" '识别文字作为独立参数交给 Manggo'
[[ ! -e "$tmp/clipboard" ]] || fail '翻译模式不把识别结果写到剪贴板'
pass '翻译模式不把识别结果写到剪贴板'

rm -- "$tmp/translation"
CAPTURE_MODE=cancel translate || fail '取消截图翻译正常退出'
[[ ! -e "$tmp/translation" ]] || fail '取消选区不启动翻译'
pass '取消选区不启动翻译'

cat > "$tmp/translate-home/.local/bin/still" <<'STUB'
#!/usr/bin/env bash
[[ "$1" == -c ]] || exit 1
exec bash -c "$2"
STUB
printf '#!/usr/bin/env bash\nprintf "0,0 100x100"\n' > "$tmp/translate-bin/slurp"
printf '#!/usr/bin/env bash\n[[ "$*" == "-g 0,0 100x100 -" ]] || exit 1\nprintf "fake-png"\n' > "$tmp/translate-bin/grim"
chmod +x "$tmp/translate-home/.local/bin/still" "$tmp/translate-bin/"{slurp,grim}
rm -- "$tmp/capture-path"
translate || fail '本机仍可使用 still 截图翻译'
[[ ! -e "$tmp/capture-path" ]] || fail 'still 可用时优先使用原来的截图方式'
pass 'still 可用时优先使用原来的截图方式'
assert_eq $'--action\ninput-translation\n--text\n\nOCR TEXT' "$(cat "$tmp/translation")" 'still 截图识别文字交给 Manggo'

[[ -z "$(find "$TMPDIR" -mindepth 1 -print -quit)" ]] || fail 'OCR 各分支均清理临时图'
pass 'OCR 各分支均清理临时图'
