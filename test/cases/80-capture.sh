#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/base-test.sh"

for file in local/bin/screenshot-annotate local/bin/ocr-region; do
  assert_file "$ROOT/$file" "$file 存在"
  [[ -x "$ROOT/$file" ]] || fail "$file 可执行"
  pass "$file 可执行"
  bash -n "$ROOT/$file" || fail "$file 语法"
  pass "$file 语法"
done

# 键位必须还在，否则脚本装了也没人调用
for bind in 'Mod\+Shift\+S.*screenshot-annotate' 'Mod\+Shift\+O.*ocr-region'; do
  grep -qE "$bind" "$ROOT/niri/config.kdl" || fail "niri 绑定存在：$bind"
  pass "niri 绑定存在：$bind"
done

# satty 的几个参数是版本敏感的，缺一个脚本就会失败
if command -v satty >/dev/null 2>&1; then
  help=$(satty --help 2>&1)
  for flag in --save-after-copy --actions-on-enter --early-exit --copy-command; do
    grep -q -- "$flag" <<< "$help" || fail "satty 支持 $flag"
    pass "satty 支持 $flag"
  done
else
  skip 'satty 参数检查' '缺少命令：satty'
fi

# OCR 管线端到端：造一张带字的图，验证语言包和 psm 组合真能识别
if command -v tesseract >/dev/null 2>&1 && command -v magick >/dev/null 2>&1; then
  img=$(mktemp --suffix=.png)
  trap 'rm -f -- "$img"' EXIT
  magick -size 640x140 xc:white -pointsize 42 -fill black -annotate +30+85 'FLAG ocr region test' "$img"
  out=$(tesseract "$img" - -l chi_sim+eng --psm 6 2>/dev/null) || fail 'tesseract 能处理测试图'
  grep -q 'FLAG' <<< "$out" || fail 'OCR 识别出英文关键字' "$out"
  pass 'OCR 识别出英文关键字'
else
  skip 'OCR 管线端到端' '缺少 tesseract 或 magick'
fi
