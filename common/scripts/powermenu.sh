#!/usr/bin/env bash

# Pilihan menu menggunakan Nerd Font Icons
if command -v rofi >/dev/null; then
    CHOSEN=$(echo -e "  Lock\n  Sleep\n  Restart\n  Poweroff\n  Logout" | rofi -dmenu -i -p "Aksi Sistem:")
elif command -v wofi >/dev/null; then
    CHOSEN=$(echo -e "  Lock\n  Sleep\n  Restart\n  Poweroff\n  Logout" | wofi --dmenu --prompt "Aksi Sistem:")
else
    exit 1
fi

# graceful_poweroff: exit sway dulu agar systemd user services (waybar, mako,
# portal, swww-daemon, dll.) berhenti dengan rapi via graphical-session.target,
# BARU poweroff. Tanpa ini systemd harus SIGKILL semua — salah satu penyebab
# shutdown/restart nge-hang menunggu proses yang tidak merespons SIGTERM.
graceful_poweroff() {
    if pgrep -x sway >/dev/null; then
        swaymsg exit 2>/dev/null || true
        # Tunggu maksimal 5 detik agar session turun bersih
        for _ in 1 2 3 4 5 6 7 8 9 10; do
            pgrep -x sway >/dev/null || break
            sleep 0.5
        done
    fi
    systemctl "$1"
}

case "$CHOSEN" in
    "  Lock")
        ~/.config/sway/lock.sh
        ;;
    "  Sleep")
        systemctl suspend
        ;;
    "  Restart")
        graceful_poweroff reboot
        ;;
    "  Poweroff")
        graceful_poweroff poweroff
        ;;
    "  Logout")
        swaymsg exit
        ;;
esac
