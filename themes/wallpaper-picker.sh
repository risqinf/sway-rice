#!/usr/bin/env bash
# =============================================================================
# WALLPAPER PICKER — wofi fullscreen center, preview besar rapi
# =============================================================================
set -euo pipefail
export PATH="$HOME/.cargo/bin:$PATH"

SWAY_RICE_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/sway-rice"
THEMES_DIR="$SWAY_RICE_HOME/themes"
STATE_FILE="$SWAY_RICE_HOME/state"
REGISTRY="${XDG_DATA_HOME:-$HOME/.local/share}/sway-rice/wallpapers"
STYLE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sway-rice"
STYLE_CSS="$STYLE_DIR/wallpaper-picker.css"
WOFI_RUN="$HOME/.local/bin/wofi-run.sh"

command -v wofi >/dev/null || { notify-send "Wallpaper Picker" "wofi tidak terinstall"; exit 1; }
[[ -x "$WOFI_RUN" ]] || { notify-send "Wallpaper Picker" "wofi-run.sh tidak ditemukan"; exit 1; }

THEME=$(cat "$STATE_FILE" 2>/dev/null || echo "raiden")
THEME_GALLERY="$THEMES_DIR/$THEME/wallpaper/gallery"

mkdir -p "$STYLE_DIR" "$REGISTRY"

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

# Wofi: 80% width, 85% height — hampir fullscreen, di tengah layar
WOFI_W=$(( SCREEN_W * 80 / 100 ))
WOFI_H=$(( SCREEN_H * 85 / 100 ))
IMG_SIZE=$(( WOFI_W * 65 / 100 ))

# Center position
X_OFF=$(( (SCREEN_W - WOFI_W) / 2 ))
Y_OFF=$(( (SCREEN_H - WOFI_H) / 2 ))

# --- CSS: rapi, gambar dominan ---
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

/* Label: badge type saja, bukan nama file */
#entry label {
    color: #8a8299;
    font-size: 13px;
    padding: 8px 8px 4px 8px;
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

# --- Kumpulkan wallpaper ---
declare -A CHOICE_TO_PATH
MENU_LINES=()

# 1. Registry
for dir in "$REGISTRY"/*/; do
    [[ -f "$dir/meta.ini" ]] || continue
    id=$(basename "$dir")
    name=$(grep -oP '^name=\K.*' "$dir/meta.ini" 2>/dev/null || echo "$id")
    wtype=$(grep -oP '^type=\K.*' "$dir/meta.ini" 2>/dev/null || echo "unknown")
    source=$(grep -oP '^source=\K.*' "$dir/meta.ini" 2>/dev/null || echo "")
    asset="$dir/asset"

    preview=""
    if [[ "$wtype" == "static" && -f "$asset" ]]; then
        preview="$asset"
    elif [[ "$wtype" == "live" && -f "$source" ]]; then
        thumb="$STYLE_DIR/thumbs/$id.png"
        mkdir -p "$STYLE_DIR/thumbs"
        if [[ ! -f "$thumb" && -x "$(command -v ffmpeg)" ]]; then
            ffmpeg -y -i "$source" -vf "select=eq(n\,0),scale=640:360" -frames:v 1 "$thumb" >/dev/null 2>&1 || true
        fi
        [[ -f "$thumb" ]] && preview="$thumb"
    fi

    badge="[${wtype^^}]"
    label="$badge $name"
    key="registry:$id"
    CHOICE_TO_PATH["$key"]="$source"

    if [[ -n "$preview" ]]; then
        MENU_LINES+=("img:$preview:text:$label")
    else
        MENU_LINES+=("$label")
    fi
done

# 2. Theme gallery
if [[ -d "$THEME_GALLERY" ]]; then
    while IFS= read -r -d '' img; do
        base=$(basename "$img")
        name="${base%.*}"
        key="theme:$img"
        CHOICE_TO_PATH["$key"]="$img"
        MENU_LINES+=("img:$img:text:[THEME] $name")
    done < <(find "$THEME_GALLERY" -maxdepth 1 -type f \
        \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
        -print0 | sort -z)
fi

[[ ${#MENU_LINES[@]} -eq 0 ]] && {
    notify-send "Wallpaper Picker" "Tidak ada wallpaper ditemukan"
    exit 1
}

CHOICE=$(printf '%s\n' "${MENU_LINES[@]}" | \
    bash "$WOFI_RUN" wallpaper \
         --dmenu \
         --style "$STYLE_CSS" \
         --prompt "Wallpaper — $THEME" \
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
[[ -z "$LABEL" ]] && LABEL="$CHOICE"

FOUND=""
for key in "${!CHOICE_TO_PATH[@]}"; do
    if [[ "$key" == registry:* ]]; then
        id="${key#registry:}"
        dir="$REGISTRY/$id"
        name=$(grep -oP '^name=\K.*' "$dir/meta.ini" 2>/dev/null || echo "$id")
        wtype=$(grep -oP '^type=\K.*' "$dir/meta.ini" 2>/dev/null || echo "unknown")
        expected="[${wtype^^}] $name"
    elif [[ "$key" == theme:* ]]; then
        img="${key#theme:}"
        base=$(basename "$img")
        name="${base%.*}"
        expected="[THEME] $name"
    fi
    if [[ "$LABEL" == "$expected" ]]; then
        FOUND="${CHOICE_TO_PATH[$key]}"
        break
    fi
done

[[ -z "$FOUND" ]] && exit 0

# Apply
if [[ -x "$HOME/.local/bin/wallpaper-apply.sh" ]]; then
    bash "$HOME/.local/bin/wallpaper-apply.sh" apply "$FOUND"
else
    cp -f "$FOUND" "$HOME/wallpaper/desktop-wallpaper.png"
    if command -v swww >/dev/null && pgrep -x swww-daemon >/dev/null; then
        swww img "$HOME/wallpaper/desktop-wallpaper.png" --transition-type fade --transition-duration 1 2>/dev/null || true
    fi
    if command -v matugen >/dev/null; then
        matugen image "$HOME/wallpaper/desktop-wallpaper.png" --prefer saturation >/dev/null 2>&1 || true
    fi
    systemctl --user restart waybar mako >/dev/null 2>&1 || true
    pkill -USR1 kitty 2>/dev/null || true
fi

notify-send "Wallpaper" "$(basename "$FOUND") diterapkan" 2>/dev/null || true
