#!/bin/bash
# v5 wallpaper hook: copies the current Noctalia wallpaper into the SDDM theme.
# Env (set by noctalia): NOCTALIA_WALLPAPER_PATH, NOCTALIA_WALLPAPER_CONNECTOR
set -euo pipefail

DEST="/usr/share/sddm/themes/noctalia/Assets/background.png"
SRC="${NOCTALIA_WALLPAPER_PATH:-}"

if [[ -z "$SRC" || ! -f "$SRC" ]]; then
  SRC="$(noctalia msg wallpaper-get 2>/dev/null | head -n1 || true)"
fi

if [[ -z "$SRC" || ! -f "$SRC" ]]; then
  echo "No wallpaper found (NOCTALIA_WALLPAPER_PATH empty and wallpaper-get failed)" >&2
  exit 1
fi

cp -f -- "$SRC" "$DEST"
echo "SDDM wallpaper synced from $SRC"
