#!/usr/bin/env bash
# THEME SWITCHER — simple wofi launcher
# Baca daftar tema dari ~/.config/sway-rice/themes/

SWAY_RICE_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/sway-rice"
THEME_DIR="$SWAY_RICE_HOME/themes"
STATE_FILE="$SWAY_RICE_HOME/state"
SWITCHER="$HOME/.local/bin/theme-switch.sh"

command -v wofi >/dev/null || { echo "wofi required"; exit 1; }
[[ -x "$SWITCHER" ]] || { echo "theme-switch.sh tidak ditemukan di $SWITCHER"; exit 1; }
[[ -d "$THEME_DIR" ]] || { echo "Tema tidak terinstal di $THEME_DIR — jalankan install.sh dulu"; exit 1; }

THEMES=()
for d in "$THEME_DIR"/*/; do
    [[ -d "$d/config" ]] && THEMES+=("$(basename "$d")")
done

[[ ${#THEMES[@]} -eq 0 ]] && { echo "No themes"; exit 1; }

ACTIVE=$(cat "$STATE_FILE" 2>/dev/null || echo "raiden")

WOFI_RUN="$HOME/.local/bin/wofi-run.sh"
[[ -x "$WOFI_RUN" ]] || { echo "wofi-run.sh tidak ditemukan"; exit 1; }

# Build menu
CHOICE=$(
    for t in "${THEMES[@]}"; do
        if [[ "$t" == "$ACTIVE" ]]; then
            printf "• %s (aktif)\n" "$t"
        else
            printf "  %s\n" "$t"
        fi
    done | bash "$WOFI_RUN" theme-simple --dmenu --prompt "Pilih Tema" --show-icons --icon-size 32 --width 420 2>/dev/null
)

# Strip bullet dan label "(aktif)"
NEW=$(printf '%s' "$CHOICE" | sed -e 's/^[• ]*//' -e 's/ (aktif)$//' | tr -d '\n')

if [[ -n "$NEW" && "$NEW" != "$ACTIVE" ]]; then
    bash "$SWITCHER" "$NEW"
else
    echo "No change"
fi
