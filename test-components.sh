#!/usr/bin/env bash
# =====================================================================
# TEST COMPONENTS - Script untuk testing komponen yang terinstall
# =====================================================================

set -uo pipefail

c_reset="\033[0m"; c_red="\033[31m"; c_green="\033[32m"; c_yellow="\033[33m"; c_blue="\033[34m"
info()  { echo -e "${c_blue}[INFO]${c_reset} $*"; }
ok()    { echo -e "${c_green}[ ✓ ]${c_reset} $*"; }
warn()  { echo -e "${c_yellow}[ ! ]${c_reset} $*"; }
err()   { echo -e "${c_red}[ ✗ ]${c_reset} $*"; }

PASSED=0
FAILED=0
WARNINGS=0

test_binary() {
    local name="$1"
    local bin="$2"
    
    if command -v "$bin" >/dev/null 2>&1; then
        ok "$name"
        ((PASSED++))
        return 0
    else
        err "$name - NOT FOUND"
        ((FAILED++))
        return 1
    fi
}

test_optional_binary() {
    local name="$1"
    local bin="$2"
    
    if command -v "$bin" >/dev/null 2>&1; then
        ok "$name (optional)"
        ((PASSED++))
        return 0
    else
        warn "$name (optional) - NOT FOUND"
        ((WARNINGS++))
        return 1
    fi
}

test_service() {
    local name="$1"
    local service="$2"
    
    if ! command -v systemctl >/dev/null 2>&1; then
        warn "$name - systemctl not available (OpenRC?)"
        ((WARNINGS++))
        return 0
    fi
    
    if systemctl --user is-enabled "$service" >/dev/null 2>&1; then
        ok "$name service enabled"
        ((PASSED++))
        return 0
    else
        warn "$name service not enabled (akan start otomatis)"
        ((WARNINGS++))
        return 1
    fi
}

test_file() {
    local name="$1"
    local file="$2"
    
    if [[ -f "$file" ]]; then
        ok "$name"
        ((PASSED++))
        return 0
    else
        err "$name - FILE NOT FOUND: $file"
        ((FAILED++))
        return 1
    fi
}

test_directory() {
    local name="$1"
    local dir="$2"
    
    if [[ -d "$dir" ]]; then
        ok "$name"
        ((PASSED++))
        return 0
    else
        err "$name - DIRECTORY NOT FOUND: $dir"
        ((FAILED++))
        return 1
    fi
}

test_font() {
    local name="$1"
    local pattern="$2"
    
    if fc-list | grep -qi "$pattern" 2>/dev/null; then
        ok "$name"
        ((PASSED++))
        return 0
    else
        warn "$name - Font not detected, run: fc-cache -f ~/.local/share/fonts/"
        ((WARNINGS++))
        return 1
    fi
}

echo
info "===== TESTING SWAY RICE COMPONENTS ====="
echo

info "=== Core Window Manager ==="
test_binary "Sway compositor" "sway"
test_binary "wlroots library" "pkg-config" && pkg-config --exists wlroots 2>/dev/null && ok "wlroots detected" || warn "wlroots check failed"
echo

info "=== Display Manager (Login) ==="
test_binary "greetd daemon" "greetd"
test_binary "gtkgreet UI" "gtkgreet"
test_file "greetd config" "/etc/greetd/config.toml"
test_file "greetd sway config" "/etc/greetd/sway-config"
test_file "greetd video wallpaper" "/etc/greetd/wallpaper/baal_1080p.mp4"
if command -v systemctl >/dev/null 2>&1; then
    if systemctl is-enabled greetd >/dev/null 2>&1; then
        ok "greetd service enabled"
        ((PASSED++))
    else
        err "greetd service NOT enabled - run: sudo systemctl enable greetd"
        ((FAILED++))
    fi
fi
echo

info "=== Status Bar & Notifications ==="
test_binary "Waybar" "waybar"
test_binary "Mako notification" "mako"
test_file "Waybar config" "$HOME/.config/waybar/config"
test_file "Waybar style" "$HOME/.config/waybar/style.css"
test_file "Mako config" "$HOME/.config/mako/config"
echo

info "=== Terminal ==="
test_binary "Kitty terminal" "kitty"
test_file "Kitty config" "$HOME/.config/kitty/kitty.conf"
test_optional_binary "Fish shell" "fish"
if [[ -f "$HOME/.config/fish/config.fish" ]]; then
    ok "Fish config file"
    ((PASSED++))
fi
echo

info "=== Application Launcher ==="
launcher_found=false
if test_binary "Anyrun launcher" "anyrun" 2>/dev/null; then launcher_found=true; fi
if test_binary "Rofi launcher" "rofi" 2>/dev/null; then launcher_found=true; fi
if test_binary "Wofi launcher" "wofi" 2>/dev/null; then launcher_found=true; fi
if ! $launcher_found; then
    err "No launcher found (anyrun/rofi/wofi)"
    ((FAILED++))
fi
echo

info "=== Screenshot & Recording ==="
test_binary "Grim screenshot" "grim"
test_binary "Slurp select" "slurp"
test_binary "wf-recorder" "wf-recorder"
test_binary "wl-clipboard" "wl-copy"
test_directory "Screenshots folder" "$HOME/Pictures/Screenshots"
echo

info "=== Wallpaper & Background ==="
test_binary "mpvpaper video wallpaper" "mpvpaper"
test_binary "mpv player" "mpv"
test_file "Desktop wallpaper" "$HOME/wallpaper/desktop-wallpaper.png"
test_file "Fastfetch wallpaper" "$HOME/wallpaper/fastfetch.png"
echo

info "=== Screen Sharing (Important for Discord/Browser) ==="
test_binary "xdg-desktop-portal" "xdg-desktop-portal"
test_binary "xdg-desktop-portal-wlr" "xdg-desktop-portal-wlr"
test_file "Portal config" "$HOME/.config/xdg-desktop-portal/portals.conf"
if command -v systemctl >/dev/null 2>&1; then
    if systemctl --user status xdg-desktop-portal >/dev/null 2>&1; then
        ok "xdg-desktop-portal service running"
        ((PASSED++))
    else
        warn "xdg-desktop-portal service not running (akan start otomatis di Sway)"
        ((WARNINGS++))
    fi
fi
echo

info "=== Audio System ==="
test_optional_binary "Pipewire" "pipewire"
test_optional_binary "Wireplumber (wpctl)" "wpctl"
test_optional_binary "PulseAudio control" "pavucontrol"
if command -v systemctl >/dev/null 2>&1; then
    test_service "Pipewire" "pipewire.socket"
    test_service "Wireplumber" "wireplumber.service"
fi
echo

info "=== Utilities ==="
test_binary "brightnessctl" "brightnessctl"
test_optional_binary "swaylock" "swaylock"
test_optional_binary "fastfetch" "fastfetch"
test_optional_binary "wallust" "wallust"
echo

info "=== System Utilities (dibutuhkan config & script) ==="
# python3 & ImageMagick esensial: tiling dwindle, theme switcher, lock blur.
if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
    ok "python3 (auto-split tiling, theme switcher)"
    ((PASSED++))
else
    err "python3 - NOT FOUND (auto-split tiling & theme switcher rusak)"
    ((FAILED++))
fi
if command -v convert >/dev/null 2>&1 || command -v magick >/dev/null 2>&1; then
    ok "ImageMagick (lock screen blur, preview tema)"
    ((PASSED++))
else
    warn "ImageMagick - NOT FOUND (lock screen blur & preview tema nonaktif)"
    ((WARNINGS++))
fi
test_optional_binary "dbus-update-activation-environment" "dbus-update-activation-environment"
test_optional_binary "gsettings (GTK dark theme)" "gsettings"
test_optional_binary "xdg-mime (default apps)" "xdg-mime"
test_optional_binary "cliphist (clipboard history)" "cliphist"
echo

info "=== Optional System Tools ==="
test_optional_binary "tuned power profiles" "tuned-adm"
test_optional_binary "Network Manager" "nmtui"
test_optional_binary "Network Manager Applet" "nm-applet"
test_optional_binary "Nautilus file manager" "nautilus"
echo

info "=== Fonts ==="
test_font "JetBrainsMono Nerd Font" "JetBrainsMono"
test_font "Rajdhani Font" "Rajdhani"
echo

info "=== Sway Configuration ==="
test_file "Sway main config" "$HOME/.config/sway/config"
test_file "Power menu script" "$HOME/.config/sway/powermenu.sh"
test_file "Brightness script" "$HOME/.config/sway/brightness.sh"
test_file "GUI recorder script" "$HOME/.config/sway/gui-recorder.sh"
if [[ -x "$HOME/.config/sway/powermenu.sh" ]]; then
    ok "Power menu is executable"
    ((PASSED++))
else
    warn "Power menu not executable - run: chmod +x ~/.config/sway/*.sh"
    ((WARNINGS++))
fi
echo

info "=== Sway Config Validation ==="
if command -v sway >/dev/null 2>&1; then
    if sway -c "$HOME/.config/sway/config" --validate 2>/dev/null; then
        ok "Sway config syntax valid"
        ((PASSED++))
    else
        err "Sway config has syntax errors"
        ((FAILED++))
        info "Run: sway -c ~/.config/sway/config --validate"
    fi
fi
echo

info "=== User Groups (for brightness & video) ==="
if groups | grep -q video; then
    ok "User in 'video' group"
    ((PASSED++))
else
    warn "User NOT in 'video' group - run: sudo usermod -aG video \$USER"
    ((WARNINGS++))
fi
if groups | grep -q render; then
    ok "User in 'render' group"
    ((PASSED++))
else
    warn "User NOT in 'render' group - run: sudo usermod -aG render \$USER"
    ((WARNINGS++))
fi
echo

info "===== TEST SUMMARY ====="
echo
ok "Passed: $PASSED"
warn "Warnings: $WARNINGS"
err "Failed: $FAILED"
echo

if [[ $FAILED -gt 0 ]]; then
    err "Some critical components are missing!"
    info "Check /tmp/sway-rice-install.log for installation errors"
    info "Or run: ./install.sh again"
    exit 1
elif [[ $WARNINGS -gt 0 ]]; then
    warn "Installation is mostly complete, but some optional components are missing"
    info "Run: ./post-install-config.sh for additional setup"
    info "Or check TROUBLESHOOTING.md for manual fixes"
    exit 0
else
    ok "All components installed successfully!"
    info "You can now reboot: sudo reboot"
    info "Or reload Sway: swaymsg reload"
    exit 0
fi
