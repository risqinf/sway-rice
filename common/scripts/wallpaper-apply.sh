#!/usr/bin/env bash
# =============================================================================
# WALLPAPER APPLY — unified static/live wallpaper engine (scalable)
# =============================================================================
# Support:
#   - Static image (png/jpg/jpeg/webp) → swww
#   - Live video (mp4/webm/mkv/gif)   → mpvpaper (fallback: swww gif)
#   - Future: html, shader, etc. — tambah handler di apply_live()
#
# Registry: ~/.local/share/sway-rice/wallpapers/
#   Setiap wallpaper = folder dengan file 'meta.ini' + asset
#   meta.ini:
#     type=static|live
#     name=My Wallpaper
#     source=/path/or/url
# =============================================================================
set -euo pipefail

REGISTRY="${XDG_DATA_HOME:-$HOME/.local/share}/sway-rice/wallpapers"
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sway-rice"
STATE_FILE="$STATE_DIR/wallpaper-state"
DEST_STATIC="$HOME/wallpaper/desktop-wallpaper.png"
mkdir -p "$REGISTRY" "$STATE_DIR" "$(dirname "$DEST_STATIC")"

# --- Helper: cek type dari extension ---
_wallpaper_type() {
    local file="$1"
    case "${file,,}" in
        *.mp4|*.webm|*.mkv|*.avi|*.mov|*.gif) echo "live" ;;
        *.png|*.jpg|*.jpeg|*.webp|*.bmp) echo "static" ;;
        *) echo "unknown" ;;
    esac
}

# --- Apply static wallpaper ---
apply_static() {
    local img="$1"
    cp -f "$img" "$DEST_STATIC"

    # Stop live wallpaper dulu
    pkill -f "mpvpaper" 2>/dev/null || true

    # Start swww-daemon (mungkin di-stop saat live)
    systemctl --user start swww-daemon >/dev/null 2>&1 || true
    sleep 0.3

    # swww apply
    if command -v swww >/dev/null && pgrep -x swww-daemon >/dev/null; then
        TRANSITIONS=("simple" "fade" "left" "right" "wipe" "grow" "center")
        TR=${TRANSITIONS[$RANDOM % ${#TRANSITIONS[@]}]}
        swww img "$DEST_STATIC" --transition-type "$TR" --transition-pos 0.5,0.5 \
             --transition-fps 144 --transition-duration 1 2>/dev/null || true
    fi

    # Adaptive colors
    if command -v matugen >/dev/null; then
        matugen image "$DEST_STATIC" --prefer saturation >/dev/null 2>&1 || true
    fi

    # Save state
    printf 'type=static\nsource=%s\n' "$img" > "$STATE_FILE"

    # Reload UI
    systemctl --user restart waybar mako >/dev/null 2>&1 || true
    # Start swww-daemon kembali untuk static wallpaper
    systemctl --user start swww-daemon >/dev/null 2>&1 || true
    pkill -USR1 kitty 2>/dev/null || true
}

# --- Apply live wallpaper (video) ---
apply_live() {
    local video="$1"

    if command -v mpvpaper >/dev/null; then
        # Stop swww-daemon — mpvpaper butuh layer background yang sama
        systemctl --user stop swww-daemon >/dev/null 2>&1 || pkill -x swww-daemon 2>/dev/null || true
        pkill -x mpvpaper 2>/dev/null || true
        sleep 0.5
        # mpvpaper: loop, no audio, vsync, all outputs
        # nohup + disown: proses tetap hidup setelah script exit
        nohup mpvpaper -o "loop no-audio vid=1" '*' "$video" >/dev/null 2>&1 &
        disown
    elif command -v swww >/dev/null && [[ "${video,,}" == *.gif ]]; then
        # Fallback: swww bisa GIF animasi
        cp -f "$video" "$DEST_STATIC.gif" 2>/dev/null || true
        swww img "$video" --transition-type none 2>/dev/null || true
    else
        notify-send "Wallpaper" "mpvpaper tidak terinstall — live wallpaper tidak tersedia"
        return 1
    fi

    # Adaptive colors dari frame pertama (jika ffmpeg ada)
    if command -v ffmpeg >/dev/null; then
        local thumb="$STATE_DIR/live-thumb.png"
        ffmpeg -y -i "$video" -vf "select=eq(n\,0),scale=1920:1080" -frames:v 1 "$thumb" >/dev/null 2>&1 || true
        [[ -f "$thumb" ]] && matugen image "$thumb" --prefer saturation >/dev/null 2>&1 || true
    fi

    # Save state
    printf 'type=live\nsource=%s\n' "$video" > "$STATE_FILE"

    systemctl --user restart waybar mako >/dev/null 2>&1 || true
    pkill -USR1 kitty 2>/dev/null || true
}

# --- Restore dari state (dipanggil saat login) ---
restore() {
    [[ -f "$STATE_FILE" ]] || return 0
    local type source
    type=$(grep -oP '^type=\K.*' "$STATE_FILE")
    source=$(grep -oP '^source=\K.*' "$STATE_FILE")

    [[ -f "$source" ]] || return 0

    case "$type" in
        static) apply_static "$source" ;;
        live)   apply_live "$source" ;;
    esac
}

# --- List registered wallpapers ---
list() {
    local dir
    for dir in "$REGISTRY"/*/; do
        [[ -f "$dir/meta.ini" ]] || continue
        local name type source
        name=$(grep -oP '^name=\K.*' "$dir/meta.ini" 2>/dev/null || basename "$dir")
        type=$(grep -oP '^type=\K.*' "$dir/meta.ini" 2>/dev/null || echo "unknown")
        source=$(grep -oP '^source=\K.*' "$dir/meta.ini" 2>/dev/null || echo "")
        printf '%s\t%s\t%s\t%s\n' "$(basename "$dir")" "$name" "$type" "$source"
    done
}

# --- Register wallpaper ke registry ---
register() {
    local file="$1"
    local name="${2:-$(basename "${file%.*}")}"
    local type
    type=$(_wallpaper_type "$file")

    [[ "$type" == "unknown" ]] && { echo "Unsupported: $file" >&2; return 1; }

    local id
    id=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
    local dir="$REGISTRY/$id"
    mkdir -p "$dir"

    # Copy/symlink asset
    if [[ -f "$file" ]]; then
        ln -sf "$(realpath "$file")" "$dir/asset"
    else
        echo "File not found: $file" >&2
        return 1
    fi

    cat > "$dir/meta.ini" <<EOF
name=$name
type=$type
source=$file
registered=$(date -Iseconds)
EOF

    echo "Registered: $id ($type)"
}

# --- Main ---
case "${1:-}" in
    restore)  restore ;;
    list)     list ;;
    register) register "${2:?file}" "${3:-}" ;;
    apply)
        file="${2:?file}"
        type=$(_wallpaper_type "$file")
        case "$type" in
            static) apply_static "$file" ;;
            live)   apply_live "$file" ;;
            *)      echo "Unknown type: $file" >&2; exit 1 ;;
        esac
        ;;
    *)
        # Direct apply (backward compatible)
        file="$1"
        [[ -f "$file" ]] || { echo "Usage: $0 <file|restore|list|register>" >&2; exit 1; }
        type=$(_wallpaper_type "$file")
        case "$type" in
            static) apply_static "$file" ;;
            live)   apply_live "$file" ;;
            *)      echo "Unknown type: $file" >&2; exit 1 ;;
        esac
        ;;
esac
