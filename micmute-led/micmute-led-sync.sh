#!/bin/bash
# Sync ThinkPad micmute LED with PipeWire default source mute state
# Requires: user in "input" group, udev rule for LED permissions
# Runs as systemd user service

LED="/sys/class/leds/platform::micmute/brightness"
TRIGGER="/sys/class/leds/platform::micmute/trigger"

# Set trigger to none (disable kernel auto-control)
if [ -w "$TRIGGER" ]; then
    echo none > "$TRIGGER"
elif command -v sg &>/dev/null; then
    sg input -c "echo none > '$TRIGGER'" 2>/dev/null
fi

# Determine write helper: direct or via sg
WRITE_CMD=""
if [ -w "$LED" ]; then
    WRITE_CMD="direct"
elif command -v sg &>/dev/null && sg input -c "test -w '$LED'" 2>/dev/null; then
    WRITE_CMD="sg"
else
    echo "micmute-led-sync: cannot write $LED (check input group + udev rule)" >&2
    exit 1
fi

write_led() {
    if [ "$WRITE_CMD" = "direct" ]; then
        printf '%s' "$1" > "$LED"
    else
        sg input -c "printf '%s' '$1' > '$LED'"
    fi
}

get_mute() {
    wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q '\[MUTED\]' && echo 1 || echo 0
}

sync_led() {
    write_led "$(get_mute)"
}

# Initial sync
sync_led

# Subscribe to PipeWire source events
pactl subscribe 2>/dev/null | while read -r line; do
    # Match source state changes (mute toggle, default source switch)
    if echo "$line" | grep -qE "on source #|on server"; then
        sync_led
    fi
done
