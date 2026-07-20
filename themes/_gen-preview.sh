#!/usr/bin/env bash
# =============================================================================
# PREVIEW GENERATOR — mockup desktop 16:9 per tema
# Layout: wallpaper penuh + waybar strip di atas (warna aksen tema) + label tema
# Output: ~/.cache/sway-rice/previews/<tema>.png
# =============================================================================
set -euo pipefail

SWAY_RICE_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/sway-rice"
THEMES_DIR="$SWAY_RICE_HOME/themes"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sway-rice/previews"

# Ukuran preview 16:9 — match image-size wofi untuk ketajaman maksimal
W=1920
H=1080
WAYBAR_H=96

command -v magick >/dev/null || { echo "ImageMagick (magick) tidak terinstall"; exit 1; }

# Cari font yang tersedia (fallback jika JetBrains tidak ada)
FONT_PATH=""
for f in \
    "$HOME/.local/share/fonts/JetBrainsMonoNLNerdFontMono-Bold.ttf" \
    "$HOME/.local/share/fonts/JetBrainsMonoNerdFontPropo-Bold.ttf" \
    "$HOME/.local/share/fonts/JetBrainsMonoNLNerdFontPropo-Bold.ttf"; do
    [[ -f "$f" ]] && FONT_PATH="$f" && break
done

mkdir -p "$CACHE_DIR"

# Ambil warna aksen tema dari gtkgreet.css
get_theme_accent() {
    local css="$1/config/greetd/gtkgreet.css"
    local accent="#9370DB"
    if [[ -f "$css" ]]; then
        local rgba
        rgba=$(grep -oP 'rgba\(\K\d+,\s*\d+,\s*\d+(?=,\s*0\.45\))' "$css" 2>/dev/null | head -1 || true)
        if [[ -n "$rgba" ]]; then
            local r g b
            r=$(echo "$rgba" | cut -d, -f1 | tr -d ' ')
            g=$(echo "$rgba" | cut -d, -f2 | tr -d ' ')
            b=$(echo "$rgba" | cut -d, -f3 | tr -d ' ')
            accent=$(printf '#%02x%02x%02x' "$r" "$g" "$b")
        fi
    fi
    echo "$accent"
}

gen_preview() {
    local theme_dir="$1"
    local tid=$(basename "$theme_dir")
    local wp=""
    for ext in png jpg jpeg webp; do
        [[ -f "$theme_dir/wallpaper/desktop-wallpaper.$ext" ]] && \
            wp="$theme_dir/wallpaper/desktop-wallpaper.$ext" && break
    done
    [[ -f "$wp" ]] || return 1

    local accent=$(get_theme_accent "$theme_dir")
    local out="$CACHE_DIR/$tid.png"

    # Skip jika cache lebih baru dari wallpaper
    if [[ -f "$out" && "$out" -nt "$wp" ]]; then
        echo "$out"
        return 0
    fi

    # Posisi & ukuran elemen waybar
    local label_x=36
    local label_y=$(( (WAYBAR_H - 50) / 2 ))
    local dot_y=$(( WAYBAR_H / 2 ))
    local dot_r=15
    local dot1_x=$(( W - 60 ))
    local dot2_x=$(( W - 120 ))
    local dot3_x=$(( W - 180 ))

    # Build argumen font (kalau ada)
    local -a font_args=()
    if [[ -n "$FONT_PATH" ]]; then
        font_args=(-font "$FONT_PATH")
    fi

    # Komposisi: wallpaper full + waybar strip + label + 3 dot di kanan
    magick "$wp" \
        -resize "${W}x${H}^" -gravity center -extent "${W}x${H}" \
        \( -size "${W}x${WAYBAR_H}" xc:"$accent" \) \
        -gravity north -compose over -composite \
        "${font_args[@]}" -pointsize 42 -fill '#FFFFFF' \
        -gravity northwest -annotate "+${label_x}+${label_y}" "  $tid" \
        -fill '#FFFFFF' -gravity northeast \
        -draw "circle ${dot1_x},${dot_y} ${dot1_x},$(( dot_y - dot_r ))" \
        -draw "circle ${dot2_x},${dot_y} ${dot2_x},$(( dot_y - dot_r ))" \
        -draw "circle ${dot3_x},${dot_y} ${dot3_x},$(( dot_y - dot_r ))" \
        "$out" 2>/dev/null

    echo "$out"
}

if [[ $# -ge 1 ]]; then
    gen_preview "$THEMES_DIR/$1"
else
    for d in "$THEMES_DIR"/*/; do
        [[ -d "$d/config" ]] || continue
        gen_preview "$d" >/dev/null
    done
    echo "Previews di: $CACHE_DIR"
fi
