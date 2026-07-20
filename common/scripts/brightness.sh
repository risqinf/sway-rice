#!/usr/bin/env bash
# Universal brightness control — auto-detect backlight device
# Priority: brightnessctl (universal) → sysfs fallback (auto-detect device)

# Cari device backlight aktif
find_backlight_device() {
    local dir="/sys/class/backlight"
    # Cek semua device yang ada
    for dev in "$dir"/*/; do
        [[ -f "${dev}max_brightness" && -f "${dev}brightness" ]] && {
            basename "$dev"
            return 0
        }
    done
    return 1
}

if [[ "$1" == "up" || "$1" == "down" ]]; then
    # Method 1: brightnessctl (paling universal, tidak perlu sudo)
    if command -v brightnessctl >/dev/null 2>&1; then
        case "$1" in
            up)   brightnessctl set 5%+ ;;
            down) brightnessctl set 5%- ;;
        esac
        exit 0
    fi

    # Method 2: sysfs fallback (auto-detect device)
    DEVICE=$(find_backlight_device) || {
        echo "Error: Tidak ditemukan backlight device di /sys/class/backlight/" >&2
        exit 1
    }
    BACKLIGHT_DIR="/sys/class/backlight/$DEVICE"
    MAX=$(cat "$BACKLIGHT_DIR/max_brightness")
    CUR=$(cat "$BACKLIGHT_DIR/brightness")
    STEP=$(( MAX / 20 ))
    [[ $STEP -lt 1 ]] && STEP=1

    case "$1" in
        up)   NEW=$((CUR + STEP)); [[ $NEW -gt $MAX ]] && NEW=$MAX ;;
        down) NEW=$((CUR - STEP)); [[ $NEW -lt 0 ]] && NEW=0 ;;
    esac

    echo "$NEW" | sudo tee "$BACKLIGHT_DIR/brightness" > /dev/null
fi
