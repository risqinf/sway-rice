#!/usr/bin/env bash
# THEME SWITCHER — fast, no delay, preserves workspace
# Waybar config/style/colors are NOT touched — matugen handles adaptive colors.
#
# Lokasi tema: ~/.config/sway-rice/themes/<tema>/{config,wallpaper}
# Dikelola oleh install.sh — repo sumber boleh dihapus setelah instalasi.

SWAY_RICE_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/sway-rice"
THEME_DIR="$SWAY_RICE_HOME/themes"
STATE_FILE="$SWAY_RICE_HOME/state"

die() { echo "[GAGAL] $*" >&2; exit 1; }
info() { echo "[+] $*"; }
ok() { echo "[OK] $*"; }

list_themes() {
    [[ -d "$THEME_DIR" ]] || return 0
    for d in "$THEME_DIR"/*/; do
        [[ -d "$d/config" ]] && basename "$d"
    done | sort
}

current_theme() {
    [[ -f "$STATE_FILE" ]] && cat "$STATE_FILE" || echo "raiden"
}

get_next_theme() {
    local current="$1" themes_array=() current_idx=0
    while IFS= read -r t; do themes_array+=("$t"); done <<< "$(list_themes)"
    [[ ${#themes_array[@]} -eq 0 ]] && echo "raiden" && return
    for i in "${!themes_array[@]}"; do
        [[ "${themes_array[$i]}" == "$current" ]] && current_idx=$i && break
    done
    echo "${themes_array[$(( (current_idx + 1) % ${#themes_array[@]} ))]}"
}

get_prev_theme() {
    local current="$1" themes_array=() current_idx=0
    while IFS= read -r t; do themes_array+=("$t"); done <<< "$(list_themes)"
    [[ ${#themes_array[@]} -eq 0 ]] && echo "raiden" && return
    for i in "${!themes_array[@]}"; do
        [[ "${themes_array[$i]}" == "$current" ]] && current_idx=$i && break
    done
    echo "${themes_array[$(( (current_idx - 1 + ${#themes_array[@]}) % ${#themes_array[@]} ))]}"
}

apply_theme() {
    local theme="$1"
    local theme_dir="$THEME_DIR/$theme"
    [[ ! -d "$theme_dir/config" ]] && die "Tema '$theme' tidak ditemukan di $THEME_DIR"

    # Save current workspace NUMBER sebelum ada perubahan apapun.
    # Pakai `num` (bukan `name`) karena nama workspace pakai hiragana
    # ("1. いち") — restore by name bisa gagal match setelah reload.
    local saved_ws
    saved_ws=$(swaymsg -t get_workspaces 2>/dev/null | python3 -c "
import json,sys
for w in json.load(sys.stdin):
    if w.get('focused'): print(w['num']); break
" 2>/dev/null || echo "")

    info "Menerapkan tema: $theme"
    mkdir -p "$HOME/.config/sway" "$HOME/.config/kitty" "$HOME/.config/mako" "$HOME/wallpaper"

    # === Copy theme-specific files ===
    cp -f "$theme_dir/config/sway/config" "$HOME/.config/sway/config" 2>/dev/null || true
    cp -fL "$theme_dir/config/sway/powermenu.sh" "$HOME/.config/sway/" 2>/dev/null || true
    cp -fL "$theme_dir/config/sway/gui-recorder.sh" "$HOME/.config/sway/" 2>/dev/null || true
    cp -fL "$theme_dir/config/sway/brightness-menu.sh" "$HOME/.config/sway/" 2>/dev/null || true
    cp -fL "$theme_dir/config/sway/brightness.sh" "$HOME/.config/sway/" 2>/dev/null || true
    chmod +x "$HOME/.config/sway/"*.sh 2>/dev/null || true
    cp -f "$theme_dir/config/mako/config" "$HOME/.config/mako/config" 2>/dev/null || true
    cp -rf "$theme_dir/config/kitty/"* "$HOME/.config/kitty/" 2>/dev/null || true
    cp -f "$theme_dir/wallpaper/desktop-wallpaper.png" "$HOME/wallpaper/" 2>/dev/null || true
    cp -f "$theme_dir/wallpaper/fastfetch.png" "$HOME/wallpaper/" 2>/dev/null || true

    # === Greetd: update wallpaper & style login mengikuti tema ===
    # Pakai helper root-owned dgn aturan sudoers NOPASSWD terbatas (dipasang
    # oleh install.sh). Ini membuat wallpaper login greetd ikut ganti tema
    # tanpa perlu password. Fallback ke `sudo -n cp` bila helper belum ada.
    if [[ -x /usr/local/bin/sway-rice-apply-greetd-theme ]]; then
        timeout 5 sudo -n /usr/local/bin/sway-rice-apply-greetd-theme "$theme" 2>/dev/null || true
    else
        timeout 2 sudo -n cp -f "$theme_dir/config/greetd/config.toml" /etc/greetd/config.toml 2>/dev/null || true
        timeout 2 sudo -n cp -f "$theme_dir/config/greetd/sway-config" /etc/greetd/sway-config 2>/dev/null || true
        timeout 2 sudo -n cp -f "$theme_dir/config/greetd/gtkgreet.css" /etc/greetd/gtkgreet.css 2>/dev/null || true
        timeout 2 sudo -n cp -f "$theme_dir/wallpaper/desktop-wallpaper.png" /etc/greetd/wallpaper/login-wallpaper.png 2>/dev/null || true
    fi

    # === Cursor theme per character ===
    local cursor_theme
    case "$theme" in
        raiden) cursor_theme="RaidenShogun" ;;
        hutao)  cursor_theme="HuTao" ;;
        furina) cursor_theme="Furina" ;;
        xiao)   cursor_theme="Xiao" ;;
        kazuha) cursor_theme="Kazuha" ;;
        *)      cursor_theme="Kazuha" ;;
    esac

    # Update cursor in sway config
    if grep -q "xcursor_theme" "$HOME/.config/sway/config" 2>/dev/null; then
        sed -i "s/seat seat0 xcursor_theme .*/seat seat0 xcursor_theme $cursor_theme 28/" "$HOME/.config/sway/config"
    else
        echo "seat seat0 xcursor_theme $cursor_theme 28" >> "$HOME/.config/sway/config"
    fi

    # Update GTK cursor settings
    for gtk_dir in "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"; do
        if [[ -f "$gtk_dir/settings.ini" ]]; then
            sed -i "s/gtk-cursor-theme-name=.*/gtk-cursor-theme-name=$cursor_theme/" "$gtk_dir/settings.ini"
            sed -i "s/gtk-cursor-theme-size=.*/gtk-cursor-theme-size=28/" "$gtk_dir/settings.ini"
        fi
    done
    gsettings set org.gnome.desktop.interface cursor-theme "$cursor_theme" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-size 28 2>/dev/null || true

    mkdir -p "$SWAY_RICE_HOME"
    echo "$theme" > "$STATE_FILE"

    # === Animation function for theme transition ===
    apply_theme_animation() {
        local img="$1"
        local transitions=("simple" "fade" "left" "right" "wipe" "grow" "center" "outer" "random")
        local transition=${transitions[$RANDOM % ${#transitions[@]}]}
        
        if command -v swww >/dev/null && pgrep -x swww-daemon >/dev/null; then
            swww img "$img" \
                --transition-type "$transition" \
                --transition-pos 0.5,0.5 \
                --transition-fps 144 \
                --transition-duration 1 \
                --transition-bezier 0.5,0,0.5,1 \
                2>/dev/null || true
        fi
    }

    # === Wallpaper + adaptive colors ===
    export PATH="$HOME/.cargo/bin:$PATH"
    if command -v swww >/dev/null && pgrep -x swww-daemon >/dev/null; then
        apply_theme_animation "$HOME/wallpaper/desktop-wallpaper.png"
    fi
    if command -v matugen >/dev/null && [[ -f "$HOME/wallpaper/desktop-wallpaper.png" ]]; then
        matugen image "$HOME/wallpaper/desktop-wallpaper.png" --prefer saturation >/dev/null 2>&1 || true
    fi

    # === Reload sway (this restarts waybar via exec_always in sway config) ===
    swaymsg reload 2>/dev/null || true

    # Restore workspace focus — pakai number agar match hiragana labels
    if [[ -n "$saved_ws" ]]; then
        sleep 0.5
        swaymsg "workspace number $saved_ws" 2>/dev/null || true
    fi

    # Restart mako
    pkill -x mako 2>/dev/null || true
    mako & disown

    # Reload kitty colors
    pkill -USR1 kitty 2>/dev/null || true

    notify-send "Tema" "$theme diterapkan (cursor: $cursor_theme)" 2>/dev/null || true
    ok "Tema $theme berhasil diterapkan!"
}

if [[ $# -lt 1 ]]; then
    echo "Penggunaan: $0 <nama_tema|next|prev>"
    list_themes
    exit 1
fi

case "$1" in
    next) apply_theme "$(get_next_theme "$(current_theme)")" ;;
    prev) apply_theme "$(get_prev_theme "$(current_theme)")" ;;
    *)    apply_theme "$1" ;;
esac
