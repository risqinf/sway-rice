#!/usr/bin/env bash
# =============================================================================
# APP LAUNCHER — wofi drun fullscreen, ikon besar, panel gelap (khas r/unixporn)
# =============================================================================
set -euo pipefail

STYLE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sway-rice"
STYLE_CSS="$STYLE_DIR/app-launcher.css"
SWAY_RICE_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/sway-rice"
THEMES_DIR="$SWAY_RICE_HOME/themes"
THEME=$(cat "$SWAY_RICE_HOME/state" 2>/dev/null || echo "raiden")

command -v wofi >/dev/null || { notify-send "Launcher" "wofi tidak terinstall"; exit 1; }
mkdir -p "$STYLE_DIR"

_accent() {
    local live="$HOME/.config/sway/colors.conf"
    local hex
    hex=$(grep -oP 'client\.focused\s+\K#[0-9a-fA-F]{6}' "$live" 2>/dev/null | head -1)
    [[ -n "$hex" ]] && echo "$hex" && return
    echo "#9370DB"
}
ACCENT=$(_accent)
PANEL_BG="#0c0a12"

cat > "$STYLE_CSS" <<CSS
* {
    font-family: "JetBrainsMono Nerd Font", monospace;
}

window {
    margin: 0;
    border: 2px solid $ACCENT;
    background-color: ${PANEL_BG};
    color: #cfc8dc;
}

#input {
    margin: 12px 16px 8px 16px;
    padding: 10px 16px;
    border: 1px solid ${ACCENT}55;
    border-radius: 8px;
    background-color: #16121e;
    color: #e6dff0;
    caret-color: $ACCENT;
    font-size: 16px;
}

#input:focus {
    border-color: $ACCENT;
    outline: none;
    box-shadow: 0 0 0 2px ${ACCENT}33;
}

#outer-box { margin: 0 12px 12px 12px; }
#inner-box {
    margin: 0;
    orientation: vertical;
}
#scroll    { margin: 0; }

#entry {
    padding: 10px 12px;
    margin: 4px 2px;
    border-radius: 10px;
    border: 2px solid transparent;
    background-color: transparent;
}

#entry:selected {
    background-color: #1e1830;
    border-color: $ACCENT;
    box-shadow: 0 0 14px ${ACCENT}44;
}

#entry label {
    color: #e6dff0;
    font-size: 16px;
    font-weight: 500;
    padding-left: 10px;
}

#entry:selected label {
    color: $ACCENT;
}

/* Ikon aplikasi besar */
#img {
    margin: 0;
    min-width: 48px;
    min-height: 48px;
}
CSS

WOFI_RUN="$HOME/.local/bin/wofi-run.sh"
[[ -x "$WOFI_RUN" ]] || { notify-send "Launcher" "wofi-run.sh tidak ditemukan"; exit 1; }

exec bash "$WOFI_RUN" launcher \
     --show drun \
     --style "$STYLE_CSS" \
     --prompt "Cari Aplikasi" \
     --allow-images \
     --allow-markup \
     --columns 1 \
     --width 1920 \
     --height 1080 \
     --image-size 48 \
     --insensitive \
     --cache-file /dev/null \
     2>/dev/null || true
