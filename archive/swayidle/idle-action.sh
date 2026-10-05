#!/bin/bash
# Idle action script for swayidle
# Usage: idle-action.sh <action>
#   lock    - lock screen
#   idle    - screen off + (on battery: suspend)
#   resume  - screen on + restart noctalia + re-lock
#   sleep   - lock before system sleep

is_on_ac() {
    [ -f /sys/class/power_supply/AC/online ] && [ "$(cat /sys/class/power_supply/AC/online)" = "1" ]
}

log() {
    logger -t idle-action "$*"
}

case "$1" in
    lock)
        log "Locking screen"
        qs -c noctalia-shell ipc call lockScreen lock
        ;;
    idle)
        log "Powering off monitors"
        niri msg action power-off-monitors
        if ! is_on_ac; then
            log "On battery, suspending"
            systemctl suspend
        fi
        ;;
    resume)
        log "Resume: powering on monitors"
        niri msg action power-on-monitors 2>/dev/null
        # Wait for monitors and wl_output to fully restore
        sleep 1.5
        # Restart noctalia-shell to reinitialize Background/Overview delegates.
        # power-off-monitors destroys wl_output, which breaks noctalia's layer shell.
        log "Resume: restarting noctalia-shell"
        pkill -x qs 2>/dev/null
        sleep 1.5
        qs -c noctalia-shell -d &
        # Wait for noctalia to fully load, then re-lock for security
        log "Resume: waiting for noctalia to load, then re-locking"
        sleep 3
        qs -c noctalia-shell ipc call lockScreen lock
        log "Resume: done"
        ;;
    sleep)
        log "Sleep: locking screen"
        qs -c noctalia-shell ipc call lockScreen lock
        ;;
esac
