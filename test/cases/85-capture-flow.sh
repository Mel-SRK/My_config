#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/base-test.sh"

for cmd in mktemp find sort; do require_command "$cmd"; done
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/shots"

# niri 桩：解析 --path，延迟写一张假图（模拟选区完成后落盘）
cat > "$tmp/bin/niri" <<'STUB'
#!/usr/bin/env bash
[[ "$1 $2" == 'msg action' && "$3" == screenshot ]] || exit 1
while [[ $# -gt 0 ]]; do
  [[ "$1" == --path ]] && out="$2"
  shift
done
[[ -n "${out:-}" ]] || exit 1
sleep 0.2
printf 'fake-png' > "$out"
STUB
# satty 桩：把输入原样留在输出位置
cat > "$tmp/bin/satty" <<'STUB'
#!/usr/bin/env bash
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
printf '#!/usr/bin/env bash\nprintf "OCR TEXT\\n"\n' > "$tmp/bin/tesseract"
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
