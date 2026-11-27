#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/base-test.sh"

tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/led"
export MICMUTE_TEST_DIR="$tmp"

# Exercise the service script using regular files in place of the hardware LED.
sed 's|/sys/class/leds/platform::micmute|${MICMUTE_TEST_DIR}/led|g' \
  "$ROOT/micmute-led/micmute-led-sync.sh" > "$tmp/sync.sh"
: > "$tmp/led/trigger"

cat > "$tmp/bin/wpctl" <<'STUB'
#!/usr/bin/env bash
[[ "$*" == 'get-volume @DEFAULT_AUDIO_SOURCE@' && "$LC_ALL" == C ]] || exit 64
printf '%s\n' "$(cat "$MICMUTE_TEST_DIR/led/brightness")" >> "$MICMUTE_TEST_DIR/queries"
[[ "${MICMUTE_TEST_DISCONNECT:-0}" == 0 ]] || exit 1
case "$(wc -l < "$MICMUTE_TEST_DIR/queries")" in
  1|3) printf 'Volume: 0.45\n' ;;
  2) printf 'Volume: 0.45 [MUTED]\n' ;;
  *) exit 65 ;;
esac
STUB

cat > "$tmp/bin/pactl" <<'STUB'
#!/usr/bin/env bash
[[ "$*" == subscribe && "$LC_ALL" == C ]] || exit 64
printf '%s\n' "Event 'change' on sink #1" "Event 'change' on source #2" "Event 'change' on server #0"
[[ "${MICMUTE_TEST_DISCONNECT:-0}" == 0 ]]
STUB
chmod +x "$tmp/bin/"{wpctl,pactl}

printf '1' > "$tmp/led/brightness"
status=0
MICMUTE_TEST_DISCONNECT=0 LC_ALL=POSIX PATH="$tmp/bin:$PATH" bash "$tmp/sync.sh" 2> "$tmp/stderr" || status=$?
assert_eq 1 "$status" '音频事件流结束时返回失败，以便 systemd 重新订阅'
assert_eq $'1\n0\n1' "$(cat "$tmp/queries")" '初始化及麦克风和服务器事件同步 LED，忽略扬声器事件'
assert_eq 0 "$(cat "$tmp/led/brightness")" '取消静音后关闭 LED'
grep -q 'event stream closed' "$tmp/stderr" || fail '记录事件流结束原因'
pass '记录事件流结束原因'

printf '1' > "$tmp/led/brightness"
: > "$tmp/queries"
status=0
MICMUTE_TEST_DISCONNECT=1 PATH="$tmp/bin:$PATH" bash "$tmp/sync.sh" 2> "$tmp/stderr" || status=$?
assert_eq 1 "$status" '音频事件订阅异常时返回失败'
assert_eq $'1\n1\n1' "$(cat "$tmp/queries")" '查询失败期间保持 LED 原状态'
assert_eq 1 "$(cat "$tmp/led/brightness")" '没有麦克风状态时保留最后一次显示'
