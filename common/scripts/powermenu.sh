#!/usr/bin/env bash

# Pilihan menu menggunakan Nerd Font Icons
if command -v rofi >/dev/null; then
    CHOSEN=$(echo -e "  Lock\n  Sleep\n  Restart\n  Poweroff\n  Logout" | rofi -dmenu -i -p "Aksi Sistem:")
elif command -v wofi >/dev/null; then
    CHOSEN=$(echo -e "  Lock\n  Sleep\n  Restart\n  Poweroff\n  Logout" | wofi --dmenu --prompt "Aksi Sistem:")
else
    exit 1
fi

# CATATAN PENTING soal reboot/poweroff:
# JANGAN `swaymsg exit` dulu sebelum `systemctl reboot/poweroff`. Script ini
# adalah proses ANAK dari sway — begitu sway exit, script ikut terbunuh
# SEBELUM sempat menjalankan systemctl. Akibatnya poweroff/reboot batal dan
# greetd cuma memunculkan layar login lagi (seperti logout).
#
# Cukup panggil `systemctl reboot/poweroff` langsung: systemd + logind yang
# akan menurunkan graphical session (semua unit PartOf=graphical-session.target)
# dengan rapi, lalu reboot/poweroff. Ini juga butuh session ter-registrasi
# sebagai "active" di logind (disediakan oleh pam_systemd via /etc/pam.d/greetd)
# supaya polkit mengizinkan tanpa password.
case "$CHOSEN" in
    "  Lock")
        ~/.config/sway/lock.sh
        ;;
    "  Sleep")
        systemctl suspend
        ;;
    "  Restart")
        systemctl reboot
        ;;
    "  Poweroff")
        systemctl poweroff
        ;;
    "  Logout")
        swaymsg exit
        ;;
esac
