#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/base-test.sh"

require_command grep
patterns='-----BEGIN [A-Z ]*PRIVATE KEY-----|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|xox[bpoa]-[A-Za-z0-9-]{10,}|sk-[A-Za-z0-9]{32,}|AKIA[0-9A-Z]{16}'
scan_file() {
  local file="$1" matches status
  # Print locations only, so a failing log does not disclose the secret itself.
  if matches=$(grep -InE -- "$patterns" "$file"); then
    lines=$(printf '%s\n' "$matches" | cut -d: -f1 | paste -sd, -)
    fail 'MANIFEST 文件没有高特征密钥' "${file#"$ROOT"/}:$lines 命中密钥特征（内容不打印）"
  else
    status=$?
    [[ "$status" -eq 1 ]] || fail '密钥扫描可读取文件' "$file (grep exit $status)"
  fi
}
while IFS=$'\t' read -r src dst mode desc extra; do
  case "${src:-}" in ''|'#'*|archive/*) continue ;; esac
  [[ -e "$ROOT/$src" ]] || continue
  if [[ -d "$ROOT/$src" ]]; then
    while IFS= read -r -d '' file; do
      scan_file "$file"
    done < <(find "$ROOT/$src" -type f ! -path "$ROOT/archive/*" -print0)
  else
    scan_file "$ROOT/$src"
  fi
  pass "密钥扫描：$src"
done < "$ROOT/MANIFEST.tsv"
