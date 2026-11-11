#!/usr/bin/env bash
# Shared helpers; each case runs in its own bash process.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo '用法：在 test/cases/*.sh 中 source test/lib/base-test.sh' >&2
  exit 2
fi

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

pass() { printf 'ok - %s\n' "$1"; }
skip() { printf 'ok - %s # SKIP %s\n' "$1" "$2"; }
fail() {
  [[ -z "${2:-}" ]] || printf '%s\n' "$2" >&2
  printf 'not ok - %s\n' "$1"
  exit 1
}
require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "缺少命令：$1"
}
assert_eq() {
  [[ "$1" == "$2" ]] || fail "$3" "期望：$1
实际：$2"
  pass "$3"
}
assert_file() {
  [[ -f "$1" ]] || fail "$2" "文件不存在：$1"
  pass "$2"
}
assert_exec() {
  [[ -f "$1" && -x "$1" ]] || fail "$2" "文件不存在或不可执行：$1"
  pass "$2"
}
