#!/usr/bin/env bash
# =====================================================================
# SWAY GENSHIN/INAZUMA RICE - UNIVERSAL AUTO INSTALLER
# Target: /home/sway (dotfiles) + deploy ke ~/.config & /etc/greetd
#
# Strategi:
#   1. Deteksi OS & package manager
#   2. Install dependency build (compiler, meson, ninja, cargo, dst) via repo
#   3. Untuk app inti (sway, wlroots, greetd, gtkgreet, waybar, kitty,
#      mako, grim, slurp, mpvpaper, rofi/anyrun/wofi): coba repo dulu,
#      kalau gagal build dari source otomatis (karena banyak distro
#      -terutama RHEL-family- tidak punya paket ini)
#   4. Salin semua dotfiles dari folder ini ke lokasi yang benar
# =====================================================================
set -euo pipefail

# Warna & fungsi logging — HARUS didefinisikan SEBELUM pemakaian pertama.
# LOG_FILE di-set nanti; fungsi akan skip write ke log bila LOG_FILE kosong.
c_reset="\033[0m"; c_red="\033[31m"; c_green="\033[32m"; c_yellow="\033[33m"; c_blue="\033[34m"
# Penting: jangan return exit-code dari `tee` — kalau tee gagal (disk penuh, dst),
# fungsi tetap dianggap sukses supaya `cmd && ok || warn` tidak salah trigger.
info()  { echo -e "${c_blue}[INFO]${c_reset} $*";       [[ -n "${LOG_FILE:-}" ]] && echo "[INFO] $*"       >> "$LOG_FILE" 2>/dev/null || true; }
ok()    { echo -e "${c_green}[ OK ]${c_reset} $*";      [[ -n "${LOG_FILE:-}" ]] && echo "[ OK ] $*"       >> "$LOG_FILE" 2>/dev/null || true; }
warn()  { echo -e "${c_yellow}[PERINGATAN]${c_reset} $*"; [[ -n "${LOG_FILE:-}" ]] && echo "[PERINGATAN] $*" >> "$LOG_FILE" 2>/dev/null || true; }
err()   { echo -e "${c_red}[GAGAL]${c_reset} $*" >&2;   [[ -n "${LOG_FILE:-}" ]] && echo "[GAGAL] $*"      >> "$LOG_FILE" 2>/dev/null || true; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME="${THEME:-raiden}"
THEME_DIR="$REPO_DIR/themes/$THEME"

# Validasi tema: harus berupa folder themes/<nama>/ yang berisi config/
if [[ ! -d "$THEME_DIR/config" ]]; then
    echo "[GAGAL] Tema '$THEME' tidak ditemukan di $REPO_DIR/themes/." >&2
    echo "        Tema tersedia:" >&2
    for d in "$REPO_DIR/themes"/*/; do
        [[ -d "$d/config" ]] && echo "          - $(basename "$d")" >&2
    done
    echo "        Contoh: THEME=xiao ./install.sh" >&2
    exit 1
fi
BUILD_ROOT="$(mktemp -d /tmp/sway-rice-build.XXXXXX)"

FORCE_INSTALL=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force) FORCE_INSTALL=1; shift ;;
        *) shift ;;
    esac
done

# =====================================================================
# TOLAK dijalankan lewat sudo (root)
# =====================================================================
# Script ini menulis config ke $HOME/.config/, $HOME/.local/share/, dst — kalau
# dijalankan lewat `sudo`, $HOME akan menunjuk ke /root (kecuali sudoers set
# always_set_home=no + user pakai -E), sehingga semua config user ter-deploy ke
# /root/.config/ dan tidak pernah dibaca oleh sway/waybar user asli. Selain itu,
# jejak file yang ditulis (mis. /tmp/sway-rice-install.log) jadi owned by root
# — waktu script dijalankan lagi tanpa sudo, semua write ke file itu gagal
# (permission denied), yang bikin fungsi `ok()` (pakai tee -a) return non-zero,
# lalu pola `cmd && ok || warn` di seluruh script salah trigger warning
# "gagal disalin" walau cp-nya sukses. Deteksi & tolak sejak awal.
if [[ $EUID -eq 0 ]]; then
    # SUDO_USER = user asli yang jalanin sudo (kalau memang via sudo, bukan login root asli)
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        echo -e "\033[31m[GAGAL]\033[0m Jangan jalankan script ini dengan sudo!" >&2
        echo -e "        Script akan otomatis panggil sudo untuk baris yang perlu privilege." >&2
        echo -e "        Jalankan sebagai user biasa:" >&2
        echo -e "            \033[36mcd ${REPO_DIR} && ./install.sh --force\033[0m" >&2
        echo -e "        (login sebagai '${SUDO_USER}', lalu tanpa sudo di depan)" >&2
        exit 1
    fi
    # Kalau memang login sebagai root asli (bukan via sudo), lanjut dengan warning
    echo -e "\033[33m[PERINGATAN]\033[0m Berjalan sebagai root asli. Config akan di-deploy ke /root/.config/." >&2
    echo -e "        Untuk deploy ke user biasa, login sebagai user tsb dulu." >&2
else
    command -v sudo >/dev/null || {
        echo -e "\033[31m[GAGAL]\033[0m sudo tidak ditemukan. Install sudo atau jalankan sebagai root." >&2
        exit 1
    }
fi

# =====================================================================
# LOGGING — pakai log file per-user (bukan /tmp global) supaya tidak bentrok
# kalau sebelumnya pernah dijalankan sebagai root.
# =====================================================================
# =====================================================================
# DETEKSI USER TUJUAN (target user untuk deploy config & systemctl --user)
# Script ini harus dijalankan SEBAGAI user biasa (tanpa sudo di depan).
# Kalau user jalankan `sudo -u risqinf ./install.sh` atau skrip ini dipanggil
# dari konteks root lain, kita deteksi user asli dari berbagai variabel.
# =====================================================================
REAL_USER="${SUDO_USER:-${LOGNAME:-${USER:-$(id -un)}}}"
# Validasi: pastikan bukan root
if [[ "$REAL_USER" == "root" ]]; then
    # Kalau dijalankan langsung sebagai root (bukan via sudo), coba deteksi
    # dari pemilik file script ini
    REAL_USER="$(stat -c '%U' "${BASH_SOURCE[0]}")"
    if [[ "$REAL_USER" == "root" ]]; then
        echo -e "\033[31m[GAGAL]\033[0m Tidak bisa mendeteksi user tujuan." >&2
        echo -e "        Jalankan script ini sebagai user biasa (tanpa sudo)." >&2
        exit 1
    fi
fi

# Helper: jalankan systemctl --user
# Script ini sudah di-guard untuk SELALU jalan sebagai user biasa (bukan root,
# bukan via sudo) — lihat check EUID di atas. Jadi tidak perlu `sudo -u` lagi:
# cukup pastikan XDG_RUNTIME_DIR & DBUS ter-set agar systemd --user reachable.
systemctl_user() {
    env XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
        DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}" \
        systemctl --user "$@"
}

LOG_FILE="/tmp/sway-rice-install-${UID}.log"
# Kalau log file sebelumnya tidak writable (mis. pernah dibuat root), fallback
# ke state dir user — jangan panggil sudo hanya untuk log.
if [[ -e "$LOG_FILE" && ! -w "$LOG_FILE" ]]; then
    LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/sway-rice-install.log"
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
fi
: > "$LOG_FILE" 2>/dev/null || {
    echo -e "\033[31m[GAGAL]\033[0m Tidak bisa menulis log ke $LOG_FILE" >&2
    exit 1
}
info "Target user: $REAL_USER (HOME=/home/$REAL_USER, UID=$(id -u "$REAL_USER"))"

cleanup() {
    rm -rf "$BUILD_ROOT"
    # Bunuh sudo keep-alive loop bila masih berjalan
    [[ -n "${_SUDO_KEEPALIVE_PID:-}" ]] && kill "$_SUDO_KEEPALIVE_PID" 2>/dev/null || true
}
trap cleanup EXIT
_SUDO_KEEPALIVE_PID=""

# =====================================================================
# 1. DETEKSI OS
# =====================================================================
DISTRO_ID=""; DISTRO_FAMILY=""; PKG_MGR=""

detect_os() {
    [[ -f /etc/os-release ]] || { err "Tidak bisa mendeteksi OS."; exit 1; }
    # shellcheck disable=SC1091
    source /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    local id_like="${ID_LIKE:-}"

    case "$DISTRO_ID" in
        arch|manjaro|endeavouros|cachyos|artix)
            DISTRO_FAMILY="arch"; PKG_MGR="pacman" ;;
        debian|ubuntu|linuxmint|pop|elementary|zorin)
            DISTRO_FAMILY="debian"; PKG_MGR="apt" ;;
        fedora)
            DISTRO_FAMILY="rhel"; PKG_MGR="dnf" ;;
        rocky|almalinux|rhel|centos|ol)
            DISTRO_FAMILY="rhel"; PKG_MGR="dnf" ;;
        opensuse*|sles)
            DISTRO_FAMILY="suse"; PKG_MGR="zypper" ;;
        alpine)
            DISTRO_FAMILY="alpine"; PKG_MGR="apk" ;;
        void)
            DISTRO_FAMILY="void"; PKG_MGR="xbps" ;;
        *)
            if [[ "$id_like" == *arch* ]]; then DISTRO_FAMILY="arch"; PKG_MGR="pacman"
            elif [[ "$id_like" == *debian* ]]; then DISTRO_FAMILY="debian"; PKG_MGR="apt"
            elif [[ "$id_like" == *rhel* || "$id_like" == *fedora* ]]; then DISTRO_FAMILY="rhel"; PKG_MGR="dnf"
            elif [[ "$id_like" == *suse* ]]; then DISTRO_FAMILY="suse"; PKG_MGR="zypper"
            elif [[ "$id_like" == *alpine* ]]; then DISTRO_FAMILY="alpine"; PKG_MGR="apk"
            elif [[ "$id_like" == *void* ]]; then DISTRO_FAMILY="void"; PKG_MGR="xbps"
            else
                # Fallback: auto-detect package manager yang tersedia
                warn "Distro '$DISTRO_ID' tidak dikenal, mencoba auto-detect package manager..."
                if command -v pacman >/dev/null; then DISTRO_FAMILY="arch"; PKG_MGR="pacman"
                elif command -v apt >/dev/null; then DISTRO_FAMILY="debian"; PKG_MGR="apt"
                elif command -v dnf >/dev/null; then DISTRO_FAMILY="rhel"; PKG_MGR="dnf"
                elif command -v yum >/dev/null; then DISTRO_FAMILY="rhel"; PKG_MGR="yum"
                elif command -v zypper >/dev/null; then DISTRO_FAMILY="suse"; PKG_MGR="zypper"
                elif command -v apk >/dev/null; then DISTRO_FAMILY="alpine"; PKG_MGR="apk"
                elif command -v xbps-install >/dev/null; then DISTRO_FAMILY="void"; PKG_MGR="xbps"
                elif command -v emerge >/dev/null; then DISTRO_FAMILY="gentoo"; PKG_MGR="portage"
                elif command -v nix-env >/dev/null; then DISTRO_FAMILY="nix"; PKG_MGR="nix"
                else err "Tidak ada package manager yang dikenal (pacman/apt/dnf/zypper/apk/xbps). Install manual diperlukan."; exit 1
                fi
                warn "Auto-detected: $PKG_MGR (family: $DISTRO_FAMILY) — beberapa package mungkin perlu install manual."
            fi ;;
    esac
    ok "Terdeteksi: $DISTRO_ID (family: $DISTRO_FAMILY, pkg mgr: $PKG_MGR)"
}

prepare_repos() {
    case "$DISTRO_FAMILY" in
        rhel)
            rpm -q epel-release &>/dev/null || sudo dnf install -y epel-release
            sudo dnf config-manager --set-enabled crb 2>/dev/null \
                || sudo dnf config-manager --set-enabled powertools 2>/dev/null || true
            ;;
        debian) sudo apt update -y ;;
        arch)   sudo pacman -Sy --noconfirm ;;
        suse)   sudo zypper --non-interactive refresh ;;
        alpine) sudo apk update ;;
        void)   sudo xbps-install -S ;;
        gentoo) sudo emerge --sync ;;
        nix)    true ;;
        *)      warn "Tidak ada prepare_repos untuk family: $DISTRO_FAMILY" ;;
    esac
}

# =====================================================================
# 2. MAPPING NAMA PAKET DEPENDENSI BUILD (per family)
# =====================================================================
declare -A DEP_ARCH=(
    [base-devel]="base-devel" [meson]="meson" [ninja]="ninja" [git]="git"
    [cmake]="cmake" [pkgconf]="pkgconf"
    [wayland]="wayland" [wayland-protocols]="wayland-protocols"
    [wlroots-deps]="libinput libxkbcommon pixman libdrm seatd libdisplay-info"
    [gtk3]="gtk3" [scdoc]="scdoc" [mpv-dev]="mpv"
    [json-c]="json-c" [pango]="pango" [cairo]="cairo"
    [libxml2]="libxml2" [hg]="mercurial" [curl]="curl"
    [pavucontrol]="pavucontrol" [nm-applet]="network-manager-applet"
    [waybar-deps]="gtkmm3 jsoncpp libsigc++ fmt spdlog libnl libpulse wireplumber playerctl scdoc"
    [runtime-deps]="tuned libnotify xdg-desktop-portal xdg-desktop-portal-wlr wireplumber"
)
declare -A DEP_DEBIAN=(
    [base-devel]="build-essential" [meson]="meson" [ninja]="ninja-build" [git]="git"
    [cmake]="cmake" [pkgconf]="pkg-config"
    [wayland]="libwayland-dev" [wayland-protocols]="wayland-protocols"
    [wlroots-deps]="libinput-dev libxkbcommon-dev libpixman-1-dev libdrm-dev libseat-dev libdisplay-info-dev"
    [gtk3]="libgtk-3-dev" [scdoc]="scdoc" [mpv-dev]="libmpv-dev"
    [json-c]="libjson-c-dev" [pango]="libpango1.0-dev" [cairo]="libcairo2-dev"
    [libxml2]="libxml2-dev" [hg]="mercurial" [curl]="curl"
    [pavucontrol]="pavucontrol" [nm-applet]="network-manager-applet"
    [rofi-deps]="bison flex wayland-protocols libpango1.0-dev libcairo2-dev libglib2.0-dev libxkbcommon-dev libgdk-pixbuf2.0-dev libstartup-notification0-dev libxcb-util0-dev libxcb-ewmh-dev libxcb-icccm4-dev libxcb-keysyms1-dev libxcb-cursor-dev libxcb-xinerama0-dev"
    [anyrun-deps]="libgtk-4-dev"
    [waybar-deps]="libgtkmm-3.0-dev libjsoncpp-dev libsigc++-2.0-dev libfmt-dev libspdlog-dev libnl-3-dev libnl-genl-3-dev libpulse-dev libwireplumber-0.4-dev playerctl scdoc"
    [runtime-deps]="tuned libnotify-bin xdg-desktop-portal xdg-desktop-portal-wlr wireplumber"
)
declare -A DEP_RHEL=(
    [base-devel]="@development" [meson]="meson" [ninja]="ninja-build" [git]="git"
    [cmake]="cmake" [pkgconf]="pkgconf-pkg-config"
    [wayland]="wayland-devel" [wayland-protocols]="wayland-protocols-devel"
    [wlroots-deps]="libinput-devel libxkbcommon-devel pixman-devel libdrm-devel libseat-devel libdisplay-info-devel"
    [gtk3]="gtk3-devel" [scdoc]="scdoc" [mpv-dev]="mpv-devel"
    [json-c]="json-c-devel" [pango]="pango-devel" [cairo]="cairo-devel"
    [libxml2]="libxml2-devel" [hg]="mercurial" [curl]="curl"
    [pavucontrol]="pavucontrol" [nm-applet]="network-manager-applet"
    [rofi-deps]="bison flex wayland-protocols-devel pango-devel cairo-devel glib2-devel libxkbcommon-devel gdk-pixbuf2-devel startup-notification-devel xcb-util-devel xcb-util-wm-devel xcb-util-keysyms-devel xcb-util-cursor-devel"
    [waybar-deps]="gtkmm3.0-devel jsoncpp-devel libsigc++20-devel fmt-devel spdlog-devel libnl3-devel pulseaudio-libs-devel scdoc"
    [runtime-deps]="tuned libnotify xdg-desktop-portal xdg-desktop-portal-wlr wireplumber"
)
declare -A DEP_SUSE=(
    [base-devel]="patterns-devel-base-devel_basis" [meson]="meson" [ninja]="ninja" [git]="git"
    [cmake]="cmake" [pkgconf]="pkgconf-pkg-config"
    [wayland]="wayland-devel" [wayland-protocols]="wayland-protocols-devel"
    [wlroots-deps]="libinput-devel libxkbcommon-devel libpixman-devel libdrm-devel libseat-devel libdisplay-info-devel"
    [gtk3]="gtk3-devel" [scdoc]="scdoc" [mpv-dev]="mpv-devel"
    [json-c]="libjson-c-devel" [pango]="pango-devel" [cairo]="cairo-devel"
    [libxml2]="libxml2-devel" [hg]="mercurial" [curl]="curl"
    [pavucontrol]="pavucontrol" [nm-applet]="network-manager-applet"
    [rofi-deps]="bison flex wayland-protocols-devel pango-devel cairo-devel glib2-devel libxkbcommon-devel gdk-pixbuf2-devel startup-notification-devel"
    [waybar-deps]="gtkmm3-devel jsoncpp-devel libsigc++-2_0-devel fmt-devel spdlog-devel libnl3-devel libpulse-devel wireplumber-devel scdoc"
    [runtime-deps]="tuned libnotify-tools xdg-desktop-portal xdg-desktop-portal-wlr wireplumber"
)
declare -A DEP_ALPINE=(
    [base-devel]="build-base" [meson]="meson" [ninja]="ninja" [git]="git"
    [cargo]="cargo" [cmake]="cmake" [pkgconf]="pkgconf"
    [wayland]="wayland-dev" [wayland-protocols]="wayland-protocols"
    [wlroots-deps]="libinput-dev libxkbcommon-dev pixman-dev libdrm-dev seatd-dev libdisplay-info-dev"
    [gtk3]="gtk+3.0-dev" [scdoc]="scdoc" [mpv-dev]="mpv-dev"
    [json-c]="json-c-dev" [pango]="pango-dev" [cairo]="cairo-dev"
    [libxml2]="libxml2-dev" [hg]="mercurial" [curl]="curl"
    [pavucontrol]="pavucontrol" [nm-applet]="network-manager-applet"
    [rofi-deps]="bison flex pango-dev cairo-dev glib-dev libxkbcommon-dev gdk-pixbuf-dev libxcb-dev xcb-util-dev xcb-util-wm-dev xcb-util-keysyms-dev xcb-util-cursor-dev"
    [waybar-deps]="gtkmm3-dev jsoncpp-dev libsigc++-dev fmt-dev spdlog-dev libnl3-dev pulseaudio-dev wireplumber-dev scdoc"
    [runtime-deps]="libnotify xdg-desktop-portal wireplumber"
)
declare -A DEP_VOID=(
    [base-devel]="base-devel" [meson]="meson" [ninja]="ninja" [git]="git"
    [cmake]="cmake" [pkgconf]="pkgconf"
    [wayland]="wayland-devel" [wayland-protocols]="wayland-protocols"
    [wlroots-deps]="libinput-devel libxkbcommon-devel pixman-devel libdrm-devel seatd libdisplay-info-devel"
    [gtk3]="gtk+3-devel" [scdoc]="scdoc" [mpv-dev]="mpv-devel"
    [json-c]="json-c-devel" [pango]="pango-devel" [cairo]="cairo-devel"
    [libxml2]="libxml2-devel" [hg]="mercurial" [curl]="curl"
    [pavucontrol]="pavucontrol" [nm-applet]="network-manager-applet"
    [rofi-deps]="bison flex pango-devel cairo-devel glib-devel libxkbcommon-devel gdk-pixbuf-devel xcb-util-devel xcb-util-wm-devel xcb-util-keysyms-devel xcb-util-cursor-devel"
    [waybar-deps]="gtkmm3-devel jsoncpp-devel libsigc++-devel fmt-devel spdlog-devel libnl-devel pulseaudio-devel wireplumber-devel scdoc"
    [runtime-deps]="libnotify xdg-desktop-portal xdg-desktop-portal-wlr wireplumber"
)

# Ambil nama paket dari key untuk distro saat ini
dep_pkg() {
    local k="$1"
    case "$DISTRO_FAMILY" in
        arch)   echo "${DEP_ARCH[$k]:-}" ;;
        debian) echo "${DEP_DEBIAN[$k]:-}" ;;
        rhel)   echo "${DEP_RHEL[$k]:-}" ;;
        suse)   echo "${DEP_SUSE[$k]:-}" ;;
        alpine) echo "${DEP_ALPINE[$k]:-}" ;;
        void)   echo "${DEP_VOID[$k]:-}" ;;
        gentoo|nix)
            # Gentoo/Nix: tidak ada mapping, return kosong — package diinstall via source build
            echo "" ;;
        *)      echo "" ;;
    esac
}

# Install paket via package manager utama
_run_pkg_install_batch() {
    case "$PKG_MGR" in
        pacman) sudo pacman -S --needed --noconfirm "$@" >>"$LOG_FILE" 2>&1 ;;
        apt)    sudo apt install -y "$@" >>"$LOG_FILE" 2>&1 ;;
        dnf)    sudo dnf install -y "$@" >>"$LOG_FILE" 2>&1 ;;
        yum)    sudo yum install -y "$@" >>"$LOG_FILE" 2>&1 ;;
        zypper) sudo zypper --non-interactive install "$@" >>"$LOG_FILE" 2>&1 ;;
        apk)    sudo apk add --no-cache "$@" >>"$LOG_FILE" 2>&1 ;;
        xbps)   sudo xbps-install -y "$@" >>"$LOG_FILE" 2>&1 ;;
        portage) sudo emerge --ask=n "$@" >>"$LOG_FILE" 2>&1 ;;
        nix)    sudo nix-env -iA "$@" >>"$LOG_FILE" 2>&1 ;;
        *)      warn "Package manager '$PKG_MGR' tidak didukung untuk batch install"; return 1 ;;
    esac
}

# run_pkg_install <pkg...> — install satu batch; jika gagal (mis. ada satu nama
# paket yang salah/tidak ada di repo — dnf/apt/zypper membatalkan SELURUH
# transaksi karena satu nama tidak valid), otomatis fallback install satu-per-satu
# supaya paket yang valid tetap terpasang alih-alih semuanya gagal diam-diam.
run_pkg_install() {
    _run_pkg_install_batch "$@" && return 0
    warn "Install batch gagal (mungkin ada nama paket yang salah), mencoba satu per satu: $*"
    local ok=1 pkg
    for pkg in "$@"; do
        if _run_pkg_install_batch "$pkg"; then
            ok=0
        else
            warn "Paket '$pkg' tidak tersedia/gagal diinstall, dilewati."
        fi
    done
    return $ok
}

# install_pkgs key1 key2 key3 ... — resolve key → nama paket lalu install
install_pkgs() {
    local pkgs=()
    for k in "$@"; do
        local p; p="$(dep_pkg "$k")"
        [[ -n "$p" ]] && pkgs+=($p)
    done
    [[ ${#pkgs[@]} -eq 0 ]] && return 0
    info "Install dependency: ${pkgs[*]}"
    run_pkg_install "${pkgs[@]}"
}

ensure_cargo_path() {
    [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
    if ! command -v cargo >/dev/null; then
        if [[ -x "$HOME/.cargo/bin/cargo" ]]; then
            export PATH="$HOME/.cargo/bin:$PATH"
        else
            warn "cargo tidak ditemukan di sistem. Menginstal rustup (official Rust installer)..."
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y >>"$LOG_FILE" 2>&1
            [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
        fi
    fi
}

# =====================================================================
# 3. CEK SUDAH TERPASANG?
# =====================================================================

# _has_bin <name> — cek binary di PATH, /usr/local/bin, ~/.local/bin, ~/.cargo/bin, /usr/libexec, /usr/local/libexec
_has_bin() {
    local bin="$1"
    command -v "$bin" >/dev/null 2>&1 && return 0
    [[ -x "/usr/local/bin/$bin" ]] && return 0
    [[ -x "$HOME/.local/bin/$bin" ]] && return 0
    [[ -x "$HOME/.cargo/bin/$bin" ]] && return 0
    [[ -x "/usr/local/libexec/$bin" ]] && return 0
    [[ -x "/usr/libexec/$bin" ]] && return 0
    return 1
}

# _has_pkgconf <name> [name2 ...] — cek via pkg-config
_has_pkgconf() {
    for pkg in "$@"; do
        pkg-config --exists "$pkg" 2>/dev/null && return 0
    done
    return 1
}

already_installed() {
    case "$1" in
        # === Window manager & compositor ===
        sway)       _has_bin sway ;;
        wlroots)    _has_pkgconf wlroots wlroots-0.18 wlroots-0.17 wlroots-0.19 ;;

        # === Display manager / login ===
        greetd)     _has_bin greetd ;;
        gtkgreet)   _has_bin gtkgreet ;;

        # === Bar & notifications ===
        waybar)     _has_bin waybar ;;
        mako)       _has_bin mako ;;

        # === Terminal ===
        kitty)      _has_bin kitty ;;

        # === Application launcher ===
        anyrun)     _has_bin anyrun ;;
        rofi)       _has_bin rofi ;;
        wofi)       _has_bin wofi ;;

        # === Screenshot & recording ===
        grim)           _has_bin grim ;;
        slurp)          _has_bin slurp ;;
        wf-recorder)    _has_bin wf-recorder ;;
        wl-clipboard)   _has_bin wl-copy ;;
        ffmpeg)         _has_bin ffmpeg ;;

        # === Wallpaper ===
        mpvpaper)   _has_bin mpvpaper ;;
        mpv)        _has_bin mpv ;;

        # === Utilities ===
        fastfetch)      _has_bin fastfetch ;;
        wallust)        _has_bin wallust ;;
        brightnessctl)  _has_bin brightnessctl ;;
        swaylock)       _has_bin swaylock ;;
        swayidle)       _has_bin swayidle ;;
        seatd)          _has_bin seatd ;;

        # === File manager ===
        nautilus)       _has_bin nautilus ;;
        cosmic-files)   _has_bin cosmic-files ;;

        # === Settings / audio / network ===
        pavucontrol)    _has_bin pavucontrol ;;
        nm-applet)      _has_bin nm-applet ;;
        fish)           _has_bin fish ;;

        # === Portal ===
        xdg-desktop-portal)     _has_bin xdg-desktop-portal ;;
        xdg-desktop-portal-wlr) _has_bin xdg-desktop-portal-wlr ;;

        # === Audio visualizer ===
        cava)               _has_bin cava ;;
        swww)               _has_bin swww && _has_bin swww-daemon ;;
        matugen)            _has_bin matugen ;;

        # === Build deps (pkg-config) ===
        wayland)        _has_pkgconf wayland ;;
        wayland-protocols) _has_pkgconf wayland-protocols ;;
        json-c)         _has_pkgconf json-c ;;
        pango)          _has_pkgconf pango pangocairo ;;
        cairo)          _has_pkgconf cairo cairo-ft ;;
        gtk3)           _has_pkgconf gtk+-3.0 ;;
        libxml2)        _has_pkgconf libxml-2.0 ;;
        pixman)         _has_pkgconf pixman-1 ;;
        libdrm)         _has_pkgconf libdrm ;;
        libinput)       _has_pkgconf libinput ;;
        libxkbcommon)   _has_pkgconf xkbcommon ;;

        *) return 1 ;;
    esac
}

# =====================================================================
# 4. PAKET YANG TERSEDIA DI REPO RESMI (jarang perlu build manual)
# =====================================================================
# Key → nama paket universal (sama di semua distro)
declare -A REPO_PKG=(
    [mpv]="mpv"
    [wl-clipboard]="wl-clipboard"
    [ffmpeg]="ffmpeg"
    [nautilus]="nautilus"
    [seatd]="seatd"
    [brightnessctl]="brightnessctl"
    [pavucontrol]="pavucontrol"
    [nm-applet]="network-manager-applet"
    [fish]="fish"
)

try_repo_install() {
    local generic="$1"
    local pkg="${REPO_PKG[$generic]:-}"
    [[ -z "$pkg" ]] && return 1
    
    # Handle special case untuk fish di Void Linux
    if [[ "$generic" == "fish" && "$DISTRO_FAMILY" == "void" ]]; then
        pkg="fish-shell"
    fi
    
    run_pkg_install "$pkg"
}

# =====================================================================
# 5. GENERIC BUILDER (meson based)
# =====================================================================
build_meson() {
    # build_meson <name> <git_url> [meson_args...]
    local name="$1" url="$2"; shift 2
    local extra_args=("$@")
    info "Build $name dari source ($url)..."
    local dir="$BUILD_ROOT/$name"
    git clone --depth 1 "$url" "$dir" >>"$LOG_FILE" 2>&1 || { err "Clone $name gagal"; return 1; }
    local rc=0
    (
        cd "$dir" || exit 1
        meson setup build --buildtype=release "${extra_args[@]}" >>"$LOG_FILE" 2>&1 || exit 1
        ninja -C build >>"$LOG_FILE" 2>&1 || exit 1
        sudo ninja -C build install >>"$LOG_FILE" 2>&1 || exit 1
    ) || rc=$?
    if [[ $rc -eq 0 ]]; then ok "$name berhasil dibuild & dipasang."; sudo ldconfig 2>/dev/null; return 0
    else err "Build $name gagal, cek $LOG_FILE"; return 1; fi
}

build_cargo() {
    # build_cargo <name> <git_url> <bin_name>
    local name="$1" url="$2" bin="$3"
    ensure_cargo_path
    command -v cargo >/dev/null || { err "cargo tidak tersedia, skip $name"; return 1; }

    info "Build $name dari source ($url)..."
    local dir="$BUILD_ROOT/$name"
    git clone --depth 1 "$url" "$dir" >>"$LOG_FILE" 2>&1 || { err "Clone $name gagal"; return 1; }
    local rc=0
    (
        cd "$dir" || exit 1
        cargo build --release >>"$LOG_FILE" 2>&1 || exit 1
        sudo install -Dm755 "target/release/$bin" "/usr/local/bin/$bin" >>"$LOG_FILE" 2>&1 || exit 1
    ) || rc=$?
    if [[ $rc -eq 0 ]] && command -v "$bin" >/dev/null; then ok "$name berhasil dibuild & dipasang."; return 0
    else err "Build $name gagal, cek $LOG_FILE"; return 1; fi
}

# =====================================================================
# 6. BUILD WLROOTS STACK (sway butuh wlroots versi terbaru)
# =====================================================================
build_wlroots() {
    already_installed wlroots && { ok "wlroots sudah ada, skip."; return 0; }

    # Coba repo dulu
    info "Coba install wlroots via repo..."
    if run_pkg_install wlroots-devel >>"$LOG_FILE" 2>&1 && _has_pkgconf wlroots wlroots-0.18 wlroots-0.17 wlroots-0.19; then
        ok "wlroots terpasang via repo."
        return 0
    fi

    install_pkgs base-devel meson ninja git cmake pkgconf wayland wayland-protocols
    # Guard empty: dep_pkg bisa return kosong untuk distro yang tidak punya key ini
    local wlroots_deps; wlroots_deps="$(dep_pkg wlroots-deps)"
    [[ -n "$wlroots_deps" ]] && run_pkg_install $wlroots_deps >>"$LOG_FILE" 2>&1
    build_meson "wlroots" "https://gitlab.freedesktop.org/wlroots/wlroots.git" \
        -Dexamples=false
}

build_sway() {
    already_installed sway && { ok "sway sudah ada, skip."; return 0; }

    # Coba repo dulu
    info "Coba install sway via repo..."
    if run_pkg_install sway >>"$LOG_FILE" 2>&1 && _has_bin sway; then
        ok "sway terpasang via repo."
        return 0
    fi

    build_wlroots || { err "wlroots wajib untuk sway."; return 1; }
    install_pkgs json-c pango cairo
    build_meson "sway" "https://github.com/swaywm/sway.git"
}

build_greetd_and_gtkgreet() {
    if already_installed greetd && already_installed gtkgreet; then
        ok "greetd & gtkgreet sudah ada, skip."; return 0
    fi

    # Coba repo dulu untuk greetd
    if ! already_installed greetd; then
        info "Coba install greetd via repo..."
        if run_pkg_install greetd >>"$LOG_FILE" 2>&1 && _has_bin greetd; then
            ok "greetd terpasang via repo."
        fi
    fi

    # Coba repo dulu untuk gtkgreet
    if ! already_installed gtkgreet; then
        info "Coba install gtkgreet via repo..."
        if run_pkg_install gtkgreet >>"$LOG_FILE" 2>&1 && _has_bin gtkgreet; then
            ok "gtkgreet terpasang via repo."
        fi
    fi

    # Jika keduanya sudah ada dari repo, selesai
    if already_installed greetd && already_installed gtkgreet; then
        return 0
    fi

    install_pkgs meson ninja gtk3 scdoc git
    ensure_cargo_path
    local dir="$BUILD_ROOT/greetd"
    git clone --depth 1 https://github.com/kennylevinsen/greetd.git "$dir" >>"$LOG_FILE" 2>&1 \
        || { err "Clone greetd gagal"; return 1; }

    if ! already_installed greetd; then
        info "Build greetd (daemon, rust)..."
        local rc=0
        ( cd "$dir" && cargo build --release --bin greetd >>"$LOG_FILE" 2>&1 \
            && sudo install -Dm755 target/release/greetd /usr/local/bin/greetd ) || rc=$?
        [[ $rc -eq 0 ]] && ok "greetd terpasang." || err "Build greetd gagal."
    fi

    if ! already_installed gtkgreet; then
        info "Build gtkgreet (meson, GTK3)..."
        if [[ -d "$dir/gtkgreet" ]]; then
            local rc=0
            ( cd "$dir/gtkgreet" \
                && meson setup build --buildtype=release >>"$LOG_FILE" 2>&1 \
                && ninja -C build >>"$LOG_FILE" 2>&1 \
                && sudo ninja -C build install >>"$LOG_FILE" 2>&1 ) || rc=$?
            [[ $rc -eq 0 ]] && ok "gtkgreet terpasang." || err "Build gtkgreet gagal."
        else
            err "Folder gtkgreet tidak ditemukan di repo greetd, struktur repo mungkin berubah."
        fi
    fi
}

build_waybar() {
    already_installed waybar && { ok "waybar sudah ada, skip."; return 0; }

    # Coba repo dulu
    info "Coba install waybar via repo..."
    if run_pkg_install waybar >>"$LOG_FILE" 2>&1 && _has_bin waybar; then
        ok "waybar terpasang via repo."
        return 0
    fi

    install_pkgs meson ninja pkgconf cmake
    if [[ -n "$(dep_pkg waybar-deps)" ]]; then
        install_pkgs waybar-deps
    fi
    build_meson "waybar" "https://github.com/Alexays/Waybar.git"
}

build_kitty() {
    already_installed kitty && { ok "kitty sudah ada, skip."; return 0; }
    info "Install kitty dari installer binary (Kovid Goyal)..."
    curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin >>"$LOG_FILE" 2>&1
    mkdir -p "$HOME/.local/bin/"
    ln -sf "$HOME/.local/kitty.app/bin/kitty" "$HOME/.local/bin/kitty"
    ln -sf "$HOME/.local/kitty.app/bin/kitten" "$HOME/.local/bin/kitten"
    # Tambah PATH ke shell rc yang aktif
    local shell_rc=""
    if [[ -n "${SHELL:-}" ]]; then
        case "$(basename "$SHELL")" in
            fish) shell_rc="$HOME/.config/fish/config.fish" ;;
            zsh)  shell_rc="$HOME/.zshrc" ;;
            *)    shell_rc="$HOME/.bashrc" ;;
        esac
    else
        shell_rc="$HOME/.bashrc"
    fi
    if [[ -n "$shell_rc" ]] && ! grep -qE '(\$HOME|\$\{HOME\}|~)/\.local/bin' "$shell_rc" 2>/dev/null; then
        if [[ "$(basename "$shell_rc")" == "config.fish" ]]; then
            echo 'fish_add_path $HOME/.local/bin' >> "$shell_rc"
        else
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shell_rc"
        fi
    fi
    ok "kitty terpasang via binary installer."
}

build_mako() {
    already_installed mako && { ok "mako sudah ada, skip."; return 0; }

    # Coba repo dulu
    info "Coba install mako via repo..."
    if run_pkg_install mako >>"$LOG_FILE" 2>&1 && _has_bin mako; then
        ok "mako terpasang via repo."
        return 0
    fi

    install_pkgs meson ninja scdoc
    build_meson "mako" "https://github.com/emersion/mako.git"
}

build_grim() {
    already_installed grim && { ok "grim sudah ada, skip."; return 0; }

    # Coba repo dulu
    info "Coba install grim via repo..."
    if run_pkg_install grim >>"$LOG_FILE" 2>&1 && _has_bin grim; then
        ok "grim terpasang via repo."
        return 0
    fi

    install_pkgs meson ninja
    build_meson "grim" "https://github.com/emersion/grim.git"
}

build_slurp() {
    already_installed slurp && { ok "slurp sudah ada, skip."; return 0; }

    # Coba repo dulu
    info "Coba install slurp via repo..."
    if run_pkg_install slurp >>"$LOG_FILE" 2>&1 && _has_bin slurp; then
        ok "slurp terpasang via repo."
        return 0
    fi

    install_pkgs meson ninja
    build_meson "slurp" "https://github.com/emersion/slurp.git"
}

build_mpvpaper() {
    already_installed mpvpaper && { ok "mpvpaper sudah ada, skip."; return 0; }

    # Coba repo dulu
    info "Coba install mpvpaper via repo..."
    if run_pkg_install mpvpaper >>"$LOG_FILE" 2>&1 && _has_bin mpvpaper; then
        ok "mpvpaper terpasang via repo."
        return 0
    fi

    install_pkgs meson ninja mpv-dev
    build_meson "mpvpaper" "https://github.com/GhostNaN/mpvpaper.git"
}

build_brightnessctl() {
    already_installed brightnessctl && { ok "brightnessctl sudah ada, skip."; return 0; }

    # Coba repo dulu
    info "Coba install brightnessctl via repo..."
    if run_pkg_install brightnessctl >>"$LOG_FILE" 2>&1 && _has_bin brightnessctl; then
        ok "brightnessctl terpasang via repo."
        return 0
    fi

    info "Build brightnessctl dari source..."
    local dir="$BUILD_ROOT/brightnessctl"
    git clone https://github.com/Hummer12007/brightnessctl.git "$dir" >>"$LOG_FILE" 2>&1 || return 1
    local rc=0
    (
        cd "$dir" || exit 1
        make >>"$LOG_FILE" 2>&1 || exit 1
        sudo make install >>"$LOG_FILE" 2>&1 || exit 1
    ) || rc=$?
    [[ $rc -eq 0 ]] && ok "brightnessctl berhasil dibuild." || return 1
}

build_anyrun() {
    already_installed anyrun && { ok "anyrun sudah ada, skip."; return 0; }

    # Coba repo dulu
    info "Coba install anyrun via repo..."
    if run_pkg_install anyrun >>"$LOG_FILE" 2>&1 && _has_bin anyrun; then
        ok "anyrun terpasang via repo."
        return 0
    fi

    ensure_cargo_path
    command -v cargo >/dev/null || { err "cargo tidak tersedia, skip anyrun"; return 1; }
    if [[ -n "$(dep_pkg anyrun-deps)" ]]; then
        install_pkgs anyrun-deps
    fi
    info "Build anyrun dari source (github)..."
    local dir="$BUILD_ROOT/anyrun"
    git clone https://github.com/Kirottu/anyrun.git "$dir" >>"$LOG_FILE" 2>&1 || { err "Clone anyrun gagal"; return 1; }
    local rc=0
    (
        cd "$dir" || exit 1
        cargo build --release >>"$LOG_FILE" 2>&1 || exit 1
        sudo install -Dm755 target/release/anyrun /usr/local/bin/anyrun >>"$LOG_FILE" 2>&1 || exit 1
        mkdir -p ~/.config/anyrun/plugins
        # Salin plugin .so yang ada
        find target/release -maxdepth 1 -name '*.so' -exec cp {} ~/.config/anyrun/plugins/ \; 2>/dev/null
    ) || rc=$?
    [[ $rc -eq 0 ]] && ok "anyrun berhasil dibuild & dipasang." || { err "Build anyrun gagal, cek $LOG_FILE"; return 1; }
}

build_rofi_wayland() {
    already_installed rofi && { ok "rofi sudah ada, skip."; return 0; }

    # Coba repo dulu (rofi-wayland atau rofi)
    info "Coba install rofi via repo..."
    if run_pkg_install rofi-wayland >>"$LOG_FILE" 2>&1 && _has_bin rofi; then
        ok "rofi-wayland terpasang via repo."
        return 0
    fi
    if run_pkg_install rofi >>"$LOG_FILE" 2>&1 && _has_bin rofi; then
        ok "rofi terpasang via repo."
        return 0
    fi

    if [[ -n "$(dep_pkg rofi-deps)" ]]; then
        install_pkgs rofi-deps
    fi
    # Tambah dependency dasar build
    install_pkgs base-devel meson ninja wayland-protocols
    info "Build rofi-wayland dari source..."
    local dir="$BUILD_ROOT/rofi-wayland"
    git clone https://github.com/lbonn/rofi.git "$dir" >>"$LOG_FILE" 2>&1 || { err "Clone rofi gagal"; return 1; }
    local rc=0
    (
        cd "$dir" || exit 1
        meson setup build >>"$LOG_FILE" 2>&1 || exit 1
        ninja -C build >>"$LOG_FILE" 2>&1 || exit 1
        sudo ninja -C build install >>"$LOG_FILE" 2>&1 || exit 1
    ) || rc=$?
    [[ $rc -eq 0 ]] && ok "rofi-wayland terpasang." || { err "Build rofi-wayland gagal."; return 1; }
}

build_cosmic_files() {
    already_installed cosmic-files && { ok "cosmic-files sudah ada, skip."; return 0; }

    # Coba repo dulu
    info "Coba install cosmic-files via repo..."
    if run_pkg_install cosmic-files >>"$LOG_FILE" 2>&1 && _has_bin cosmic-files; then
        ok "cosmic-files terpasang via repo."
        return 0
    fi

    ensure_cargo_path
    command -v cargo >/dev/null || { err "cargo tidak tersedia, skip cosmic-files."; return 1; }
    info "Build cosmic-files dari source (github)..."
    local dir="$BUILD_ROOT/cosmic-files"
    git clone --depth 1 https://github.com/pop-os/cosmic-files.git "$dir" >>"$LOG_FILE" 2>&1 || { err "Clone cosmic-files gagal"; return 1; }
    local rc=0
    (
        cd "$dir" || exit 1
        cargo build --release >>"$LOG_FILE" 2>&1 || exit 1
        mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
        install -Dm755 target/release/cosmic-files "$HOME/.local/bin/cosmic-files" >>"$LOG_FILE" 2>&1 || exit 1
        if [[ -f "res/com.system76.CosmicFiles.desktop" ]]; then
            mkdir -p "$HOME/.local/share/icons/hicolor/scalable/apps"
            cp -r res/icons/* "$HOME/.local/share/icons/" 2>/dev/null || true
            install -Dm644 res/com.system76.CosmicFiles.desktop "$HOME/.local/share/applications/" 2>/dev/null || true
            sed -i "s|Exec=cosmic-files|Exec=$HOME/.local/bin/cosmic-files|g" "$HOME/.local/share/applications/com.system76.CosmicFiles.desktop" 2>/dev/null || true
        fi
    ) || rc=$?
    [[ $rc -eq 0 ]] && ok "cosmic-files berhasil dibuild." || { err "Build cosmic-files gagal."; return 1; }
}

build_wofi() {
    already_installed wofi && { ok "wofi sudah ada, skip."; return 0; }

    # Coba repo dulu
    info "Coba install wofi via repo..."
    if run_pkg_install wofi >>"$LOG_FILE" 2>&1 && _has_bin wofi; then
        ok "wofi terpasang via repo."
        return 0
    fi

    install_pkgs hg meson ninja
    info "Build wofi dari source..."
    local dir="$BUILD_ROOT/wofi"
    hg clone https://hg.sr.ht/~scoopta/wofi "$dir" >>"$LOG_FILE" 2>&1 || { err "Clone wofi gagal"; return 1; }
    local rc=0
    (
        cd "$dir" || exit 1
        meson setup build >>"$LOG_FILE" 2>&1 || exit 1
        ninja -C build >>"$LOG_FILE" 2>&1 || exit 1
        sudo ninja -C build install >>"$LOG_FILE" 2>&1 || exit 1
    ) || rc=$?
    [[ $rc -eq 0 ]] && ok "wofi berhasil dibuild." || { err "Build wofi gagal."; return 1; }
}

install_launcher() {
    info "Menyiapkan Application Launcher (Fallback: anyrun > rofi > wofi)..."
    if already_installed anyrun; then ok "Launcher terpilih: anyrun"; return 0; fi
    if already_installed rofi; then ok "Launcher terpilih: rofi"; return 0; fi
    if already_installed wofi; then ok "Launcher terpilih: wofi"; return 0; fi

    if build_anyrun; then
        ok "Launcher terpilih: anyrun"; return 0
    fi
    warn "Anyrun gagal, mencoba rofi-wayland..."
    if build_rofi_wayland; then
        ok "Launcher terpilih: rofi"; return 0
    fi
    warn "Rofi gagal, mencoba wofi..."
    if build_wofi; then
        ok "Launcher terpilih: wofi"; return 0
    fi
    err "Semua opsi launcher gagal diinstall."
}

build_wallust() {
    already_installed wallust && { ok "wallust sudah ada, skip."; return 0; }
    ensure_cargo_path
    command -v cargo >/dev/null || { err "cargo tidak tersedia, skip wallust"; return 1; }
    info "Install wallust via cargo..."
    local rc=0
    cargo install wallust >>"$LOG_FILE" 2>&1 || rc=$?
    [[ $rc -eq 0 ]] && ok "wallust berhasil dipasang." || { err "Install wallust gagal, cek $LOG_FILE"; return 1; }
}

build_fastfetch() {
    already_installed fastfetch && { ok "fastfetch sudah ada, skip."; return 0; }
    info "Coba install fastfetch via repo..."
    if try_repo_install fastfetch; then ok "fastfetch terpasang via repo."; return 0; fi
    info "Build fastfetch dari source..."
    install_pkgs cmake
    local dir="$BUILD_ROOT/fastfetch"
    git clone https://github.com/fastfetch-cli/fastfetch.git "$dir" >>"$LOG_FILE" 2>&1 || { err "Clone fastfetch gagal"; return 1; }
    local rc=0
    (
        cd "$dir" || exit 1
        mkdir build && cd build
        cmake .. >>"$LOG_FILE" 2>&1 || exit 1
        cmake --build . --target fastfetch --target flashfetch >>"$LOG_FILE" 2>&1 || exit 1
        sudo cmake --install . --prefix /usr/local >>"$LOG_FILE" 2>&1 || exit 1
    ) || rc=$?
    [[ $rc -eq 0 ]] && ok "fastfetch berhasil dibuild & dipasang." || { err "Build fastfetch gagal, cek $LOG_FILE"; return 1; }
}

build_wfrecorder() {
    already_installed wf-recorder && { ok "wf-recorder sudah ada, skip."; return 0; }

    # Coba repo dulu
    info "Coba install wf-recorder via repo..."
    if run_pkg_install wf-recorder >>"$LOG_FILE" 2>&1 && _has_bin wf-recorder; then
        ok "wf-recorder terpasang via repo."
        return 0
    fi

    install_pkgs meson ninja
    build_meson "wf-recorder" "https://github.com/ammen99/wf-recorder.git"
}

build_swaylock() {
    already_installed swaylock && { ok "swaylock sudah ada, skip."; return 0; }

    # Coba repo dulu
    info "Coba install swaylock via repo..."
    if run_pkg_install swaylock >>"$LOG_FILE" 2>&1 && _has_bin swaylock; then
        ok "swaylock terpasang via repo."
        return 0
    fi

    install_pkgs meson ninja
    build_meson "swaylock" "https://github.com/swaywm/swaylock.git"
}

build_swayidle() {
    already_installed swayidle && { ok "swayidle sudah ada, skip."; return 0; }

    # Coba repo dulu
    info "Coba install swayidle via repo..."
    if run_pkg_install swayidle >>"$LOG_FILE" 2>&1 && _has_bin swayidle; then
        ok "swayidle terpasang via repo."
        return 0
    fi

    install_pkgs meson ninja
    build_meson "swayidle" "https://github.com/swaywm/swayidle.git"
}

# swww: daemon wallpaper dengan transisi animasi (fade/wipe/wave 144fps).
# Tidak tersedia di crates.io — build dari git via cargo.
build_swww() {
    already_installed swww && already_installed swww-daemon && { ok "swww sudah ada, skip."; return 0; }

    # Dependensi kompilasi: lz4 (liblz4) + wayland
    case "$DISTRO_FAMILY" in
        rhel)   run_pkg_install lz4-devel wayland-devel >>"$LOG_FILE" 2>&1 || true ;;
        debian) run_pkg_install liblz4-dev libwayland-dev >>"$LOG_FILE" 2>&1 || true ;;
        arch)   run_pkg_install lz4 wayland >>"$LOG_FILE" 2>&1 || true ;;
        suse)   run_pkg_install liblz4-devel wayland-devel >>"$LOG_FILE" 2>&1 || true ;;
        alpine) run_pkg_install lz4-dev wayland-dev >>"$LOG_FILE" 2>&1 || true ;;
        void)   run_pkg_install liblz4-devel wayland-devel >>"$LOG_FILE" 2>&1 || true ;;
    esac

    ensure_cargo_path
    info "Build swww dari git (cargo)..."
    if cargo install --git https://github.com/LGFae/swww.git swww >>"$LOG_FILE" 2>&1 && _has_bin swww; then
        ok "swww terpasang."
    else
        warn "swww gagal di-build — transisi wallpaper dinonaktifkan (fallback swaybg)."
    fi
}

# matugen: Material You color generator dari wallpaper.
build_matugen() {
    already_installed matugen && { ok "matugen sudah ada, skip."; return 0; }

    case "$DISTRO_FAMILY" in
        arch)   run_pkg_install matugen >>"$LOG_FILE" 2>&1 || true ;;
        *)      : ;; # distro lain: dari crates.io
    esac
    _has_bin matugen && { ok "matugen terpasang via repo."; return 0; }

    ensure_cargo_path
    info "Build matugen (cargo)..."
    if cargo install matugen >>"$LOG_FILE" 2>&1 && _has_bin matugen; then
        ok "matugen terpasang."
    else
        warn "matugen gagal di-build — warna adaptif dinonaktifkan (pakai palet tema)."
    fi
}

build_cava() {
    already_installed cava && { ok "cava sudah ada, skip."; return 0; }

    # Coba repo dulu
    info "Coba install cava via repo..."
    if run_pkg_install cava >>"$LOG_FILE" 2>&1 && _has_bin cava; then
        ok "cava terpasang via repo."
        return 0
    fi

    info "Build cava dari source..."
    install_pkgs cmake base-devel
    case "$DISTRO_FAMILY" in
        arch)   run_pkg_install fftw ncurses alsa-lib pipewire >>"$LOG_FILE" 2>&1 || true ;;
        debian) run_pkg_install libfftw3-dev libncursesw5-dev libasound2-dev libpipewire-0.3-dev >>"$LOG_FILE" 2>&1 || true ;;
        rhel)   run_pkg_install fftw-devel ncurses-devel alsa-lib-devel pipewire-devel >>"$LOG_FILE" 2>&1 || true ;;
        suse)   run_pkg_install fftw3-devel ncurses-devel alsa-devel pipewire-devel >>"$LOG_FILE" 2>&1 || true ;;
        alpine) run_pkg_install fftw-dev ncurses-dev alsa-lib-dev pipewire-dev >>"$LOG_FILE" 2>&1 || true ;;
        void)   run_pkg_install fftw-devel ncurses-devel alsa-lib-devel pipewire-devel >>"$LOG_FILE" 2>&1 || true ;;
    esac

    local dir="$BUILD_ROOT/cava"
    git clone --depth 1 https://github.com/karlstav/cava.git "$dir" >>"$LOG_FILE" 2>&1 || { err "Clone cava gagal"; return 1; }
    local rc=0
    (
        cd "$dir" || exit 1
        ./autogen.sh >>"$LOG_FILE" 2>&1 || true
        ./configure --prefix=/usr/local >>"$LOG_FILE" 2>&1 || exit 1
        make >>"$LOG_FILE" 2>&1 || exit 1
        sudo make install >>"$LOG_FILE" 2>&1 || exit 1
    ) || rc=$?
    [[ $rc -eq 0 ]] && ok "cava berhasil dibuild & dipasang." || { err "Build cava gagal, cek $LOG_FILE"; return 1; }
}

build_xdg_desktop_portal_wlr() {
    # Cek apakah sudah terinstal DAN compatible dengan wlroots saat ini.
    # xdg-desktop-portal-wlr >= 0.7.0 menggunakan ext_image_capture_source_v1
    # yang TIDAK tersedia di wlroots 0.18.x — menyebabkan "No supported targets"
    # saat share screen. Kita pin ke v0.6.0 yang pakai zwlr_screencopy_manager_v1.
    local NEEDS_REBUILD=0
    if _has_bin xdg-desktop-portal-wlr; then
        # Cek apakah binary yang terinstal punya ext_image_capture_source_v1
        # (tanda versi >= 0.7.0 yang incompatible dengan wlroots 0.18)
        if strings /usr/local/libexec/xdg-desktop-portal-wlr 2>/dev/null | \
           grep -q "ext_image_capture_source_v1_interface"; then
            warn "xdg-desktop-portal-wlr terinstal tapi versi incompatible (>= 0.7.0)."
            warn "Akan rebuild dari v0.6.0 untuk compatibility dengan wlroots 0.18."
            NEEDS_REBUILD=1
        else
            ok "xdg-desktop-portal-wlr sudah ada dan compatible, skip."
            return 0
        fi
    fi

    # Coba repo dulu (hanya kalau belum terinstal)
    if [[ $NEEDS_REBUILD -eq 0 ]]; then
        info "Coba install xdg-desktop-portal-wlr via repo..."
        if run_pkg_install xdg-desktop-portal-wlr >>"$LOG_FILE" 2>&1 && _has_bin xdg-desktop-portal-wlr; then
            # Cek versi dari repo — kalau incompatible, rebuild
            if strings /usr/local/libexec/xdg-desktop-portal-wlr 2>/dev/null | \
               grep -q "ext_image_capture_source_v1_interface"; then
                warn "Versi repo incompatible, akan rebuild dari source."
            else
                ok "xdg-desktop-portal-wlr terpasang via repo."
                return 0
            fi
        fi
    fi

    info "Build xdg-desktop-portal-wlr v0.6.0 dari source (untuk screen sharing)..."

    # Install dependencies
    install_pkgs meson ninja wayland wayland-protocols
    case "$DISTRO_FAMILY" in
        arch)
            run_pkg_install pipewire inih >>"$LOG_FILE" 2>&1 || true
            ;;
        debian)
            run_pkg_install libpipewire-0.3-dev libinih-dev libsystemd-dev >>"$LOG_FILE" 2>&1 || true
            ;;
        rhel)
            run_pkg_install pipewire-devel inih-devel systemd-devel >>"$LOG_FILE" 2>&1 || true
            ;;
        suse)
            run_pkg_install pipewire-devel libinih-devel systemd-devel >>"$LOG_FILE" 2>&1 || true
            ;;
        alpine)
            run_pkg_install pipewire-dev inih-dev eudev-dev >>"$LOG_FILE" 2>&1 || true
            ;;
        void)
            run_pkg_install pipewire-devel inih-devel eudev-libudev-devel >>"$LOG_FILE" 2>&1 || true
            ;;
    esac

    # Build dari source — PIN ke v0.6.0 (compatible dengan wlroots 0.18.x)
    # v0.7.0+ pakai ext_image_capture_source_v1 yang tidak ada di wlroots 0.18,
    # menyebabkan "No supported targets specified" saat share screen.
    local dir="$BUILD_ROOT/xdg-desktop-portal-wlr"
    git clone --depth 1 --branch v0.6.0 \
        "https://github.com/emersion/xdg-desktop-portal-wlr.git" "$dir" \
        >>"$LOG_FILE" 2>&1 || { err "Clone xdg-desktop-portal-wlr v0.6.0 gagal"; return 1; }
    local rc=0
    (
        cd "$dir" || exit 1
        meson setup build --prefix=/usr/local --libexecdir=/usr/local/libexec \
            --buildtype=release -Dsd-bus-provider=libsystemd \
            >>"$LOG_FILE" 2>&1 || exit 1
        ninja -C build >>"$LOG_FILE" 2>&1 || exit 1
        sudo ninja -C build install >>"$LOG_FILE" 2>&1 || exit 1
    ) || rc=$?
    if [[ $rc -ne 0 ]]; then
        err "Build xdg-desktop-portal-wlr v0.6.0 gagal, cek $LOG_FILE"
        return 1
    fi
    sudo ldconfig 2>/dev/null

    # Symlink dari libexec ke /usr/local/bin agar ada di PATH
    if [[ -x /usr/local/libexec/xdg-desktop-portal-wlr ]]; then
        sudo ln -sf /usr/local/libexec/xdg-desktop-portal-wlr /usr/local/bin/xdg-desktop-portal-wlr 2>/dev/null || true
    fi

    # PENTING: xdg-desktop-portal (daemon utama, biasanya dari paket distro/RPM)
    # hardcode mencari file *.portal HANYA di <datadir-compile-time>/xdg-desktop-portal/portals
    # (biasanya /usr/share/...) dan TIDAK mengikuti XDG_DATA_DIRS untuk pencarian ini.
    # Karena xdg-desktop-portal-wlr di-build dengan --prefix=/usr/local, file wlr.portal
    # hasil build nyasar ke /usr/local/share/xdg-desktop-portal/portals/ — lokasi yang
    # TIDAK PERNAH dibaca oleh daemon utama. Salin manual ke /usr/share.
    if [[ -f /usr/local/share/xdg-desktop-portal/portals/wlr.portal ]]; then
        sudo mkdir -p /usr/share/xdg-desktop-portal/portals
        sudo cp -f /usr/local/share/xdg-desktop-portal/portals/wlr.portal /usr/share/xdg-desktop-portal/portals/wlr.portal
        ok "wlr.portal disalin ke /usr/share/xdg-desktop-portal/portals/."
    fi

    # Restart portal service agar pakai binary baru
    systemctl_user try-restart xdg-desktop-portal-wlr.service 2>/dev/null || true

    if _has_bin xdg-desktop-portal-wlr; then
        ok "xdg-desktop-portal-wlr v0.6.0 berhasil dibuild & dipasang."
        return 0
    else
        warn "xdg-desktop-portal-wlr gagal dibuild, screen sharing mungkin tidak berfungsi."
        return 1
    fi
}

build_fish() {
    already_installed fish && { ok "fish shell sudah ada, skip."; return 0; }
    info "Coba install fish via repo..."
    if try_repo_install fish; then 
        ok "fish terpasang via repo."
        return 0
    fi
    
    # Jika gagal, build dari source
    info "Build fish dari source..."
    install_pkgs cmake base-devel
    case "$DISTRO_FAMILY" in
        arch)   run_pkg_install pcre2 >>"$LOG_FILE" 2>&1 || true ;;
        debian) run_pkg_install libpcre2-dev gettext >>"$LOG_FILE" 2>&1 || true ;;
        rhel)   run_pkg_install pcre2-devel gettext-devel >>"$LOG_FILE" 2>&1 || true ;;
        suse)   run_pkg_install pcre2-devel gettext-tools >>"$LOG_FILE" 2>&1 || true ;;
        alpine) run_pkg_install pcre2-dev gettext-dev >>"$LOG_FILE" 2>&1 || true ;;
        void)   run_pkg_install pcre2-devel gettext-devel >>"$LOG_FILE" 2>&1 || true ;;
    esac
    
    local dir="$BUILD_ROOT/fish"
    git clone --depth 1 https://github.com/fish-shell/fish-shell.git "$dir" >>"$LOG_FILE" 2>&1 || { err "Clone fish gagal"; return 1; }
    local rc=0
    (
        cd "$dir" || exit 1
        cmake . -DCMAKE_INSTALL_PREFIX=/usr/local >>"$LOG_FILE" 2>&1 || exit 1
        make >>"$LOG_FILE" 2>&1 || exit 1
        sudo make install >>"$LOG_FILE" 2>&1 || exit 1
    ) || rc=$?
    [[ $rc -eq 0 ]] && ok "fish berhasil dibuild & dipasang." || { err "Build fish gagal"; return 1; }
}

# =====================================================================
# 6b. UTILITAS SISTEM BAWAAN DESKTOP (GNOME/KDE) — TAPI TIDAK ADA DI MINIMAL
# =====================================================================
# Rice ini awalnya dikembangkan di atas Rocky Linux yang SUDAH terpasang GNOME,
# sehingga banyak tool "diam-diam" tersedia (python3, ImageMagick, pipewire,
# dbus, gsettings, NetworkManager, fontconfig, dst). Di instalasi minimal /
# server / distro lain, tool-tool ini BELUM tentu ada, padahal config sway,
# waybar, dan script rice bergantung padanya. Pasang eksplisit via repo.
#
# Pemetaan nama paket dibedakan per family karena berbeda-beda.
install_system_utils() {
    info "=== Memasang utilitas sistem yang dibutuhkan config & script ==="

    # --- ESENSIAL: fitur inti rusak tanpa ini ---
    #   imagemagick     : blur lock screen (Super+L) + generator preview tema
    #   python3         : auto-split dwindle tiling, theme-switcher, reload keybind
    #   pipewire (+pulse): server audio (wpctl volume, pw-record perekaman)
    #   wireplumber     : session manager pipewire (wpctl)
    #   xdg-utils       : xdg-mime / xdg-settings / xdg-open (default apps)
    #   dbus            : dbus-update-activation-environment (env portal)
    #   fontconfig      : fc-cache (registrasi font)
    #   dconf + schemas : gsettings (dark theme GTK + cursor theme)
    #   NetworkManager  : nmtui / nm-connection-editor (klik network di waybar)
    local essential=()
    case "$DISTRO_FAMILY" in
        arch)
            essential=(imagemagick python pipewire pipewire-pulse wireplumber
                       xdg-utils dbus fontconfig dconf gsettings-desktop-schemas
                       glib2 networkmanager) ;;
        debian)
            essential=(imagemagick python3 pipewire pipewire-pulse wireplumber
                       xdg-utils dbus fontconfig dconf-cli gsettings-desktop-schemas
                       libglib2.0-bin network-manager) ;;
        rhel)
            essential=(ImageMagick python3 pipewire pipewire-pulseaudio wireplumber
                       xdg-utils dbus fontconfig dconf gsettings-desktop-schemas
                       glib2 NetworkManager NetworkManager-tui nm-connection-editor) ;;
        suse)
            essential=(ImageMagick python3 pipewire pipewire-pulseaudio wireplumber
                       xdg-utils dbus-1 fontconfig dconf gsettings-desktop-schemas
                       glib2-tools NetworkManager NetworkManager-connection-editor) ;;
        alpine)
            essential=(imagemagick python3 pipewire pipewire-pulse wireplumber
                       xdg-utils dbus fontconfig dconf gsettings-desktop-schemas
                       glib networkmanager) ;;
        void)
            essential=(ImageMagick python3 pipewire wireplumber
                       xdg-utils dbus fontconfig dconf gsettings-desktop-schemas
                       glib NetworkManager) ;;
        *)
            essential=(imagemagick python3 pipewire wireplumber xdg-utils dbus fontconfig) ;;
    esac
    if [[ ${#essential[@]} -gt 0 ]]; then
        info "Utilitas esensial: ${essential[*]}"
        run_pkg_install "${essential[@]}" || warn "Sebagian utilitas esensial gagal dipasang — cek $LOG_FILE"
    fi

    # Verifikasi cepat tool paling kritikal, beri panduan bila gagal.
    _has_bin convert || _has_bin magick || warn "ImageMagick (convert/magick) tidak ada — lock screen blur & preview tema nonaktif."
    _has_bin python3 || _has_bin python  || warn "python3 tidak ada — auto-split tiling & theme switcher tidak berfungsi."

    # --- OPSIONAL: fitur tambahan; script sudah fallback bila tidak ada ---
    #   cliphist : riwayat clipboard (Super+Shift+V)
    #   wtype    : auto-paste setelah pilih item clipboard
    #   wlsunset : night light / filter cahaya biru (quick-settings)
    #   gammastep: alternatif night light
    local optional=()
    case "$DISTRO_FAMILY" in
        arch)   optional=(cliphist wtype wlsunset) ;;
        debian) optional=(wtype wlsunset gammastep) ;;
        rhel)   optional=(wlsunset) ;;
        suse)   optional=(wtype wlsunset) ;;
        alpine) optional=(wtype wlsunset) ;;
        void)   optional=(wtype wlsunset) ;;
    esac
    for pkg in "${optional[@]}"; do
        run_pkg_install "$pkg" >>"$LOG_FILE" 2>&1 \
            && ok "$pkg terpasang (opsional)." \
            || warn "$pkg tidak tersedia di repo (opsional, dilewati)."
    done

    # cliphist tidak ada di repo kebanyakan distro (program Go). Coba build via
    # `go install` bila Go tersedia — best-effort, tidak menggagalkan install.
    install_cliphist
}

# cliphist: manajer riwayat clipboard untuk Wayland (dipakai Super+Shift+V).
# Tersedia langsung di repo Arch; di distro lain di-build via Go.
install_cliphist() {
    _has_bin cliphist && { ok "cliphist sudah ada, skip."; return 0; }
    if command -v go >/dev/null 2>&1; then
        info "Build cliphist via Go (go install)..."
        if GOBIN="$HOME/.local/bin" go install go.senan.xyz/cliphist@latest >>"$LOG_FILE" 2>&1 \
            && _has_bin cliphist; then
            ok "cliphist terpasang ke ~/.local/bin (riwayat clipboard aktif)."
            return 0
        fi
    fi
    warn "cliphist tidak terpasang — riwayat clipboard (Super+Shift+V) dinonaktifkan."
    return 0
}

# =====================================================================
# 7. MAIN INSTALL FLOW
# =====================================================================
install_repo_only_deps() {
    info "=== Memasang paket yang biasanya tersedia di repo resmi ==="
    for pkg in mpv wl-clipboard ffmpeg nautilus seatd brightnessctl pavucontrol nm-applet; do
        if already_installed "$pkg"; then
            ok "$pkg sudah ada."
        elif try_repo_install "$pkg"; then
            ok "$pkg terpasang via repo."
        else
            warn "$pkg gagal/tidak ada di repo."
            if [[ "$pkg" == "brightnessctl" ]]; then
                build_brightnessctl || warn "Gagal build brightnessctl dari source."
            fi
        fi
    done

    # Runtime deps yang dipakai config sway/waybar tapi sering tidak terpasang
    # Install satu per satu karena availability berbeda per distro.
    # Pakai dep_pkg runtime-deps yang sudah didefinisikan per distro di atas,
    # iterasi nama paket individual agar tidak ada duplikasi case.
    info "Memasang runtime dependencies (notify-send, wpctl, tuned, portal, dll)..."
    local runtime_pkg_list; runtime_pkg_list="$(dep_pkg runtime-deps)"
    if [[ -n "$runtime_pkg_list" ]]; then
        for pkg_name in $runtime_pkg_list; do
            run_pkg_install "$pkg_name" >>"$LOG_FILE" 2>&1 || true
        done
    fi
    # Aktifkan seatd (systemd atau OpenRC)
    if command -v systemctl >/dev/null; then
        sudo systemctl enable --now seatd 2>/dev/null || true
    elif command -v rc-update >/dev/null; then
        sudo rc-update add seatd default 2>/dev/null || true
        sudo rc-service seatd start 2>/dev/null || true
    fi
}

install_core_stack() {
    info "=== Build/Install stack inti (wlroots ecosystem) ==="
    build_sway
    build_greetd_and_gtkgreet
    build_waybar
    build_kitty
    build_mako
    build_grim
    build_slurp
    build_mpvpaper
    build_brightnessctl
    build_cosmic_files
    install_launcher
    build_fastfetch
    build_wallust
    build_wfrecorder
    build_swaylock
    build_swayidle
    build_cava
    build_swww
    build_matugen

    # Install xdg-desktop-portal-wlr (untuk screen sharing)
    info "=== Install xdg-desktop-portal-wlr untuk screen sharing ==="
    if ! build_xdg_desktop_portal_wlr; then
        warn "xdg-desktop-portal-wlr gagal diinstall, screen sharing mungkin tidak berfungsi di browser."
    fi
    
    # Install fish shell
    info "=== Install fish shell ==="
    if ! already_installed fish; then
        if ! build_fish; then
            warn "fish shell gagal diinstall, menggunakan bash sebagai gantinya."
        fi
    fi
}

install_fonts() {
    info "=== Memasang font ==="
    local font_dir="$HOME/.local/share/fonts"
    mkdir -p "$font_dir"

    if [[ -d "$REPO_DIR/fonts" ]] && [[ -n "$(ls -A "$REPO_DIR/fonts" 2>/dev/null)" ]]; then
        cp -n "$REPO_DIR"/fonts/*.ttf "$font_dir/" 2>/dev/null
        ok "Font dari repo lokal disalin."
    fi

    ok "Font (Rajdhani + JetBrainsMono Nerd Font) sudah tersedia di repo."

    fc-cache -f "$font_dir" >>"$LOG_FILE" 2>&1
}

setup_greetd_user() {
    info "Menyiapkan pengguna dan izin untuk greetd..."
    local nologin_path
    if command -v nologin >/dev/null 2>&1; then
        nologin_path=$(command -v nologin)
    elif [[ -x /sbin/nologin ]]; then
        nologin_path="/sbin/nologin"
    elif [[ -x /usr/sbin/nologin ]]; then
        nologin_path="/usr/sbin/nologin"
    else
        nologin_path="/bin/false"
    fi

    if ! grep -q "^${nologin_path}$" /etc/shells 2>/dev/null; then
        echo "$nologin_path" | sudo tee -a /etc/shells >/dev/null
        ok "Menambahkan $nologin_path ke /etc/shells"
    fi

    if ! id "greeter" >/dev/null 2>&1; then
        sudo useradd -M -d /var/lib/greetd -s "$nologin_path" greeter
        ok "Pengguna 'greeter' berhasil dibuat."
    fi

    # Tambahkan greeter ke semua group yang relevan (sekali saja)
    sudo usermod -aG video,render greeter 2>>"$LOG_FILE" || true
    sudo chown -R greeter:greeter /etc/greetd
    sudo find /etc/greetd -type d -exec chmod 755 {} \;
    sudo find /etc/greetd -type f -exec chmod 644 {} \;
    ok "Izin direktori /etc/greetd telah disesuaikan."
}

deploy_configs() {
    info "Menyalin konfigurasi ke direktori sistem dan pengguna..."

    if [[ -d "$HOME/.config/sway" && $FORCE_INSTALL -eq 0 ]]; then
        warn "Konfigurasi sudah ada. Mengamankan ke ~/.config-backup..."
        mkdir -p "$HOME/.config-backup"
        local config_dirs=(sway waybar anyrun mako kitty fastfetch wallust)
        for d in "${config_dirs[@]}"; do
            [[ -d "$HOME/.config/$d" ]] && mv "$HOME/.config/$d" "$HOME/.config-backup/" 2>/dev/null || true
        done
    fi

    local config_dirs=(sway waybar anyrun mako kitty fish fastfetch wallust rofi wofi cava gtk-3.0 matugen)
    for d in "${config_dirs[@]}"; do
        mkdir -p "$HOME/.config/$d"
    done
    mkdir -p "$HOME/.config/matugen/templates"
    mkdir -p "$HOME/.local/bin"

    # === MATUGEN (warna adaptif dari wallpaper) ===
    if [[ -d "$REPO_DIR/themes/matugen" ]]; then
        cp "$REPO_DIR/themes/matugen/config.toml" "$HOME/.config/matugen/config.toml" 2>/dev/null || true
        for tmpl in "$REPO_DIR/themes/matugen/templates/"*; do
            [[ -f "$tmpl" ]] && cp "$tmpl" "$HOME/.config/matugen/templates/"
        done
        ok "Konfigurasi matugen disalin."
    fi

    # === FALLBACK COLORS (dipakai sebelum matugen pertama kali jalan) ===
    # Waybar colors.css - di-import oleh style.css
    if [[ ! -f "$HOME/.config/waybar/colors.css" ]]; then
        cat > "$HOME/.config/waybar/colors.css" << 'COLORS_EOF'
/* Fallback colors (sebelum matugen generate) - Raiden theme */
@define-color background #1A1621;
@define-color foreground #ECE4F4;
@define-color accent     #9370DB;
@define-color accent-alt #D4AF37;
@define-color urgent     #F44747;
@define-color success    #A6E22E;
COLORS_EOF
        ok "Fallback waybar/colors.css dibuat."
    fi

    # Sway colors.conf - di-include oleh config
    if [[ ! -f "$HOME/.config/sway/colors.conf" ]]; then
        cat > "$HOME/.config/sway/colors.conf" << 'COLORS_EOF'
# Fallback colors (sebelum matugen generate) - Raiden theme
set $bg         #1A1621
set $fg         #ECE4F4
set $accent     #9370DB
set $accent-alt #D4AF37
client.focused          $accent     $accent     $fg         $accent-alt
client.focused_inactive $bg         $bg         $fg         $bg
client.unfocused        $bg         $bg         #888888     $bg
client.urgent           $bg         $bg         $fg         $bg
COLORS_EOF
        ok "Fallback sway/colors.conf dibuat."
    fi

    # Kitty colors.conf
    if [[ ! -f "$HOME/.config/kitty/colors.conf" ]]; then
        cat > "$HOME/.config/kitty/colors.conf" << 'COLORS_EOF'
# Fallback colors (sebelum matugen generate) - Raiden theme
foreground #ECE4F4
background #1A1621
color0     #1A1621
color1     #F44747
color2     #A6E22E
color3     #D4AF37
color4     #6699CC
color5     #9370DB
color6     #5FB3B3
color7     #ECE4F4
color8     #5A5A5A
color9     #F44747
color10    #A6E22E
color11    #D4AF37
color12    #6699CC
color13    #9370DB
color14    #5FB3B3
color15    #ECE4F4
COLORS_EOF
        ok "Fallback kitty/colors.conf dibuat."
    fi

    # Mako colors.ini
    if [[ ! -f "$HOME/.config/mako/colors.ini" ]]; then
        cat > "$HOME/.config/mako/colors.ini" << 'COLORS_EOF'
# Fallback colors (sebelum matugen generate) - Raiden theme
background-color=#1A1621
text-color=#ECE4F4
border-color=#9370DB
COLORS_EOF
        ok "Fallback mako/colors.ini dibuat."
    fi

    # Cava colors.ini
    mkdir -p "$HOME/.config/cava"
    if [[ ! -f "$HOME/.config/cava/colors.ini" ]]; then
        cat > "$HOME/.config/cava/colors.ini" << 'COLORS_EOF'
[color]
gradient = 1
gradient_count = 2
gradient_color_1 = '#9370DB'
gradient_color_2 = '#D4AF37'
COLORS_EOF
        ok "Fallback cava/colors.ini dibuat."
    fi

    # === WALLPAPER PICKER ===
    if [[ -f "$REPO_DIR/themes/wallpaper-picker.sh" ]]; then
        cp "$REPO_DIR/themes/wallpaper-picker.sh" "$HOME/.local/bin/wallpaper-picker.sh"
        chmod +x "$HOME/.local/bin/wallpaper-picker.sh"
        ok "Wallpaper picker terpasang (Mod+W, wofi grid)."
    fi

    # === THEME SWITCHER ===
    if [[ -f "$REPO_DIR/themes/theme-switch.sh" ]]; then
        cp "$REPO_DIR/themes/theme-switch.sh" "$HOME/.local/bin/theme-switch.sh"
        chmod +x "$HOME/.local/bin/theme-switch.sh"
    fi
    if [[ -f "$REPO_DIR/themes/theme-switcher.sh" ]]; then
        cp "$REPO_DIR/themes/theme-switcher.sh" "$HOME/.local/bin/theme-switcher.sh"
        chmod +x "$HOME/.local/bin/theme-switcher.sh"
    fi
    if [[ -f "$REPO_DIR/themes/theme-switch-wofi.sh" ]]; then
        cp "$REPO_DIR/themes/theme-switch-wofi.sh" "$HOME/.local/bin/theme-switch-wofi.sh"
        chmod +x "$HOME/.local/bin/theme-switch-wofi.sh"
    fi
    if [[ -f "$REPO_DIR/themes/_gen-preview.sh" ]]; then
        cp "$REPO_DIR/themes/_gen-preview.sh" "$HOME/.local/bin/_gen-preview.sh"
        chmod +x "$HOME/.local/bin/_gen-preview.sh"
    fi
    # Bersihkan script Python lama (deprecated)
    rm -f "$HOME/.local/bin/theme-switcher.py" "$HOME/.local/bin/wallpaper-picker.py"
    ok "Theme switcher terpasang (Mod+T UI, Mod+Y menu, Mod+Shift+T next)."

    # Sway configs (wajib ada)
    cp "$THEME_DIR/config/sway/config"          "$HOME/.config/sway/config" 2>/dev/null || warn "sway/config tidak ditemukan"
    for script in powermenu.sh gui-recorder.sh brightness-menu.sh brightness.sh lock.sh; do
        if [[ -f "$THEME_DIR/config/sway/$script" ]]; then
            # Gunakan -L untuk dereference symlink (tema memakai symlink ke common/scripts/)
            cp -L "$THEME_DIR/config/sway/$script" "$HOME/.config/sway/$script"
            chmod +x "$HOME/.config/sway/$script"
        fi
    done
    ok "Konfigurasi sway disalin."

    # === COMMON ASSETS (shared di semua tema) ===
    # common/scripts/ → ~/.config/sway/ (helper scripts yang dipakai sway config)
    if [[ -d "$REPO_DIR/common/scripts" ]]; then
        for script in "$REPO_DIR/common/scripts/"*.sh; do
            [[ -f "$script" ]] || continue
            cp -L "$script" "$HOME/.config/sway/$(basename "$script")"
            chmod +x "$HOME/.config/sway/$(basename "$script")"
        done
        ok "Common scripts disalin ke ~/.config/sway/."
    fi

    # common/systemd-user/ → ~/.config/systemd/user/ (user services: waybar, mako, swww-daemon)
    if [[ -d "$REPO_DIR/common/systemd-user" ]]; then
        mkdir -p "$HOME/.config/systemd/user"
        for svc in "$REPO_DIR/common/systemd-user/"*.service; do
            [[ -f "$svc" ]] || continue
            cp "$svc" "$HOME/.config/systemd/user/$(basename "$svc")"
        done
        systemctl_user daemon-reload 2>/dev/null || true
        # Enable services (PartOf=graphical-session.target — di-start saat sway aktif)
        for svc in "$REPO_DIR/common/systemd-user/"*.service; do
            [[ -f "$svc" ]] || continue
            local svc_name
            svc_name=$(basename "$svc")
            # sway-graphical-session.service tidak punya [Install] section — skip enable
            [[ "$svc_name" == "sway-graphical-session.service" ]] && continue
            systemctl_user enable "$svc_name" 2>/dev/null || true
        done
        ok "Systemd user services di-deploy (waybar, mako, swww-daemon)."
    fi

    # common/local-bin/ → ~/.local/bin/ (user executables: sway-run)
    if [[ -d "$REPO_DIR/common/local-bin" ]]; then
        mkdir -p "$HOME/.local/bin"
        for bin in "$REPO_DIR/common/local-bin/"*; do
            [[ -f "$bin" ]] || continue
            cp -L "$bin" "$HOME/.local/bin/$(basename "$bin")"
            chmod +x "$HOME/.local/bin/$(basename "$bin")"
        done
        ok "Common binaries disalin ke ~/.local/bin/."
    fi

    # common/wayland-sessions/ → ~/.local/share/wayland-sessions/ (session file untuk gtkgreet)
    # gtkgreet memprioritaskan user-level sessions di atas /usr/share/wayland-sessions/
    if [[ -d "$REPO_DIR/common/wayland-sessions" ]]; then
        mkdir -p "$HOME/.local/share/wayland-sessions"
        for desktop in "$REPO_DIR/common/wayland-sessions/"*.desktop; do
            [[ -f "$desktop" ]] || continue
            # Substitusi %h dengan $HOME literal (desktop entry spec tidak expand %h)
            sed "s|%h|$HOME|g" "$desktop" > "$HOME/.local/share/wayland-sessions/$(basename "$desktop")"
        done
        ok "Wayland session files disalin (Sway user env akan muncul di gtkgreet)."
    fi

    # Swaylock config (Inazuma theme, blurred lock screen)
    if [[ -f "$THEME_DIR/config/swaylock/config" ]]; then
        mkdir -p "$HOME/.config/swaylock"
        cp "$THEME_DIR/config/swaylock/config" "$HOME/.config/swaylock/config"
        ok "Konfigurasi swaylock disalin."
    fi

    # Waybar configs (wajib)
    if [[ -d "$THEME_DIR/config/waybar" ]]; then
        cp -r "$THEME_DIR/config/waybar/"* "$HOME/.config/waybar/" 2>/dev/null || true
        for script in "$HOME/.config/waybar/"*.sh; do
            [[ -f "$script" ]] && chmod +x "$script"
        done
        ok "Konfigurasi waybar disalin."
    fi

    # Mako config
    if [[ -f "$THEME_DIR/config/mako/config" ]]; then
        cp "$THEME_DIR/config/mako/config" "$HOME/.config/mako/config"
        ok "Konfigurasi mako disalin."
    fi

    # Kitty configs
    if [[ -d "$THEME_DIR/config/kitty" ]]; then
        cp -r "$THEME_DIR/config/kitty/"* "$HOME/.config/kitty/" 2>/dev/null || true
        ok "Konfigurasi kitty disalin."
    fi

    # Opsional: salin jika ada di tema
    local optional_configs=(anyrun fastfetch wallust wofi rofi)
    for d in "${optional_configs[@]}"; do
        if [[ -d "$THEME_DIR/config/$d" ]] && [[ -n "$(ls -A "$THEME_DIR/config/$d" 2>/dev/null)" ]]; then
            mkdir -p "$HOME/.config/$d"
            cp -r "$THEME_DIR/config/$d/"* "$HOME/.config/$d/" 2>/dev/null || true
            ok "Konfigurasi $d disalin."
        fi
    done

    # Fish shell config
    if [[ -f "$THEME_DIR/config/fish/config.fish" ]]; then
        if [[ -f "$HOME/.config/fish/config.fish" ]]; then
            if ! grep -q "exec sway" "$HOME/.config/fish/config.fish" 2>/dev/null; then
                cat "$THEME_DIR/config/fish/config.fish" >> "$HOME/.config/fish/config.fish"
            fi
        else
            mkdir -p "$HOME/.config/fish"
            cp "$THEME_DIR/config/fish/config.fish" "$HOME/.config/fish/config.fish"
        fi
        ok "Konfigurasi fish disalin."
    fi

    # === XDG Desktop Portal config (wlr diutamakan, gtk fallback) ===
    mkdir -p "$HOME/.config/xdg-desktop-portal"
    # Nama file harus portals.conf (default fallback) karena xdg-desktop-portal
    # mencari: 1) ${XDG_CURRENT_DESKTOP}-portals.conf  2) portals.conf
    # Saat boot, XDG_CURRENT_DESKTOP belum tentu ter-set, jadi portals.conf
    # adalah nama yang paling reliable.
    cat > "$HOME/.config/xdg-desktop-portal/portals.conf" << 'PORTAL_EOF'
[preferred]
default=wlr;gtk
org.freedesktop.impl.portal.Screenshot=wlr
org.freedesktop.impl.portal.ScreenCast=wlr
org.freedesktop.impl.portal.FileChooser=gtk
PORTAL_EOF
    # Hapus file lama (naming lama yang salah)
    rm -f "$HOME/.config/xdg-desktop-portal/sway-portals.conf" 2>/dev/null || true
    ok "portals.conf ditulis (wlr > gtk)."

    # === Environment variables untuk portal & apps Wayland ===
    # JANGAN set XDG_SESSION_TYPE di sini — itu di-set oleh login manager
    # (greetd→PAM→systemd-logind) dan bervariasi per session: wayland untuk sway,
    # tty untuk SSH/console. Men-set-nya di environment.d akan menimpa nilai yang
    # benar untuk session non-graphical.
    mkdir -p "$HOME/.config/environment.d"
    cat > "$HOME/.config/environment.d/sway.conf" << 'ENV_EOF'
XDG_CURRENT_DESKTOP=sway
XDG_SESSION_DESKTOP=sway
MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORM=wayland
QT_WAYLAND_DISABLE_WINDOWDECORATION=1
SDL_VIDEODRIVER=wayland
CLUTTER_BACKEND=wayland
_JAVA_AWT_WM_NONREPARENTING=1
ENV_EOF
    ok "environment.d/sway.conf ditulis."

    # === FIX: xdg-desktop-portal-gtk gagal start berulang ("cannot open display") ===
    # xdg-desktop-portal-gtk adalah implementasi GTK/X11. Di sesi Wayland murni,
    # dbus activation men-start service ini SEBELUM WAYLAND_DISPLAY ter-import ke
    # systemd --user environment, sehingga ia exit dengan "cannot open display: "
    # lalu di-retry untuk SETIAP portal interface (FileChooser, Settings,
    # Notification, Print, dst) — memenuhi journal dengan kegagalan dan ikut
    # memperlambat stop sequence saat reboot/shutdown.
    # Solusi: drop-in override agar service hanya start bila WAYLAND_DISPLAY ada.
    mkdir -p "$HOME/.config/systemd/user/xdg-desktop-portal-gtk.service.d"
    cat > "$HOME/.config/systemd/user/xdg-desktop-portal-gtk.service.d/wayland.conf" << 'GTK_EOF'
[Unit]
# Jangan start service ini sama sekali bila belum ada sesi Wayland aktif.
# Environment ini di-import dari sway config (import-environment) tepat
# setelah WAYLAND_DISPLAY tersedia, jadi portal tetap start on-demand
# untuk FileChooser/dll — hanya saja tidak lagi race dengan DISPLAY kosong.
ConditionEnvironment=WAYLAND_DISPLAY

[Service]
# Bila sesi grafis mati (logout/shutdown), hentikan dengan cepat dan JANGAN
# restart-loop. RestartSec memperlambat retry; StartLimitBurst + interval
# panjang menghentikan loop restart saat display hilang di tengah shutdown
# (penyebab "A stop job is running" yang menggantung poweroff/reboot).
Restart=on-failure
RestartSec=3s
StartLimitIntervalSec=30s
StartLimitBurst=2
TimeoutStopSec=5s
GTK_EOF
    ok "Drop-in xdg-desktop-portal-gtk (ConditionEnvironment=WAYLAND_DISPLAY) ditulis."

    # Drop-in serupa untuk xdg-desktop-portal & -wlr: saat Wayland display mati
    # di tengah shutdown, backend portal exit non-zero lalu Restart=on-failure
    # mencoba start lagi tanpa display — loop ini menahan stop job. Batasi retry.
    for portal_svc in xdg-desktop-portal xdg-desktop-portal-wlr; do
        mkdir -p "$HOME/.config/systemd/user/$portal_svc.service.d"
        cat > "$HOME/.config/systemd/user/$portal_svc.service.d/stop-fast.conf" << 'PORTAL_STOP_EOF'
[Service]
# Cegah restart-loop saat display mati di tengah shutdown — lihat
# xdg-desktop-portal-gtk.service.d/wayland.conf untuk penjelasan lengkap.
Restart=on-failure
RestartSec=3s
StartLimitIntervalSec=30s
StartLimitBurst=2
TimeoutStopSec=5s
PORTAL_STOP_EOF
    done
    ok "Drop-in portal (anti restart-loop saat shutdown) ditulis."

    # === Pastikan tidak ada portal backend yang ter-mask manual oleh user ===
    # (mis. xdg-desktop-portal-gtk di-mask sebelumnya — ini akan mematikan
    # FileChooser/Notification/dll karena sway-portals.conf di atas fallback ke gtk)
    # Unmask portal services yang mungkin ter-mask sebelumnya
    for svc in xdg-desktop-portal-gtk xdg-desktop-portal xdg-desktop-portal-wlr; do
        local mask_path="$HOME/.config/systemd/user/$svc.service"
        if [[ -L "$mask_path" ]] && \
           [[ "$(readlink "$mask_path")" == "/dev/null" ]]; then
            rm -f "$mask_path"
            warn "$svc.service sebelumnya ter-mask — sudah di-unmask."
        fi
    done
    systemctl_user daemon-reload 2>/dev/null || true

    # === Tambah DefaultTimeoutStopSec untuk mencegah shutdown hang ===
    # Default systemd user service timeout 90 detik — terlalu lama.
    # Jika ada service yang tidak berhenti (portal, waybar, dll), sistem
    # nge-hang saat reboot/shutdown. Set 10 detik agar force-kill lebih cepat.
    mkdir -p "$HOME/.config/systemd/user.conf.d"
    cat > "$HOME/.config/systemd/user.conf.d/timeout.conf" << 'TIMEOUT_EOF'
[Manager]
DefaultTimeoutStopSec=10s
TIMEOUT_EOF
    systemctl_user daemon-reexec 2>/dev/null || true
    ok "Systemd user timeout diset ke 10 detik (cegah shutdown hang)."

    # === Discord: paksa native Wayland (Ozone) agar screen sharing via portal berfungsi ===
    # Discord Electron default jalan lewat XWayland, di mana PipeWire/portal ScreenCast
    # tidak bekerja dengan baik. --ozone-platform-hint=auto membuat Electron pakai native
    # Wayland saat tersedia (WAYLAND_DISPLAY set), tanpa mengubah paket sistem.
    if [[ -f /usr/share/applications/discord.desktop ]]; then
        mkdir -p "$HOME/.local/share/applications"
        sed -E 's#^Exec=(.*/Discord)( .*)?$#Exec=\1 --enable-features=WaylandWindowDecorations --ozone-platform-hint=auto\2#' \
            /usr/share/applications/discord.desktop > "$HOME/.local/share/applications/discord.desktop"
        ok "Discord desktop entry di-override untuk native Wayland (screen sharing)."
    fi

    ok "Konfigurasi tingkat pengguna berhasil disalin ke ~/.config/"

    # === GREETD CONFIGS ===
    sudo mkdir -p /etc/greetd/wallpaper
    sudo cp "$THEME_DIR/config/greetd/config.toml"  /etc/greetd/config.toml
    sudo cp "$THEME_DIR/config/greetd/sway-config"  /etc/greetd/sway-config
    sudo cp "$THEME_DIR/config/greetd/gtkgreet.css" /etc/greetd/gtkgreet.css
    ok "Konfigurasi greetd berhasil disalin ke /etc/greetd/"

    setup_greetd_user

    mkdir -p "$HOME/wallpaper"

    # Wallpaper login screen STATIS per tema (swaybg membaca file ini).
    # Sumber: desktop-wallpaper tema aktif — sekaligus sebagai cadangan bila
    # tema tidak punya video khusus.
    sudo cp "$THEME_DIR/wallpaper/desktop-wallpaper.png" /etc/greetd/wallpaper/login-wallpaper.png 2>/dev/null \
        && sudo chmod 644 /etc/greetd/wallpaper/login-wallpaper.png \
        && ok "Wallpaper login (statis) disalin dari tema $THEME." \
        || warn "wallpaper/desktop-wallpaper.png tidak ditemukan di repo."

    # Video untuk tema yang masih menggunakannya (opsional, mis. raiden)
    if [[ -f "$THEME_DIR/wallpaper/baal_1080p.mp4" ]]; then
        sudo cp "$THEME_DIR/wallpaper/baal_1080p.mp4" /etc/greetd/wallpaper/baal_1080p.mp4 2>/dev/null \
            && sudo chmod 644 /etc/greetd/wallpaper/baal_1080p.mp4 \
            && ok "Wallpaper video greeter disalin." \
            || warn "Gagal menyalin video greeter."
    fi

    # Wallpaper untuk fastfetch (nama file netral, sama di semua tema)
    cp "$THEME_DIR/wallpaper/fastfetch.png" "$HOME/wallpaper/fastfetch.png" 2>/dev/null \
        && ok "Wallpaper fastfetch disalin." \
        || warn "wallpaper/fastfetch.png tidak ditemukan di repo."

    # Desktop wallpaper (nama netral agar theme-switcher bisa menimpanya)
    cp "$THEME_DIR/wallpaper/desktop-wallpaper.png" "$HOME/wallpaper/desktop-wallpaper.png" 2>/dev/null \
        && ok "Wallpaper desktop disalin." \
        || warn "wallpaper/desktop-wallpaper.png tidak ditemukan di repo."

    # === INSTALL THEMES ke ~/.config/sway-rice/ ===
    # Repo boleh dihapus setelah ini — semua script runtime membaca dari sini.
    local SWAY_RICE_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/sway-rice"
    info "Menginstal semua tema ke $SWAY_RICE_HOME/themes/ ..."
    mkdir -p "$SWAY_RICE_HOME/themes"
    for theme_src in "$REPO_DIR/themes"/*/; do
        local tname
        tname=$(basename "$theme_src")
        # Hanya folder tema (yang punya config/), skip fastfetch/matugen/dsb.
        [[ -d "$theme_src/config" ]] || continue
        rm -rf "${SWAY_RICE_HOME:?}/themes/$tname"
        cp -r "$theme_src" "$SWAY_RICE_HOME/themes/$tname"
    done
    ok "Semua tema terinstal ke $SWAY_RICE_HOME/themes/"

    # === STATE FILES ===
    echo "$THEME" > "$SWAY_RICE_HOME/state"
    # Bersihkan state file lama (deprecated)
    rm -f "$HOME/.config/sway-rice-repo" "$HOME/.config/sway-rice-theme"
    ok "State file dibuat: $SWAY_RICE_HOME/state"
}

enable_services() {
    info "=== Mengaktifkan service ==="

    # Aktifkan penyimpanan journald PERSISTEN (bertahan lintas reboot).
    # Tanpa ini, /var/log/journal tidak ada — semua log (termasuk penyebab
    # reboot/shutdown yang hang) hilang begitu sistem mati, sehingga tidak
    # bisa didiagnosis setelahnya. Wajib untuk troubleshooting hang saat shutdown.
    if [[ ! -d /var/log/journal ]]; then
        info "Mengaktifkan systemd-journald persistent storage..."
        sudo mkdir -p /var/log/journal
        sudo systemd-tmpfiles --create --prefix /var/log/journal >>"$LOG_FILE" 2>&1 || true
        sudo systemctl restart systemd-journald >>"$LOG_FILE" 2>&1 || true
        ok "Journal persisten diaktifkan (/var/log/journal). Log akan bertahan lintas reboot."
    else
        ok "Journal persisten sudah aktif."
    fi

    if command -v systemctl >/dev/null; then
        if systemctl list-unit-files 2>/dev/null | grep -q '^greetd.service'; then
            sudo systemctl enable greetd >>"$LOG_FILE" 2>&1
            ok "greetd.service diaktifkan."
        else
            # Buat unit file jika tidak ada
            warn "greetd.service tidak terdaftar. Membuat unit file..."
            sudo tee /etc/systemd/system/greetd.service > /dev/null << 'UNIT'
[Unit]
Description=Greeter daemon
Documentation=https://git.sr.ht/~kennylevinsen/greetd
After=systemd-user-sessions.service
After=seatd.service
Conflicts=getty@tty1.service

[Service]
Type=simple
ExecStart=/usr/local/bin/greetd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
            sudo systemctl daemon-reload
            sudo systemctl enable greetd >>"$LOG_FILE" 2>&1
            ok "greetd.service dibuat dan diaktifkan."
        fi
    elif command -v rc-update >/dev/null; then
        sudo rc-update add greetd default >>"$LOG_FILE" 2>&1 || warn "Gagal mengaktifkan greetd di OpenRC."
        ok "greetd diaktifkan via OpenRC."
    fi
}

print_summary() {
    echo
    info "=========================================="
    info " RINGKASAN INSTALASI"
    info "=========================================="

    local failed=0

    # Cek semua komponen inti
    local core_components=(sway greetd gtkgreet waybar kitty mako grim slurp mpvpaper)
    for comp in "${core_components[@]}"; do
        if already_installed "$comp"; then
            ok "$comp ✓"
        else
            err "$comp ✗ — GAGAL, cek $LOG_FILE"
            failed=$((failed + 1))
        fi
    done

    # Cek launcher
    if already_installed anyrun || already_installed rofi || already_installed wofi; then
        ok "launcher ✓"
    else
        err "launcher ✗ — semua opsi gagal"
        ((failed++))
    fi

    echo
    info "=== Yang perlu dicek manual ==="

    # Cek runtime deps
    if ! command -v notify-send >/dev/null 2>&1; then
        warn "notify-send tidak ada — install libnotify (untuk notifikasi)"
    fi
    if ! command -v wpctl >/dev/null 2>&1; then
        warn "wpctl tidak ada — install wireplumber (untuk kontrol volume)"
    fi
    if ! command -v tuned-adm >/dev/null 2>&1; then
        warn "tuned-adm tidak ada — install tuned (untuk Mod+P/O/I power profile)"
    fi
    if ! command -v nmtui >/dev/null 2>&1; then
        warn "nmtui tidak ada — install NetworkManager-tui (untuk Waybar network click)"
    fi
    if _has_bin convert || _has_bin magick; then
        ok "ImageMagick ✓"
    else
        warn "ImageMagick tidak ada — lock screen blur (Super+L) & preview tema nonaktif"
    fi
    if _has_bin python3 || _has_bin python; then
        ok "python3 ✓"
    else
        err "python3 tidak ada — auto-split tiling & theme switcher TIDAK berfungsi"
    fi
    if ! _has_bin cliphist; then
        warn "cliphist tidak ada — riwayat clipboard (Super+Shift+V) nonaktif"
    fi
    if ! _has_bin xdg-desktop-portal-wlr; then
        warn "xdg-desktop-portal-wlr tidak ada — diperlukan untuk screen sharing di Discord/browser"
    else
        ok "xdg-desktop-portal-wlr ✓"
    fi
    if ! _has_bin cava; then
        warn "cava tidak ada — audio visualizer di waybar tidak akan aktif"
    else
        ok "cava ✓"
    fi
    if ! _has_bin fish; then
        warn "fish shell tidak ada — menggunakan bash sebagai gantinya"
    else
        ok "fish shell ✓"
    fi

    # Cek fonts — semua sudah di-bundle di repo
    if fc-list | grep -qi "JetBrainsMono" 2>/dev/null; then
        ok "JetBrainsMono Nerd Font ✓"
    else
        warn "JetBrainsMono Nerd Font belum terdeteksi — jalankan fc-cache -f ~/.local/share/fonts/"
    fi

    # Cek greetd service
    if command -v systemctl >/dev/null; then
        if systemctl is-enabled greetd 2>/dev/null | grep -q enabled; then
            ok "greetd.service enabled ✓"
        else
            warn "greetd.service belum enabled — jalankan: sudo systemctl enable greetd"
        fi
    fi

    echo
    if [[ $failed -gt 0 ]]; then
        err "$failed komponen gagal terpasang. Cek log: $LOG_FILE"
    else
        ok "Semua komponen inti terpasang!"
    fi
    echo
    info "Langkah selanjutnya:"
    info "  1. Reboot: sudo systemctl restart greetd (atau reboot)"
    info "  2. Login via gtkgreet → masuk ke Sway"
    info "  3. Waybar, wallpaper, dan tema akan aktif otomatis"
    info "  4. Untuk screen sharing di Discord/browser:"
    info "     - Pastikan xdg-desktop-portal-wlr sudah terinstall"
    info "     - Restart xdg-desktop-portal: systemctl --user restart xdg-desktop-portal"
    info "  5. Untuk menggunakan fish shell: chsh -s \$(which fish)"
    echo
}

main() {
    # Cache sudo credential SEKALI di awal + keep-alive background, sehingga
    # user tidak diminta password berulang kali selama instalasi paket/build.
    # Keep-alive loop refresh timestamp sudo tiap 50 detik (default timeout 5m).
    sudo -v || { err "Script memerlukan sudo untuk install paket & konfigurasi sistem."; exit 1; }
    ( while true; do sudo -v 2>/dev/null; sleep 50; done ) &
    _SUDO_KEEPALIVE_PID=$!

    info "===== SWAY GENSHIN/INAZUMA RICE — UNIVERSAL INSTALLER ====="
    detect_os
    prepare_repos
    install_system_utils
    install_repo_only_deps
    install_core_stack
    install_fonts
    deploy_configs
    enable_services

    # Post-install config (systemd user services, environment.d, sway-run, portal, GTK)
    # Dijalankan otomatis agar setup lengkap dalam satu langkah. Tidak butuh sudo
    # tambahan — semua operasi di level user.
    if [[ -f "$REPO_DIR/post-install-config.sh" ]]; then
        info "Menjalankan post-install-config.sh..."
        bash "$REPO_DIR/post-install-config.sh" || warn "Post-install config gagal — jalankan manual: bash $REPO_DIR/post-install-config.sh"
    fi

    print_summary
    warn "Log lengkap tersimpan di: $LOG_FILE"
}

main "$@"
