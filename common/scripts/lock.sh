#!/usr/bin/env bash
# Lock screen dengan blurred screenshot background — classic r/unixporn look.
# Fallback ke solid color bila grim/imagemagick tidak tersedia.

LOCK_IMG="/tmp/swaylock-bg-$$.png"
WALLPAPER="${HOME}/wallpaper/desktop-wallpaper.png"

cleanup() { rm -f "$LOCK_IMG"; }
trap cleanup EXIT

if command -v grim >/dev/null && command -v convert >/dev/null; then
    # Screenshot semua output, lalu blur kuat + sedikit darken
    grim "$LOCK_IMG"
    convert "$LOCK_IMG" -blur 0x12 -modulate 70,100 "$LOCK_IMG"
elif [ -f "$WALLPAPER" ] && command -v convert >/dev/null; then
    convert "$WALLPAPER" -blur 0x14 -modulate 65,100 "$LOCK_IMG"
fi

if [ -f "$LOCK_IMG" ]; then
    exec swaylock -i "$LOCK_IMG" --scale fill
else
    exec swaylock -c 0f0e14
fi
