#!/usr/bin/env bash
# =============================================================================
# THEME SWITCHER — wofi fullscreen center, preview besar rapi
# =============================================================================
set -euo pipefail

SWAY_RICE_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/sway-rice"
THEMES_DIR="$SWAY_RICE_HOME/themes"
STATE_FILE="$SWAY_RICE_HOME/state"
SWITCHER="$HOME/.local/bin/theme-switch.sh"
STYLE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sway-rice"
STYLE_CSS="$STYLE_DIR/theme-switcher.css"
WOFI_RUN="$HOME/.local/bin/wofi-run.sh"

command -v wofi >/dev/null || { notify-send "Theme Switcher" "wofi tidak terinstall"; exit 1; }
[[ -x "$SWITCHER" ]] || { notify-send "Theme Switcher" "theme-switch.sh tidak ditemukan"; exit 1; }
[[ -d "$THEMES_DIR" ]] || { notify-send "Theme Switcher" "Tema tidak terinstal di $THEMES_DIR"; exit 1; }
[[ -x "$WOFI_RUN" ]] || { notify-send "Theme Switcher" "wofi-run.sh tidak ditemukan"; exit 1; }

mkdir -p "$STYLE_DIR"

PREVIEW_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/sway-rice/previews"
GEN_PREVIEW="$HOME/.local/bin/_gen-preview.sh"
[[ -x "$GEN_PREVIEW" ]] && bash "$GEN_PREVIEW" >/dev/null 2>&1 || true

ACTIVE=$(cat "$STATE_FILE" 2>/dev/null || echo "raiden")

_accent() {
    local live="$HOME/.config/sway/colors.conf"
    local hex
    hex=$(grep -oP 'client\.focused\s+\K#[0-9a-fA-F]{6}' "$live" 2>/dev/null | head -1)
    [[ -n "$hex" ]] && echo "$hex" && return
    echo "#9370DB"
}

ACCENT=$(_accent)
PANEL_BG="#0c0a12"

# Responsive sizing — scale dari resolusi layar
read -r SCREEN_W SCREEN_H <<< "$(swaymsg -t get_outputs 2>/dev/null | python3 -c "
import json,sys
for o in json.load(sys.stdin):
    if o.get('focused') or o.get('active'):
        r = o.get('rect', {})
        print(r.get('width', 1920), r.get('height', 1080))
        break
" 2>/dev/null || echo "1920 1080")"

# Wofi: 80% width, 85% height — hampir fullscreen tapi masih ada context
WOFI_W=$(( SCREEN_W * 80 / 100 ))
WOFI_H=$(( SCREEN_H * 85 / 100 ))
IMG_SIZE=$(( WOFI_W * 65 / 100 ))

# Center position: x = (screen - wofi) / 2, y = (screen - wofi) / 2
X_OFF=$(( (SCREEN_W - WOFI_W) / 2 ))
Y_OFF=$(( (SCREEN_H - WOFI_H) / 2 ))

# --- CSS: rapi, gambar dominan, label di bawah ---
cat > "$STYLE_CSS" <<CSS
* {
    font-family: "JetBrainsMono Nerd Font", monospace;
}

window {
    margin: 0;
    border: none;
    background-color: ${PANEL_BG};
    color: #cfc8dc;
}

#input {
    margin: 12px 16px;
    padding: 8px 16px;
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

#outer-box {
    margin: 0 12px 12px 12px;
    padding: 0;
}

#inner-box {
    margin: 0;
    padding: 0;
    orientation: vertical;
}

#scroll {
    margin: 0;
    padding: 0;
}

#entry {
    padding: 8px;
    margin: 6px 4px;
    border: none;
    border-radius: 10px;
    background-color: #14101c;
}

#entry:selected {
    background-color: #1e1830;
    border: none;
    box-shadow: 0 0 0 2px $ACCENT, 0 0 24px ${ACCENT}44;
}

#entry label {
    color: #cfc8dc;
    font-size: 18px;
    font-weight: 700;
    padding: 10px 8px 6px 8px;
}

#entry:selected label {
    color: $ACCENT;
}

#img {
    margin: 0;
    padding: 0;
    border: none;
    border-radius: 8px;
}
CSS

# --- Kumpulkan tema & preview ---
declare -A LABEL_TO_ID
MENU_LINES=()
while IFS= read -r -d '' dir; do
    tid=$(basename "$dir")
    [[ -d "$dir/config" ]] || continue

    preview="$PREVIEW_CACHE/$tid.png"
    if [[ ! -f "$preview" ]]; then
        preview=""
        for ext in png jpg jpeg webp; do
            p="$dir/wallpaper/desktop-wallpaper.$ext"
            [[ -f "$p" ]] && preview="$p" && break
        done
    fi

    label="$tid"
    [[ "$tid" == "$ACTIVE" ]] && label="$tid  •  aktif"
    LABEL_TO_ID["$label"]="$tid"

    if [[ -n "$preview" ]]; then
        MENU_LINES+=("img:$preview:text:$label")
    else
        MENU_LINES+=("$label")
    fi
done < <(find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

[[ ${#MENU_LINES[@]} -eq 0 ]] && { notify-send "Theme Switcher" "Tidak ada tema ditemukan"; exit 1; }

CHOICE=$(printf '%s\n' "${MENU_LINES[@]}" | \
    bash "$WOFI_RUN" theme \
         --dmenu \
         --style "$STYLE_CSS" \
         --prompt "Pilih Tema" \
         --allow-images \
         --allow-markup \
         --columns 1 \
         --width "$WOFI_W" \
         --height "$WOFI_H" \
         --xoffset "$X_OFF" \
         --yoffset "$Y_OFF" \
         --define image_size="$IMG_SIZE" \
         --cache-file /dev/null \
         2>/dev/null || true)

[[ -z "$CHOICE" ]] && exit 0

LABEL=$(printf '%s' "$CHOICE" | sed -E 's|^img:[^:]+:text:||')
TID="${LABEL_TO_ID[$LABEL]:-}"

if [[ -n "$TID" && "$TID" != "$ACTIVE" ]]; then
    bash "$SWITCHER" "$TID"
fi
