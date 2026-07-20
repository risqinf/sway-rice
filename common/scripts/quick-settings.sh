#!/usr/bin/env bash
# =============================================================================
# QUICK SETTINGS — toggle WiFi/BT/NightLight/DND (khas r/unixporn)
# =============================================================================
set -euo pipefail

STYLE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sway-rice"
STYLE_CSS="$STYLE_DIR/quick-settings.css"

command -v wofi >/dev/null || { notify-send "Quick Settings" "wofi tidak terinstall"; exit 1; }
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
#inner-box {
    margin: 0;
    orientation: vertical;
}
#scroll    { margin: 0; }

#entry {
    padding: 12px 14px;
    margin: 4px 2px;
    border-radius: 10px;
    border: 2px solid #241f30;
    background-color: #14101c;
}

#entry:selected {
    background-color: #1e1830;
    border-color: $ACCENT;
    box-shadow: 0 0 14px ${ACCENT}44;
}

#entry label {
    color: #e6dff0;
    font-size: 15px;
    font-weight: 500;
}

#entry:selected label {
    color: $ACCENT;
}
CSS

# Status helpers
_wifi_status() {
    if nmcli radio wifi 2>/dev/null | grep -q "enabled"; then echo "ON"; else echo "OFF"; fi
}
_bt_status() {
    if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then echo "ON"; else echo "OFF"; fi
}
_dnd_status() {
    if makoctl mode 2>/dev/null | grep -q "do-not-disturb"; then echo "ON"; else echo "OFF"; fi
}
_nl_status() {
    if pgrep -x wlsunset >/dev/null || pgrep -x gammastep >/dev/null; then echo "ON"; else echo "OFF"; fi
}
_airplane_status() {
    if nmcli radio all 2>/dev/null | grep -qv "enabled"; then echo "ON"; else echo "OFF"; fi
}

MENU="📶  WiFi          [$(_wifi_status)]
🔵  Bluetooth     [$(_bt_status)]
🌙  Night Light   [$(_nl_status)]
🔕  Do Not Disturb [$(_dnd_status)]
✈️  Airplane Mode  [$(_airplane_status)]
─────────────────────────────
🔊  Volume Mixer
📡  Network Connections
🎨  Appearance Settings
⚙️  System Settings"

WOFI_RUN="$HOME/.local/bin/wofi-run.sh"
[[ -x "$WOFI_RUN" ]] || { notify-send "Quick Settings" "wofi-run.sh tidak ditemukan"; exit 1; }

CHOICE=$(printf '%s\n' "$MENU" | \
    bash "$WOFI_RUN" settings \
         --dmenu \
         --style "$STYLE_CSS" \
         --prompt "Quick Settings" \
         --allow-markup \
         --columns 1 \
         --width 800 \
         --height 600 \
         --cache-file /dev/null \
         --insensitive \
         2>/dev/null || true)

[[ -z "$CHOICE" ]] && exit 0

case "$CHOICE" in
    *WiFi*)
        if [[ "$(_wifi_status)" == "ON" ]]; then
            nmcli radio wifi off
        else
            nmcli radio wifi on
        fi
        notify-send "WiFi" "Toggled" 2>/dev/null || true
        ;;
    *Bluetooth*)
        if [[ "$(_bt_status)" == "ON" ]]; then
            bluetoothctl power off >/dev/null 2>&1 &
        else
            bluetoothctl power on >/dev/null 2>&1 &
        fi
        notify-send "Bluetooth" "Toggled" 2>/dev/null || true
        ;;
    *Night\ Light*)
        if [[ "$(_nl_status)" == "ON" ]]; then
            pkill -x wlsunset 2>/dev/null || pkill -x gammastep 2>/dev/null || true
        else
            if command -v wlsunset >/dev/null; then
                wlsunset -l -6.2 -L 106.8 >/dev/null 2>&1 &
            elif command -v gammastep >/dev/null; then
                gammastep -l -6.2:106.8 >/dev/null 2>&1 &
            else
                notify-send "Night Light" "wlsunset/gammastep tidak terinstall" 2>/dev/null || true
            fi
        fi
        ;;
    *Do\ Not\ Disturb*)
        if [[ "$(_dnd_status)" == "ON" ]]; then
            makoctl mode -r do-not-disturb >/dev/null 2>&1 || true
        else
            makoctl mode -a do-not-disturb >/dev/null 2>&1 || true
        fi
        notify-send "DND" "Toggled" 2>/dev/null || true
        ;;
    *Airplane*)
        if [[ "$(_airplane_status)" == "ON" ]]; then
            nmcli radio all on
        else
            nmcli radio all off
        fi
        notify-send "Airplane Mode" "Toggled" 2>/dev/null || true
        ;;
    *Volume\ Mixer*)
        if command -v pavucontrol >/dev/null; then
            pavucontrol &
        else
            kitty -e pulsemixer &
        fi
        ;;
    *Network\ Connections*)
        nm-connection-editor &
        ;;
    *Appearance*)
        kitty -e bash ~/.local/bin/theme-switcher.sh &
        ;;
    *System\ Settings*)
        if command -v gnome-control-center >/dev/null; then
            gnome-control-center &
        else
            kitty -e nmtui &
        fi
        ;;
esac
