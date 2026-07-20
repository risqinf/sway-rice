#!/usr/bin/env bash
# =====================================================================
# XDG-DESKTOP-PORTAL-WLR INSTALLER — Rocky Linux 10 (from source)
# =====================================================================
# Rocky Linux 10 tidak menyediakan xdg-desktop-portal-wlr di repo resmi
# maupun EPEL. Script ini build manual dari source.
#
# Komponen yang dibuild:
#   1. xdg-desktop-portal (parent portal daemon)
#   2. xdg-desktop-portal-wlr (wlroots screen sharing backend)
#
# Penggunaan:
#   chmod +x install-xdg-wlr.sh
#   ./install-xdg-wlr.sh
# =====================================================================
set -euo pipefail

# =====================================================================
# DETEKSI USER TUJUAN (target user untuk deploy config & systemctl --user)
# =====================================================================
REAL_USER="${SUDO_USER:-${LOGNAME:-${USER:-$(id -un)}}}"
if [[ "$REAL_USER" == "root" ]]; then
    REAL_USER="$(stat -c '%U' "${BASH_SOURCE[0]}")"
    if [[ "$REAL_USER" == "root" ]]; then
        err "Tidak bisa mendeteksi user tujuan. Jalankan sebagai user biasa."
        exit 1
    fi
fi

systemctl_user() {
    sudo -u "$REAL_USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$REAL_USER")" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$REAL_USER")/bus" \
        systemctl --user "$@"
}

LOG_FILE="/tmp/xdg-wlr-install-$UID.log"
BUILD_ROOT="$(mktemp -d /tmp/xdg-wlr-build.XXXXXX)"
: > "$LOG_FILE"

# Warna
c_reset="\033[0m"; c_red="\033[31m"; c_green="\033[32m"
c_yellow="\033[33m"; c_blue="\033[34m"; c_cyan="\033[36m"

info()  { echo -e "${c_blue}[INFO]${c_reset} $*"  | tee -a "$LOG_FILE"; }
ok()    { echo -e "${c_green}[ OK ]${c_reset} $*" | tee -a "$LOG_FILE"; }
warn()  { echo -e "${c_yellow}[WARN]${c_reset} $*" | tee -a "$LOG_FILE"; }
err()   { echo -e "${c_red}[GAGAL]${c_reset} $*"   | tee -a "$LOG_FILE"; }
banner(){ echo -e "${c_cyan}$*${c_reset}" | tee -a "$LOG_FILE"; }

cleanup() { rm -rf "$BUILD_ROOT"; }
trap cleanup EXIT

# _has_bin <name> — cek binary di PATH + lokasi umum
_has_bin() {
    local bin="$1"
    command -v "$bin" >/dev/null 2>&1 && return 0
    for p in /usr/local/bin /usr/local/libexec /usr/libexec /usr/bin; do
        [[ -x "$p/$bin" ]] && return 0
    done
    return 1
}

# _find_bin <name> — return path aktual dari binary
_find_bin() {
    local bin="$1"
    command -v "$bin" 2>/dev/null && return
    for p in /usr/local/bin /usr/local/libexec /usr/libexec /usr/bin; do
        if [[ -x "$p/$bin" ]]; then echo "$p/$bin"; return; fi
    done
}

# =====================================================================
# 1. VALIDASI SISTEM
# =====================================================================
validate_system() {
    banner "============================================"
    banner " XDG-DESKTOP-PORTAL-WLR INSTALLER"
    banner " Target: Rocky Linux 10 (from source)"
    banner "============================================"
    echo

    if [[ ! -f /etc/os-release ]]; then
        err "Tidak bisa mendeteksi OS (/etc/os-release tidak ada)."
        exit 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release
    local distro_id="${ID:-unknown}"
    local id_like="${ID_LIKE:-}"

    if [[ "$distro_id" != "rocky" && "$distro_id" != "almalinux" && \
          "$distro_id" != "rhel" && "$distro_id" != "centos" && \
          "$id_like" != *rhel* && "$id_like" != *fedora* ]]; then
        warn "Script ini ditujukan untuk Rocky/RHEL-family."
        warn "Terdeteksi: $distro_id. Tetap dilanjutkan..."
    fi

    ok "Sistem: $PRETTY_NAME ($distro_id)"

    if [[ $EUID -eq 0 ]]; then
        warn "Berjalan sebagai root. Disarankan jalankan sebagai user biasa dengan sudo."
    else
        command -v sudo >/dev/null || { err "sudo tidak ditemukan."; exit 1; }
    fi
}

# =====================================================================
# 2. AKTIFKAN REPO YANG DIPERLUKAN
# =====================================================================
enable_repos() {
    info "Mengaktifkan CRB (CodeReady Builder) dan EPEL..."

    # EPEL
    if ! rpm -q epel-release &>/dev/null; then
        sudo dnf install -y epel-release >>"$LOG_FILE" 2>&1 || {
            warn "Gagal install epel-release, mencoba alternatif..."
            sudo dnf install -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm" >>"$LOG_FILE" 2>&1 || true
        }
    fi

    # CRB
    sudo dnf config-manager --set-enabled crb 2>/dev/null \
        || sudo dnf config-manager --set-enabled powertools 2>/dev/null \
        || warn "CRB/PowerTools tidak bisa diaktifkan (mungkin sudah aktif atau tidak ada)."

    sudo dnf makecache >>"$LOG_FILE" 2>&1 || true
    ok "Repo diaktifkan."
}

# =====================================================================
# 3. INSTALL BUILD DEPENDENCIES
# =====================================================================
install_build_deps() {
    info "Memasang build dependencies..."

    local deps=(
        # Build tools (individual, bukan group syntax)
        gcc
        gcc-c++
        make
        autoconf
        automake
        meson
        ninja-build
        cmake
        pkgconf-pkg-config
        git

        # Wayland
        wayland-devel
        wayland-protocols-devel

        # Portal deps
        glib2-devel
        libdrm-devel

        # xdg-desktop-portal build deps
        # (systemd-devel untuk sd-bus, inih untuk config parsing)
        systemd-devel
        inih-devel

        # Pipewire (diperlukan untuk screen casting)
        pipewire-devel

        # XML & docs
        libxml2-devel
        xmltoman
        doxygen

        # D-Bus
        dbus-devel

        # FUSE (diperlukan xdg-desktop-portal untuk document portal)
        fuse3-devel
    )

    # Install satu per satu agar yang gagal tidak menghentikan seluruh proses
    local failed=()
    for dep in "${deps[@]}"; do
        if ! sudo dnf install -y "$dep" >>"$LOG_FILE" 2>&1; then
            warn "Paket '$dep' tidak tersedia, akan dicoba diabaikan."
            failed+=("$dep")
        fi
    done

    if [[ ${#failed[@]} -gt 0 ]]; then
        warn "Paket berikut tidak tersedia: ${failed[*]}"
        warn "Build mungkin tetap berhasil tanpa paket opsional tersebut."
    fi

    # Pastikan inih tersedia (kadang tidak ada di Rocky)
    if ! pkg-config --exists inih 2>/dev/null; then
        info "inih tidak ditemukan via pkg-config, build dari source..."
        build_inih
    fi

    ok "Build dependencies selesai."
}

# =====================================================================
# 3b. BUILD INIH DARI SOURCE (fallback jika tidak ada di repo)
# =====================================================================
build_inih() {
    local dir="$BUILD_ROOT/inih"
    info "Build inih dari source..."
    git clone --depth 1 https://github.com/benhoyt/inih.git "$dir" >>"$LOG_FILE" 2>&1 || {
        err "Clone inih gagal."
        return 1
    }
    (
        cd "$dir" || exit 1
        meson setup build --buildtype=release -Ddistro_install=true >>"$LOG_FILE" 2>&1 || exit 1
        ninja -C build >>"$LOG_FILE" 2>&1 || exit 1
        sudo ninja -C build install >>"$LOG_FILE" 2>&1 || exit 1
    ) || { err "Build inih gagal."; return 1; }
    sudo ldconfig 2>/dev/null
    ok "inih berhasil dibuild & dipasang."
}

# =====================================================================
# 4. BUILD XDG-DESKTOP-PORTAL (parent daemon)
# =====================================================================
build_xdg_desktop_portal() {
    if _has_bin xdg-desktop-portal; then
        local existing; existing="$(_find_bin xdg-desktop-portal)"
        ok "xdg-desktop-portal sudah terinstall: $existing"
        return 0
    fi

    # Cek apakah ada di repo dulu
    info "Coba install xdg-desktop-portal via dnf..."
    if sudo dnf install -y xdg-desktop-portal >>"$LOG_FILE" 2>&1; then
        # Verifikasi binary benar-benar ada (dnf bisa return 0 tapi paket kosong/meta)
        if _has_bin xdg-desktop-portal; then
            ok "xdg-desktop-portal terpasang via dnf."
            return 0
        fi
        warn "dnf install sukses tapi binary tidak ditemukan. Build dari source..."
    fi

    info "Build xdg-desktop-portal dari source..."

    local dir="$BUILD_ROOT/xdg-desktop-portal"
    git clone --depth 1 https://github.com/flatpak/xdg-desktop-portal.git "$dir" >>"$LOG_FILE" 2>&1 || {
        err "Clone xdg-desktop-portal gagal."
        return 1
    }

    local rc=0
    (
        cd "$dir" || exit 1
        meson setup build \
            --prefix=/usr/local \
            --libexecdir=/usr/local/libexec \
            --buildtype=release \
            -Dportal-tests=false \
            -Dsystemd=enabled \
            >>"$LOG_FILE" 2>&1 || exit 1
        ninja -C build >>"$LOG_FILE" 2>&1 || exit 1
        sudo ninja -C build install >>"$LOG_FILE" 2>&1 || exit 1
    ) || rc=$?

    if [[ $rc -ne 0 ]]; then
        err "Build xdg-desktop-portal gagal (rc=$rc). Cek $LOG_FILE"
        return 1
    fi

    sudo ldconfig 2>/dev/null

    # Symlink dari libexec ke /usr/local/bin agar ada di PATH
    if [[ -x /usr/local/libexec/xdg-desktop-portal ]]; then
        sudo ln -sf /usr/local/libexec/xdg-desktop-portal /usr/local/bin/xdg-desktop-portal 2>/dev/null || true
    fi

    ok "xdg-desktop-portal berhasil dibuild & dipasang."
}

# =====================================================================
# 5. BUILD XDG-DESKTOP-PORTAL-WLR
# =====================================================================
build_xdg_desktop_portal_wlr() {
    if _has_bin xdg-desktop-portal-wlr; then
        local existing; existing="$(_find_bin xdg-desktop-portal-wlr)"
        ok "xdg-desktop-portal-wlr sudah terinstall: $existing"
        return 0
    fi

    # Cek repo dulu
    info "Coba install xdg-desktop-portal-wlr via dnf..."
    if sudo dnf install -y xdg-desktop-portal-wlr >>"$LOG_FILE" 2>&1; then
        if _has_bin xdg-desktop-portal-wlr; then
            ok "xdg-desktop-portal-wlr terpasang via dnf."
            return 0
        fi
        warn "dnf install sukses tapi binary tidak ditemukan. Build dari source..."
    fi

    info "Build xdg-desktop-portal-wlr dari source (v0.6.0 — compatible dengan wlroots 0.18)..."

    local dir="$BUILD_ROOT/xdg-desktop-portal-wlr"
    git clone --depth 1 --branch v0.6.0 https://github.com/emersion/xdg-desktop-portal-wlr.git "$dir" >>"$LOG_FILE" 2>&1 || {
        err "Clone xdg-desktop-portal-wlr gagal."
        return 1
    }

    local rc=0
    (
        cd "$dir" || exit 1
        meson setup build \
            --prefix=/usr/local \
            --libexecdir=/usr/local/libexec \
            --buildtype=release \
            -Dsd-bus-provider=libsystemd \
            >>"$LOG_FILE" 2>&1 || exit 1
        ninja -C build >>"$LOG_FILE" 2>&1 || exit 1
        sudo ninja -C build install >>"$LOG_FILE" 2>&1 || exit 1
    ) || rc=$?

    if [[ $rc -ne 0 ]]; then
        err "Build xdg-desktop-portal-wlr gagal (rc=$rc). Cek $LOG_FILE"
        return 1
    fi

    sudo ldconfig 2>/dev/null

    # Symlink dari libexec ke /usr/local/bin agar ada di PATH
    if [[ -x /usr/local/libexec/xdg-desktop-portal-wlr ]]; then
        sudo ln -sf /usr/local/libexec/xdg-desktop-portal-wlr /usr/local/bin/xdg-desktop-portal-wlr 2>/dev/null || true
    fi

    # PENTING: xdg-desktop-portal (paket dnf, datadir compile-time /usr/share) hardcode
    # mencari file *.portal HANYA di /usr/share/xdg-desktop-portal/portals dan TIDAK
    # mengikuti XDG_DATA_DIRS untuk pencarian file registrasi backend ini (berbeda dari
    # D-Bus service activation yang memang scan /usr/local juga). Karena kita build
    # dengan --prefix=/usr/local, wlr.portal nyasar ke /usr/local/share/... — lokasi yang
    # tidak pernah dibaca daemon. Tanpa ini, ScreenCast/Screenshot tidak akan pernah
    # ter-resolve ke wlr walau service jalan normal — screen sharing tetap gagal total.
    if [[ -f /usr/local/share/xdg-desktop-portal/portals/wlr.portal ]]; then
        sudo mkdir -p /usr/share/xdg-desktop-portal/portals
        sudo cp -f /usr/local/share/xdg-desktop-portal/portals/wlr.portal /usr/share/xdg-desktop-portal/portals/wlr.portal
        ok "wlr.portal disalin ke /usr/share/xdg-desktop-portal/portals/ (lokasi yang benar-benar dibaca daemon)."
    fi

    ok "xdg-desktop-portal-wlr berhasil dibuild & dipasang."
}

# =====================================================================
# 6. INSTALL SYSTEMD USER UNITS (jika tidak otomatis terpasang)
# =====================================================================
install_systemd_units() {
    info "Memeriksa systemd user units..."

    local unit_dir="$HOME/.config/systemd/user"
    mkdir -p "$unit_dir"

    # Resolve path binary xdg-desktop-portal
    local portal_exec; portal_exec="$(_find_bin xdg-desktop-portal)"
    [[ -z "$portal_exec" ]] && portal_exec="/usr/local/libexec/xdg-desktop-portal"

    # xdg-desktop-portal.service biasanya sudah terpasang oleh build
    # Tapi jika tidak ada, buat manual
    if [[ ! -f /usr/lib/systemd/user/xdg-desktop-portal.service ]] && \
       [[ ! -f /usr/local/lib/systemd/user/xdg-desktop-portal.service ]] && \
       [[ ! -f "$unit_dir/xdg-desktop-portal.service" ]]; then
        info "Membuat xdg-desktop-portal.service manual..."
        cat > "$unit_dir/xdg-desktop-portal.service" << EOF
[Unit]
Description=Portal service
Documentation=man:xdg-desktop-portal(8)
ConditionEnvironment=XDG_CURRENT_DESKTOP

[Service]
Type=dbus
BusName=org.freedesktop.portal.Desktop
ExecStart=${portal_exec}
EOF
        ok "xdg-desktop-portal.service dibuat (ExecStart=$portal_exec)."
    fi

    # Resolve path binary xdg-desktop-portal-wlr
    local wlr_exec; wlr_exec="$(_find_bin xdg-desktop-portal-wlr)"
    [[ -z "$wlr_exec" ]] && wlr_exec="/usr/local/libexec/xdg-desktop-portal-wlr"

    # xdg-desktop-portal-wlr.service
    if [[ ! -f /usr/lib/systemd/user/xdg-desktop-portal-wlr.service ]] && \
       [[ ! -f /usr/local/lib/systemd/user/xdg-desktop-portal-wlr.service ]] && \
       [[ ! -f "$unit_dir/xdg-desktop-portal-wlr.service" ]]; then
        info "Membuat xdg-desktop-portal-wlr.service manual..."
        cat > "$unit_dir/xdg-desktop-portal-wlr.service" << EOF
[Unit]
Description=Portal service (wlroots implementation)
Documentation=https://github.com/emersion/xdg-desktop-portal-wlr
BindsTo=xdg-desktop-portal.service

[Service]
Type=dbus
BusName=org.freedesktop.impl.portal.desktop.wlr
ExecStart=${wlr_exec}
EOF
        ok "xdg-desktop-portal-wlr.service dibuat (ExecStart=$wlr_exec)."
    fi

    systemctl_user daemon-reload 2>/dev/null || true
}

# =====================================================================
# 7. KONFIGURASI PORTAL
# =====================================================================
configure_portal() {
    info "Konfigurasi xdg-desktop-portal..."

    # Direktori config
    mkdir -p "$HOME/.config/xdg-desktop-portal"

    # sway-portals.conf — tentukan backend mana yang dipakai
    # Nama file harus portals.conf (default fallback) karena xdg-desktop-portal
    # mencari: 1) ${XDG_CURRENT_DESKTOP}-portals.conf  2) portals.conf
    # Saat boot, XDG_CURRENT_DESKTOP belum tentu ter-set, jadi portals.conf
    # adalah nama yang paling reliable.
    local conf="$HOME/.config/xdg-desktop-portal/portals.conf"
    cat > "$conf" << 'EOF'
[preferred]
default=wlr;gtk
org.freedesktop.impl.portal.Screenshot=wlr
org.freedesktop.impl.portal.ScreenCast=wlr
org.freedesktop.impl.portal.FileChooser=gtk
EOF
    # Hapus file lama jika ada (naming lama yang salah)
    rm -f "$HOME/.config/xdg-desktop-portal/sway-portals.conf" 2>/dev/null || true
    ok "Konfigurasi portal ditulis: $conf"

    # Pastikan sway config punya import environment
    local sway_conf="$HOME/.config/sway/config"
    if [[ -f "$sway_conf" ]]; then
        if ! grep -q "XDG_CURRENT_DESKTOP" "$sway_conf" 2>/dev/null; then
            cat >> "$sway_conf" << 'EOF'

# === XDG Desktop Portal (screen sharing) ===
exec systemctl --user import-environment DISPLAY WAYLAND_DISPLAY SWAYSOCK XDG_CURRENT_DESKTOP
exec hash dbus-update-activation-environment 2>/dev/null && \
     dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY SWAYSOCK XDG_CURRENT_DESKTOP
EOF
            ok "Environment variables ditambahkan ke sway config."
        fi
    fi

    # Set XDG_CURRENT_DESKTOP=sway di profile
    local profile_file="$HOME/.config/environment.d/sway.conf"
    mkdir -p "$(dirname "$profile_file")"
    if [[ ! -f "$profile_file" ]] || ! grep -q "XDG_CURRENT_DESKTOP" "$profile_file" 2>/dev/null; then
        cat >> "$profile_file" << 'EOF'
XDG_CURRENT_DESKTOP=sway
XDG_SESSION_TYPE=wayland
EOF
        ok "Environment variables ditulis: $profile_file"
    fi
}

# =====================================================================
# 8. ENABLE & START SERVICES
# =====================================================================
enable_services() {
    info "Mengaktifkan xdg-desktop-portal services..."

    if ! command -v systemctl >/dev/null 2>&1; then
        warn "systemctl tidak ditemukan. Portal harus dijalankan manual."
        return 0
    fi

    systemctl_user daemon-reload 2>/dev/null || true

    # Enable socket (auto-start saat dibutuhkan)
    if systemctl_user list-unit-files 2>/dev/null | grep -q 'xdg-desktop-portal\.service'; then
        systemctl_user enable xdg-desktop-portal.service 2>/dev/null || true
        ok "xdg-desktop-portal.service diaktifkan."
    else
        warn "xdg-desktop-portal.service tidak ditemukan di systemd."
    fi

    if systemctl_user list-unit-files 2>/dev/null | grep -q 'xdg-desktop-portal-wlr\.service'; then
        systemctl_user enable xdg-desktop-portal-wlr.service 2>/dev/null || true
        ok "xdg-desktop-portal-wlr.service diaktifkan."
    else
        warn "xdg-desktop-portal-wlr.service tidak ditemukan. Akan auto-start via D-Bus."
    fi

    # Restart portal jika sudah berjalan
    if systemctl_user is-active xdg-desktop-portal >/dev/null 2>&1; then
        systemctl_user restart xdg-desktop-portal 2>/dev/null || true
        ok "xdg-desktop-portal direstart."
    fi
}

# =====================================================================
# 9. VERIFIKASI
# =====================================================================
verify_install() {
    echo
    banner "============================================"
    banner " VERIFIKASI INSTALASI"
    banner "============================================"
    echo

    local all_ok=true

    # Cek binary
    if _has_bin xdg-desktop-portal; then
        local portal_bin; portal_bin="$(_find_bin xdg-desktop-portal)"
        ok "xdg-desktop-portal: $portal_bin"
    else
        err "xdg-desktop-portal TIDAK ditemukan!"
        all_ok=false
    fi

    if _has_bin xdg-desktop-portal-wlr; then
        local wlr_bin; wlr_bin="$(_find_bin xdg-desktop-portal-wlr)"
        ok "xdg-desktop-portal-wlr: $wlr_bin"
    else
        err "xdg-desktop-portal-wlr TIDAK ditemukan!"
        all_ok=false
    fi

    # Cek config
    if [[ -f "$HOME/.config/xdg-desktop-portal/portals.conf" ]]; then
        ok "Konfigurasi portal: OK"
    else
        warn "Konfigurasi portal tidak ditemukan."
    fi

    # Cek environment
    if [[ -f "$HOME/.config/environment.d/sway.conf" ]]; then
        ok "Environment variables: OK"
    else
        warn "Environment variables tidak ditemukan."
    fi

    echo
    if [[ "$all_ok" == "true" ]]; then
        banner "============================================"
        banner " INSTALASI BERHASIL"
        banner "============================================"
        echo
        info "Untuk mengaktifkan screen sharing:"
        info "  1. Logout & login kembali ke Sway"
        info "  2. Atau jalankan: systemctl --user restart xdg-desktop-portal"
        info "  3. Test di Discord/browser: share screen"
    else
        banner "============================================"
        banner " INSTALASI GAGAL — cek $LOG_FILE"
        banner "============================================"
    fi
    echo
}

# =====================================================================
# MAIN
# =====================================================================
main() {
    validate_system
    enable_repos
    install_build_deps
    build_xdg_desktop_portal
    build_xdg_desktop_portal_wlr
    install_systemd_units
    configure_portal
    enable_services
    verify_install
}

main "$@"
