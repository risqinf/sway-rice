#!/usr/bin/env bash
# =============================================================================
# THEME LIB — helper untuk theme discovery & metadata (scalable)
# =============================================================================
# Sumber: ~/.config/sway-rice/themes/<tid>/
#   theme.ini   — metadata (name, author, variant, accent, preview, features)
#   config/     — sway, waybar, kitty, mako, dll.
#   wallpaper/  — gallery + desktop-wallpaper
# =============================================================================

THEMES_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sway-rice/themes"
STATE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/sway-rice/state"

# --- List semua theme (auto-discovery) ---
theme_list() {
    local dir tid
    for dir in "$THEMES_DIR"/*/; do
        [[ -d "$dir/config" ]] || continue
        tid=$(basename "$dir")
        echo "$tid"
    done | sort
}

# --- Get metadata field ---
theme_meta() {
    local tid="$1" field="$2" default="${3:-}"
    local ini="$THEMES_DIR/$tid/theme.ini"
    [[ -f "$ini" ]] || { echo "$default"; return; }
    grep -oP "^${field}=\K.*" "$ini" 2>/dev/null | head -1 || echo "$default"
}

# --- Get display name (fallback: tid) ---
theme_display_name() {
    theme_meta "$1" "display_name" "$1"
}

# --- Get accent color (fallback: dari live colors.conf) ---
theme_accent() {
    local tid="$1"
    local accent
    accent=$(theme_meta "$tid" "accent" "")
    [[ -n "$accent" ]] && echo "$accent" && return

    # Fallback: live colors.conf
    local live="$HOME/.config/sway/colors.conf"
    grep -oP 'client\.focused\s+\K#[0-9a-fA-F]{6}' "$live" 2>/dev/null | head -1 || echo "#9370DB"
}

# --- Get preview path ---
theme_preview() {
    local tid="$1"
    local preview
    preview=$(theme_meta "$tid" "preview" "wallpaper/desktop-wallpaper.png")

    # Try cache first
    local cache="${XDG_CACHE_HOME:-$HOME/.cache}/sway-rice/previews/$tid.png"
    [[ -f "$cache" ]] && echo "$cache" && return

    # Try theme dir
    local p="$THEMES_DIR/$tid/$preview"
    [[ -f "$p" ]] && echo "$p" && return

    # Try any wallpaper
    for ext in png jpg jpeg webp; do
        p="$THEMES_DIR/$tid/wallpaper/desktop-wallpaper.$ext"
        [[ -f "$p" ]] && echo "$p" && return
    done

    echo ""
}

# --- Validate theme structure ---
theme_validate() {
    local tid="$1"
    local dir="$THEMES_DIR/$tid"
    local errors=()

    [[ -d "$dir" ]] || { echo "Theme not found: $tid"; return 1; }
    [[ -d "$dir/config" ]] || errors+=("missing config/")
    [[ -d "$dir/wallpaper" ]] || errors+=("missing wallpaper/")
    [[ -f "$dir/theme.ini" ]] || errors+=("missing theme.ini (optional but recommended)")

    if [[ ${#errors[@]} -gt 0 ]]; then
        printf 'Theme %s issues:\n' "$tid"
        printf '  - %s\n' "${errors[@]}"
        return 1
    fi
    echo "Theme $tid: OK"
}

# --- Current theme ---
theme_current() {
    cat "$STATE_FILE" 2>/dev/null || echo "raiden"
}
