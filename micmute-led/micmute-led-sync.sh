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

sync_led() {
    local volume
    # The default source can be temporarily unavailable during a restart or device switch.
    volume=$(LC_ALL=C wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null) || return 0
    case "$volume" in
        *'[MUTED]'*) write_led 1 ;;
        *) write_led 0 ;;
    esac
}

# Initial sync
sync_led

# Subscribe to PipeWire source events
LC_ALL=C pactl subscribe | while IFS= read -r line; do
    case "$line" in
        *' on source #'*) sync_led ;;
        *' on server'*) sync_led ;;
    esac
done

# Any end to the event stream requires a fresh subscription.
printf '%s\n' 'micmute-led-sync: PulseAudio event stream closed' >&2
exit 1
