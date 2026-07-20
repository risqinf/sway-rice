#!/usr/bin/env bash
# =============================================================================
# CLIPBOARD HISTORY — wofi list, paste ke window aktif (khas r/unixporn)
# =============================================================================
set -euo pipefail

STYLE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sway-rice"
STYLE_CSS="$STYLE_DIR/clipboard.css"

command -v wofi >/dev/null || { notify-send "Clipboard" "wofi tidak terinstall"; exit 1; }
command -v cliphist >/dev/null || { notify-send "Clipboard" "cliphist tidak terinstall"; exit 1; }
command -v wl-copy >/dev/null || { notify-send "Clipboard" "wl-copy tidak terinstall"; exit 1; }
mkdir -p "$STYLE_DIR"

PANEL_BG="#0c0a12"
ACCENT="#ddc66e"

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
    margin: 10px 14px 8px 14px;
    padding: 8px 14px;
    border: 1px solid ${ACCENT}55;
    border-radius: 8px;
    background-color: #16121e;
    color: #e6dff0;
    caret-color: $ACCENT;
    font-size: 14px;
}

#input:focus {
    border-color: $ACCENT;
    outline: none;
    box-shadow: 0 0 0 2px ${ACCENT}33;
}

#outer-box { margin: 0 10px 10px 10px; }
#inner-box { margin: 0; }
#scroll    { margin: 0; }

#entry {
    padding: 8px 12px;
    margin: 3px 2px;
    border-radius: 8px;
    border: 2px solid transparent;
    background-color: transparent;
}

#entry:selected {
    background-color: #1e1830;
    border-color: $ACCENT;
}

#entry label {
    color: #e6dff0;
    font-size: 13px;
}

#entry:selected label {
    color: $ACCENT;
}

#img {
    margin-right: 8px;
    min-width: 64px;
    min-height: 64px;
}
CSS

WOFI_RUN="$HOME/.local/bin/wofi-run.sh"
[[ -x "$WOFI_RUN" ]] || { notify-send "Clipboard" "wofi-run.sh tidak ditemukan"; exit 1; }

CHOICE=$(cliphist list | \
    bash "$WOFI_RUN" clipboard \
         --dmenu \
         --style "$STYLE_CSS" \
         --prompt "Clipboard History" \
         --allow-images \
         --allow-markup \
         --columns 1 \
         --width 1000 \
         --height 800 \
         --image-size 64 \
         --cache-file /dev/null \
         --insensitive \
         2>/dev/null || true)

[[ -z "$CHOICE" ]] && exit 0

# Decode & copy ke clipboard
printf '%s' "$CHOICE" | cliphist decode | wl-copy

# Paste otomatis ke window aktif via wtype (opsional, install: wtype)
if command -v wtype >/dev/null; then
    sleep 0.1
    wtype -M ctrl -k v -m ctrl 2>/dev/null || true
fi

notify-send "Clipboard" "Disalin ke clipboard" 2>/dev/null || true
