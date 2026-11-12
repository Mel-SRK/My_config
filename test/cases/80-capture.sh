#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/base-test.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
capture_home="$tmp/home with spaces"
mkdir -p "$capture_home/.local/bin"
for file in local/bin/screenshot-annotate local/bin/ocr-region; do
  assert_file "$ROOT/$file" "$file 存在"
  [[ -x "$ROOT/$file" ]] || fail "$file 可执行"
  pass "$file 可执行"
  bash -n "$ROOT/$file" || fail "$file 语法"
  pass "$file 语法"
  cp -- "$ROOT/$file" "$capture_home/.local/bin/"
done

# Check the actual spawn-sh command and its installed target under a clean HOME.
for name in screenshot-annotate ocr-region; do
  if [[ "$name" == screenshot-annotate ]]; then bind='Mod\+Shift\+S'; else bind='Mod\+Shift\+O'; fi
  grep -qE "^[[:space:]]*$bind[[:space:]].*\{[[:space:]]*spawn-sh \"exec ~/\.local/bin/$name\";[[:space:]]*\}" "$ROOT/niri/config.kdl" ||
    fail "niri 绑定使用可展开的 spawn-sh：$name"
  pass "niri 绑定使用可展开的 spawn-sh：$name"
  awk -F '\t' -v src="local/bin/$name" -v dst="~/.local/bin/$name" \
    '$1 == src && $2 == dst && $3 == "user" {found=1} END {exit !found}' "$ROOT/MANIFEST.tsv" ||
    fail "绑定脚本在 MANIFEST 中：$name"
  resolved=$(HOME="$capture_home" sh -c "command -v ~/.local/bin/$name") || fail "shell 能解析绑定命令：$name"
  assert_eq "$capture_home/.local/bin/$name" "$resolved" "shell 能解析绑定命令：$name"
done

# 兜底：以后再加 spawn "xxx" 时，命令必须在系统 PATH 里，否则键位会静默失效
while read -r cmd; do
  [[ -n "$cmd" ]] || continue
  PATH=/usr/local/sbin:/usr/local/bin:/usr/bin command -v -- "$cmd" >/dev/null 2>&1 ||
    fail "spawn 引用的 $cmd 必须在系统 PATH（否则改用 spawn-sh 展开 ~）"
  pass "spawn 引用的 $cmd 在系统 PATH"
done < <(sed -n 's/.*{[[:space:]]*spawn "\([^"]*\)".*/\1/p' "$ROOT/niri/config.kdl" | sort -u)

# 选区必须走 niri 截图 UI：grim+slurp 是实时画面，不冻结
for file in local/bin/screenshot-annotate local/bin/ocr-region; do
  grep -q 'niri msg action screenshot' "$ROOT/$file" || fail "使用 niri 截图 UI（冻结画面）：$file"
  pass "使用 niri 截图 UI：$file"
  if grep -v '^[[:space:]]*#' "$ROOT/$file" | grep -q 'slurp'; then
    fail "不再用 slurp 选区（不冻结）：$file"
  fi
  pass "不再用 slurp 选区：$file"
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
  img="$tmp/ocr.png"
  magick -size 640x140 xc:white -pointsize 42 -fill black -annotate +30+85 'FLAG ocr region test' "$img"
  out=$(tesseract "$img" - -l chi_sim+eng --psm 6 2>/dev/null) || fail 'tesseract 能处理测试图'
  grep -q 'FLAG' <<< "$out" || fail 'OCR 识别出英文关键字' "$out"
  pass 'OCR 识别出英文关键字'
else
  skip 'OCR 管线端到端' '缺少 tesseract 或 magick'
fi
