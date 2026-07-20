#!/usr/bin/env bash

# Pastikan brightnessctl terinstal
if ! command -v brightnessctl >/dev/null 2>&1; then
    exit 0
fi

# Menu Kecerahan Menggunakan Rofi / Wofi
if command -v rofi >/dev/null; then
    CHOSEN=$(echo -e "100%\n75%\n50%\n25%" | rofi -dmenu -i -p "Kecerahan:")
elif command -v wofi >/dev/null; then
    CHOSEN=$(echo -e "100%\n75%\n50%\n25%" | wofi --show dmenu --prompt "Kecerahan:")
else
    exit 1
fi

if [[ -n "$CHOSEN" ]]; then
    # Jika user hanya memasukkan angka (misal "0"), tambahkan "%"
    if [[ "$CHOSEN" =~ ^[0-9]+$ ]]; then
        CHOSEN="${CHOSEN}%"
    fi
    brightnessctl set "$CHOSEN"
fi

