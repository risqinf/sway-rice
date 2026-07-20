#!/usr/bin/env bash
# =====================================================================
# POST-INSTALL CONFIGURATION SCRIPT
# Script ini untuk konfigurasi tambahan setelah install.sh selesai
# Khususnya untuk xdg-desktop-portal-wlr dan konfigurasi environment
# =====================================================================

set -uo pipefail

c_reset="\033[0m"; c_red="\033[31m"; c_green="\033[32m"; c_yellow="\033[33m"; c_blue="\033[34m"
info()  { echo -e "${c_blue}[INFO]${c_reset} $*"; }
ok()    { echo -e "${c_green}[ OK ]${c_reset} $*"; }
warn()  { echo -e "${c_yellow}[PERINGATAN]${c_reset} $*"; }
err()   { echo -e "${c_red}[GAGAL]${c_reset} $*"; }

# =====================================================================
# Configure XDG Desktop Portal untuk Wayland
# =====================================================================
configure_xdg_portal() {
    info "=== Konfigurasi XDG Desktop Portal untuk Wayland ==="
    
    # Buat direktori konfigurasi
    mkdir -p "$HOME/.config/xdg-desktop-portal"
    
    # Buat file konfigurasi untuk xdg-desktop-portal-wlr
    # Nama file harus portals.conf (default fallback) karena xdg-desktop-portal
    # mencari: 1) ${XDG_CURRENT_DESKTOP}-portals.conf  2) portals.conf
    cat > "$HOME/.config/xdg-desktop-portal/portals.conf" << 'EOF'
[preferred]
default=wlr;gtk
org.freedesktop.impl.portal.Screenshot=wlr
org.freedesktop.impl.portal.ScreenCast=wlr
org.freedesktop.impl.portal.FileChooser=gtk
EOF
    rm -f "$HOME/.config/xdg-desktop-portal/sway-portals.conf" 2>/dev/null || true
    ok "File konfigurasi xdg-desktop-portal dibuat (portals.conf)"
    
    # Buat environment variables untuk sway
    if ! grep -q "XDG_CURRENT_DESKTOP" "$HOME/.config/sway/config" 2>/dev/null; then
        cat >> "$HOME/.config/sway/config" << 'EOF'

# XDG Desktop Portal Environment
exec systemctl --user import-environment DISPLAY WAYLAND_DISPLAY SWAYSOCK
exec hash dbus-update-activation-environment 2>/dev/null && \
     dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY SWAYSOCK
EOF
        ok "Environment variables ditambahkan ke sway config"
    fi
    
    # Restart xdg-desktop-portal jika sudah berjalan
    if systemctl --user is-active xdg-desktop-portal >/dev/null 2>&1; then
        systemctl --user restart xdg-desktop-portal
        ok "xdg-desktop-portal direstart"
    fi
}

# =====================================================================
# Configure Pipewire untuk audio
# =====================================================================
configure_pipewire() {
    info "=== Konfigurasi Pipewire untuk audio ==="
    
    if ! command -v pipewire >/dev/null 2>&1; then
        warn "pipewire tidak terinstall, skip konfigurasi"
        return 1
    fi
    
    # Enable & start pipewire services
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user enable --now pipewire.socket 2>/dev/null || true
        systemctl --user enable --now pipewire-pulse.socket 2>/dev/null || true
        systemctl --user enable --now wireplumber.service 2>/dev/null || true
        ok "Pipewire services diaktifkan"
    fi
}

# =====================================================================
# Setup default applications
# =====================================================================
setup_default_apps() {
    info "=== Setup default applications ==="
    
    # mimeapps.list adalah file, bukan direktori
    touch "$HOME/.config/mimeapps.list"
    
    # Set default terminal
    if command -v kitty >/dev/null 2>&1; then
        xdg-settings set default-terminal-emulator kitty.desktop 2>/dev/null || true
        ok "Kitty diset sebagai terminal default"
    fi
    
    # Set default file manager
    if command -v nautilus >/dev/null 2>&1; then
        xdg-mime default org.gnome.Nautilus.desktop inode/directory 2>/dev/null || true
        ok "Nautilus diset sebagai file manager default"
    elif command -v cosmic-files >/dev/null 2>&1; then
        xdg-mime default com.system76.CosmicFiles.desktop inode/directory 2>/dev/null || true
        ok "Cosmic Files diset sebagai file manager default"
    fi
}

# =====================================================================
# Configure GTK theme for consistency
# =====================================================================
configure_gtk_theme() {
    info "=== Konfigurasi GTK theme ==="
    
    mkdir -p "$HOME/.config/gtk-3.0"
    mkdir -p "$HOME/.config/gtk-4.0"
    
    # Basic GTK settings
    cat > "$HOME/.config/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Adwaita
gtk-font-name=Cantarell 11
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
EOF
    
    cp "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"
    ok "GTK theme dikonfigurasi"
}

# =====================================================================
# Create screenshot directory
# =====================================================================
setup_screenshot_dir() {
    info "=== Setup direktori screenshot ==="
    
    mkdir -p "$HOME/Pictures/Screenshots"
    ok "Direktori screenshot dibuat: ~/Pictures/Screenshots"
}

# =====================================================================
# Configure fish shell integration
# =====================================================================
configure_fish_integration() {
    if ! command -v fish >/dev/null 2>&1; then
        return 0
    fi
    
    info "=== Konfigurasi fish shell integration ==="
    
    # Add fish to /etc/shells if not already there
    if ! grep -q "$(command -v fish)" /etc/shells 2>/dev/null; then
        echo "$(command -v fish)" | sudo tee -a /etc/shells >/dev/null
        ok "Fish shell ditambahkan ke /etc/shells"
    fi
    
    # Suggest changing default shell
    if [[ "$SHELL" != *"fish"* ]]; then
        echo
        warn "Fish shell terinstall tapi belum diset sebagai default shell"
        info "Untuk menggunakan fish sebagai default shell, jalankan:"
        info "  chsh -s \$(which fish)"
        echo
    fi
}

# =====================================================================
# Test screen sharing setup
# =====================================================================
test_screenshare_setup() {
    info "=== Test screen sharing setup ==="
    
    if ! command -v xdg-desktop-portal-wlr >/dev/null 2>&1; then
        warn "xdg-desktop-portal-wlr tidak terinstall"
        warn "Screen sharing di Discord/browser tidak akan berfungsi"
        return 1
    fi
    
    ok "xdg-desktop-portal-wlr terinstall"
    
    # Check if config file exists
    if [[ -f "$HOME/.config/xdg-desktop-portal/portals.conf" ]]; then
        ok "Konfigurasi portal ditemukan"
    else
        warn "Konfigurasi portal tidak ditemukan"
    fi
    
    # Check if portal service can start
    if systemctl --user status xdg-desktop-portal >/dev/null 2>&1; then
        ok "xdg-desktop-portal service berjalan"
    else
        warn "xdg-desktop-portal service tidak berjalan"
        info "Service akan start otomatis saat login ke Sway"
    fi
}

# =====================================================================
# Deploy systemd --user services (waybar, mako, swww-daemon, graphical-session)
# =====================================================================
# Layanan ini terikat ke graphical-session.target sehingga systemd mengelola
# lifecycle mereka — mencegah orphan process yang menahan shutdown/restart.
deploy_systemd_user_services() {
    info "=== Deploy systemd --user services ==="

    local repo_dir
    repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local src="$repo_dir/common/systemd-user"
    local dst="$HOME/.config/systemd/user"

    if [[ ! -d "$src" ]]; then
        warn "Folder $src tidak ditemukan, skip"
        return 1
    fi

    mkdir -p "$dst"
    local svc
    for svc in "$src"/*.service; do
        [[ -f "$svc" ]] || continue
        cp "$svc" "$dst/"
        ok "Disalin: $(basename "$svc")"
    done

    systemctl --user daemon-reload
    systemctl --user enable swww-daemon.service waybar.service mako.service 2>/dev/null || true
    ok "systemd --user services diaktifkan"
}

# =====================================================================
# Deploy environment.d (XDG vars untuk user session)
# =====================================================================
deploy_environment_d() {
    info "=== Deploy environment.d ==="
    mkdir -p "$HOME/.config/environment.d"
    # Jangan set XDG_SESSION_TYPE di sini — itu di-set oleh login manager
    # dan bervariasi per session (wayland untuk sway, tty untuk SSH).
    cat > "$HOME/.config/environment.d/sway.conf" << 'EOF'
XDG_CURRENT_DESKTOP=sway
XDG_SESSION_DESKTOP=sway
MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORM=wayland
QT_WAYLAND_DISABLE_WINDOWDECORATION=1
SDL_VIDEODRIVER=wayland
CLUTTER_BACKEND=wayland
_JAVA_AWT_WM_NONREPARENTING=1
EOF
    ok "environment.d/sway.conf dibuat"
}

# =====================================================================
# Deploy sway-run wrapper + user session file (tanpa sudo)
# =====================================================================
# gtkgreet memprioritaskan ~/.local/share/wayland-sessions/ di atas
# /usr/share/wayland-sessions/, sehingga user bisa menimpa Exec=sway
# bawaan dengan wrapper yang mengekspor env lengkap sebelum sway start.
deploy_sway_run_wrapper() {
    info "=== Deploy sway-run wrapper & user session file ==="

    local repo_dir
    repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if [[ -f "$repo_dir/common/local-bin/sway-run" ]]; then
        mkdir -p "$HOME/.local/bin"
        cp "$repo_dir/common/local-bin/sway-run" "$HOME/.local/bin/sway-run"
        chmod +x "$HOME/.local/bin/sway-run"
        ok "sway-run → ~/.local/bin/sway-run"
    fi

    if [[ -f "$repo_dir/common/wayland-sessions/sway-user.desktop" ]]; then
        mkdir -p "$HOME/.local/share/wayland-sessions"
        # %h tidak diekspansi oleh desktop entry spec — ganti dengan $HOME literal
        sed "s|%h|$HOME|g" "$repo_dir/common/wayland-sessions/sway-user.desktop" \
            > "$HOME/.local/share/wayland-sessions/sway-user.desktop"
        ok "sway-user.desktop → ~/.local/share/wayland-sessions/"
    fi
}

# =====================================================================
# Main
# =====================================================================
main() {
    echo
    info "===== POST-INSTALL CONFIGURATION ====="
    echo

    configure_xdg_portal
    configure_pipewire
    setup_default_apps
    configure_gtk_theme
    setup_screenshot_dir
    configure_fish_integration
    deploy_systemd_user_services
    deploy_environment_d
    deploy_sway_run_wrapper
    test_screenshare_setup

    echo
    ok "===== POST-INSTALL CONFIGURATION SELESAI ====="
    echo
    info "Untuk menerapkan semua perubahan:"
    info "  1. Logout dari session saat ini"
    info "  2. Login kembali via greetd"
    info "  3. Test screen sharing di Discord/browser"
    echo
}

main "$@"
