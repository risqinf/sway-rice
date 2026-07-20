# Troubleshooting Guide - Sway Rice

## Screen Sharing di Discord/Browser Tidak Berfungsi

### Masalah
Discord atau browser (Chrome, Firefox, Edge) tidak bisa screen sharing atau menampilkan error saat mencoba share screen.

### Penyebab
Ada 2 penyebab paling umum, keduanya sudah otomatis ditangani oleh `install.sh`/`install-xdg-wlr.sh` versi terbaru:

1. **`wlr.portal` tersimpan di lokasi yang tidak dibaca daemon.** `xdg-desktop-portal`
   (paket distro, biasanya `--prefix=/usr`) HANYA mencari file registrasi backend
   (`*.portal`) di `<datadir-compile-time>/xdg-desktop-portal/portals` (mis.
   `/usr/share/...`) dan **tidak mengikuti `XDG_DATA_DIRS`** untuk pencarian ini —
   beda dengan D-Bus service activation yang memang scan `/usr/local` juga. Kalau
   `xdg-desktop-portal-wlr` di-build manual dengan `--prefix=/usr/local` (umum di
   Rocky/RHEL karena tidak ada di repo resmi), `wlr.portal` akan nyasar ke
   `/usr/local/share/xdg-desktop-portal/portals/` — dan **tidak pernah** dibaca
   daemon, sehingga `ScreenCast`/`Screenshot` tidak pernah ter-resolve ke `wlr`
   walau service-nya aktif dan binary-nya ada. Cek dengan:
   ```bash
   gdbus introspect --session --dest org.freedesktop.portal.Desktop \
       --object-path /org/freedesktop/portal/desktop 2>&1 | grep -i screencast
   ```
   Kalau kosong, salin manual:
   ```bash
   sudo mkdir -p /usr/share/xdg-desktop-portal/portals
   sudo cp /usr/local/share/xdg-desktop-portal/portals/wlr.portal /usr/share/xdg-desktop-portal/portals/
   systemctl --user restart xdg-desktop-portal
   ```

2. **xdg-desktop-portal-wlr belum terinstall/dikonfigurasi.**

### Solusi

#### 1. Pastikan xdg-desktop-portal-wlr terinstall
```bash
# Check apakah sudah terinstall
which xdg-desktop-portal-wlr

# Jika belum, install manual via package manager
# Arch/Manjaro:
sudo pacman -S xdg-desktop-portal-wlr

# Debian/Ubuntu:
sudo apt install xdg-desktop-portal-wlr

# Fedora/RHEL:
sudo dnf install xdg-desktop-portal-wlr

# Jika tidak tersedia di repo, build dari source (sudah ada di install.sh)
```

#### 2. Jalankan post-install configuration
```bash
cd /home/sway
./post-install-config.sh
```

#### 3. Restart xdg-desktop-portal service
```bash
systemctl --user restart xdg-desktop-portal
systemctl --user restart xdg-desktop-portal-wlr
```

#### 4. Check environment variables di Sway
Pastikan file `~/.config/sway/config` memiliki baris berikut:
```bash
exec systemctl --user import-environment DISPLAY WAYLAND_DISPLAY SWAYSOCK
exec hash dbus-update-activation-environment 2>/dev/null && \
     dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY SWAYSOCK
```

**Jangan** exec binary portal secara manual (`xdg-desktop-portal &`, `pkill -f xdg-desktop-portal`, dst) di config sway. Proses yang di-spawn lepas dari systemd seperti itu bisa race dengan D-Bus activation, gagal ke-terminate bersih saat logout/shutdown (berkontribusi ke hang saat reboot/shutdown), dan berebut kepemilikan nama bus dengan instance yang diaktifkan otomatis oleh systemd/D-Bus. Biarkan systemd user units (`xdg-desktop-portal.service`, `xdg-desktop-portal-wlr.service`) yang start on-demand.

#### 5. Check config file portal
Pastikan file `~/.config/xdg-desktop-portal/sway-portals.conf` ada dan berisi:
```ini
[preferred]
default=wlr;gtk
org.freedesktop.impl.portal.Screenshot=wlr
org.freedesktop.impl.portal.ScreenCast=wlr
org.freedesktop.impl.portal.FileChooser=gtk
```

#### 5b. Pastikan backend gtk TIDAK ter-mask
Karena `FileChooser` di-fallback ke `gtk`, service `xdg-desktop-portal-gtk.service`
harus AKTIF (tidak di-mask). Cek:
```bash
systemctl --user status xdg-desktop-portal-gtk
# Kalau "Loaded: masked" —> unmask:
rm -f ~/.config/systemd/user/xdg-desktop-portal-gtk.service
systemctl --user daemon-reload
```

#### 6. Discord khusus - Paksa native Wayland
Discord Electron secara default jalan lewat XWayland, di mana screen sharing via
PipeWire/portal tidak selalu bekerja. Electron modern (37+, yang dipakai Discord
saat ini) sudah support `--ozone-platform-hint=auto` untuk native Wayland.
`install.sh` otomatis membuat override di `~/.local/share/applications/discord.desktop`
dengan flag ini (tanpa mengubah paket sistem). Untuk cek/perbaiki manual:
```bash
mkdir -p ~/.local/share/applications
sed -E 's#^Exec=(.*/Discord)( .*)?$#Exec=\1 --enable-features=WaylandWindowDecorations --ozone-platform-hint=auto\2#' \
    /usr/share/applications/discord.desktop > ~/.local/share/applications/discord.desktop
```
Alternatif lain:
- Gunakan Discord web (https://discord.com/app) di browser
- Atau install Discord Wayland build (mis. `discord-canary` dari AUR di Arch)

### Test Screen Sharing
1. Buka browser (Chrome/Chromium dengan flag Wayland)
2. Pergi ke https://mozilla.github.io/webrtc-landing/gum_test.html
3. Klik "Share your screen"
4. Harus muncul picker untuk pilih window/monitor

### Logs untuk Debug
```bash
# Check xdg-desktop-portal logs (perlu persistent journald, lihat bagian di bawah)
journalctl --user -u xdg-desktop-portal -f

# Check xdg-desktop-portal-wlr logs
journalctl --user -u xdg-desktop-portal-wlr -f

# Cek interface yang benar-benar teregistrasi ke D-Bus
gdbus introspect --session --dest org.freedesktop.portal.Desktop \
    --object-path /org/freedesktop/portal/desktop 2>&1 | grep -oE "interface org\.freedesktop\.portal\.[A-Za-z]+"

# Test manual (jalankan portal-wlr langsung, lihat error real-time)
XDG_CURRENT_DESKTOP=sway /usr/local/libexec/xdg-desktop-portal-wlr -l DEBUG
```

---

## SELinux: `greetd` AVC denial di log (Rocky/RHEL/Fedora)

### Gejala
```
setroubleshoot: SELinux is preventing /usr/local/bin/greetd from using
the transition access on a process.
```

### Penjelasan
greetd yang di-build dari source ke `/usr/local/bin/greetd` mendapat SELinux
context `bin_t` — policy bawaan distro mengasumsikan greetd diinstall via RPM
di `/usr/bin/greetd` dengan context `greetd_exec_t`. Akibatnya domain
transition saat greetd spawn session user ditolak.

### Status
**Tidak berbahaya bila `getenforce` = `Permissive`** (hanya log, tidak blokir).
Login tetap berfungsi normal.

### Solusi permanen (opsional, butuh sudo sekali saja)
```bash
sudo semanage fcontext -a -t greetd_exec_t /usr/local/bin/greetd
sudo restorecon -v /usr/local/bin/greetd
```
Bila `greetd_exec_t` tidak dikenali (policy tidak ada), install hanya
policy-nya: `sudo dnf install -y greetd` lalu ulangi perintah di atas
(binary RPM bisa dihapus setelahnya, policy tetap terpasang).

---

## `XDG_CURRENT_DESKTOP` kosong / "not set"

### Penjelasan
Environment variable ini di-set oleh beberapa lapis:
1. **greetd `config.toml`** — inline `env XDG_CURRENT_DESKTOP=sway ...` untuk greeter session
2. **`~/.local/bin/sway-run`** — wrapper session user yang di-deploy post-install,
   dipanggil via `~/.local/share/wayland-sessions/sway-user.desktop`
3. **`~/.config/environment.d/sway.conf`** — dibaca systemd --user
4. **sway `config` `exec { export ... }`** — diekspor lagi saat sway start,
   lalu di-import ke systemd user manager via `systemctl --user import-environment`

Bila salah satu lapis dilewati (mis. login via SSH/TTY, atau service systemd
system-level), variabel ini memang tidak akan ada — **itu normal**. Yang penting
adalah lapis 1–4 berfungsi untuk sesi sway.

### Verifikasi (dari dalam sesi sway)
```bash
echo $XDG_CURRENT_DESKTOP                       # harus: sway
systemctl --user show-environment | grep XDG    # vars harus ter-import
```

---

## Reboot/Shutdown Stuck di CLI (Perlu Matikan Paksa via Tombol Power)

### Masalah
Setelah `sudo reboot` atau `sudo poweroff`, layar kembali ke CLI/TTY dan macet di situ — tidak benar-benar restart/mati, harus tekan tombol power untuk paksa mati.

### Penyebab Paling Umum

1. **Proses portal yang di-spawn manual di config sway lepas dari systemd.**
   `exec bash -c '... &'` membuat proses background yang tidak jadi child langsung
   dari session/user manager systemd — systemd bisa "kehilangan jejak" proses ini
   saat logout, sehingga stop job menunggu sampai timeout (`TimeoutStopUSec`,
   default 1-2 menit) sebelum shutdown lanjut. Sudah diperbaiki di config terbaru
   (lihat bagian screen sharing di atas) — portal sekarang dibiarkan dikelola
   sepenuhnya oleh systemd user units.

2. **Bug parsing sway: `exec_always pkill mako; mako`.** Di sway, `;` pada satu
   baris memisahkan antar-COMMAND SWAY (seperti `workspace 1; exec foo`), BUKAN
   command shell. Baris ini sebenarnya terbaca sebagai `exec_always pkill mako`
   lalu command sway tidak valid bernama `mako` (diam-diam gagal, tidak selalu
   berdampak ke hang tapi merupakan bug nyata — mako tidak pernah ter-restart
   setelah reload config). Sudah diperbaiki jadi
   `exec_always bash -c 'pkill mako 2>/dev/null; exec mako'`.

3. **Tidak ada log persisten untuk diagnosis.** Tanpa `/var/log/journal`
   (persistent journald storage), semua log hilang begitu mati — sehingga
   penyebab hang sebelumnya tidak pernah bisa dilihat lagi. `install.sh` versi
   terbaru otomatis mengaktifkan ini.

4. **`graphical-session.target` tidak pernah aktif → waybar/mako/swww jadi orphan.**
   Unit session helper dulu memakai `ConditionEnvironment=WAYLAND_DISPLAY` yang
   dievaluasi sebelum variabel itu ter-import, sehingga service di-skip PERMANEN
   dan target turun dalam detik yang sama. Akibatnya waybar/mako/swww-daemon
   (yang `PartOf=graphical-session.target`) tidak dikelola systemd — jadi proses
   orphan (PPID=1) yang tidak ikut dibunuh saat shutdown dan menahan stop job.
   Diperbaiki: condition rapuh dihapus, env sekarang di-import lebih awal oleh
   `sway-run` (sebelum sway start) dan lagi oleh blok `exec` di sway config.

5. **Sway config versi lama men-spawn waybar/mako manual.** Baris
   `exec_always bash -c 'pkill -x waybar; exec waybar'` (dan varian mako/swaybg)
   membuat proses ini jadi anak sway — bukan systemd — sehingga setiap reload
   menumpuk orphan baru. `cava.sh` juga menumpuk karena `restart-interval: 3`
   di waybar me-restart script tiap 3 detik. Diperbaiki: waybar/mako/swww murni
   systemd services; `restart-interval` cava dihapus.

6. **Portal backend restart-loop di tengah shutdown.** `xdg-desktop-portal-gtk`
   exit non-zero saat Wayland display mati, lalu `Restart=on-failure` mencoba
   start lagi tanpa display — loop ini menahan stop job ("A stop job is running").
   Diperbaiki dengan drop-in `StartLimitBurst=2` + `TimeoutStopSec=5s` di
   `~/.config/systemd/user/xdg-desktop-portal{,-wlr,-gtk}.service.d/`.

### Solusi

#### 1. Aktifkan log persisten (WAJIB untuk diagnosis ke depan)
```bash
sudo mkdir -p /var/log/journal
sudo systemd-tmpfiles --create --prefix /var/log/journal
sudo systemctl restart systemd-journald
```

#### 2. Setelah hang berikutnya terjadi, cek job yang menggantung
Begitu reboot berikutnya berhasil, cek boot sebelumnya:
```bash
journalctl -b -1 --no-pager | grep -iE "stop job is running|Timed out waiting|reached target"
```

#### 3. Update config sway ke versi terbaru dari repo ini
File `~/.config/sway/config` di sistem Anda kemungkinan masih pakai versi lama
yang exec binary portal manual — jalankan ulang `./install.sh` (atau salin ulang
`config/sway/config` dari repo) supaya dapat versi yang sudah diperbaiki.

#### 4. Cek inhibitor yang menahan shutdown
```bash
systemd-inhibit --list
```
Aplikasi seperti Discord/NetworkManager/UPower normal menahan sebentar (mode
`delay`) untuk cleanup — ini seharusnya tidak menyebabkan hang permanen, tapi
kalau salah satu stuck di situ terus, coba tutup aplikasinya dulu sebelum shutdown.

#### 5. Jika masih hang, coba shutdown dari TTY lain
```bash
# Ctrl+Alt+F2 ke TTY lain, login, lalu:
sudo systemctl reboot   # atau: sudo systemctl poweroff
# Bandingkan dengan output journalctl -f di TTY tersebut sebelum trigger reboot lain
```

---


## Screen Recorder Tidak Merekam Suara Sistem (YouTube/Discord/dll.)

### Masalah
Saat rekam layar fullscreen (Mod+Shift+R) sambil memutar video YouTube, audio
video tidak ikut terekam — hasil rekaman bisu. Hal yang sama untuk share screen
di Discord: suara desktop tidak terdengar lawan bicara.

### Penyebab
1. **Mode "Video Full Screen" lama tidak merekam audio sama sekali** — `wf-recorder`
   dipanggil tanpa flag `--audio`.
2. **Mode "Video + Mic" merekam mic, bukan suara sistem.** YouTube keluar lewat
   speaker (sink), bukan mic (source) — jadi tidak terekam.
3. **Deteksi sink salah.** Script lama mengambil angka ID mentah dari
   `wpctl status` (mis. `51`) — bukan nama node PipeWire yang valid. Untuk merekam
   suara sistem, wf-recorder butuh **monitor source** dari sink aktif
   (`<nama_sink>.monitor`), yaitu mirror dari apa yang Anda dengar di speaker.

### Solusi (sudah diterapkan di `gui-recorder.sh` terbaru)
Script sekarang memakai monitor source yang benar, diambil via:
```bash
SINK=$(wpctl inspect @DEFAULT_AUDIO_SINK@ | grep -oP 'node\.name = "\K[^"]+')
MONITOR="${SINK}.monitor"   # contoh: alsa_output.pci-...__sink.monitor
wf-recorder -c libx264 --audio="$MONITOR" -f out.mp4
```
Menu recorder baru:
- **Video + System Audio** → rekam layar + suara speaker (YouTube, game, Discord).
- **Video + System + Mic** → keduanya, via virtual mix source `pw-loopback`.
- **Video Only** → tanpa audio.

> Catatan: jangan pakai `--audio-backend=pipewire` pada wf-recorder build
> tertentu — ada build yang tidak menulis audio stream dengan backend itu.
> Backend default (pulse / pipewire-pulse) lebih andal.

### Discord Screenshare (audio desktop)
Audio desktop untuk Discord dikelola PipeWire lewat xdg-desktop-portal-wlr.
Pastikan Discord jalan native Wayland (lihat bagian Screen Sharing di atas) dan
portal aktif:
```bash
systemctl --user status xdg-desktop-portal xdg-desktop-portal-wlr
```

---

## Pipewire Audio Tidak Berfungsi

### Masalah
Tidak ada sound, atau volume control di Waybar tidak berfungsi.

### Solusi

#### 1. Install Pipewire & Wireplumber
```bash
# Arch/Manjaro:
sudo pacman -S pipewire pipewire-pulse wireplumber

# Debian/Ubuntu:
sudo apt install pipewire pipewire-pulse wireplumber

# Fedora/RHEL:
sudo dnf install pipewire pipewire-pulseaudio wireplumber
```

#### 2. Enable & Start Services
```bash
systemctl --user enable --now pipewire.socket
systemctl --user enable --now pipewire-pulse.socket
systemctl --user enable --now wireplumber.service
```

#### 3. Restart Sway
```bash
# Mod + Shift + C (reload Sway config)
# atau logout dan login kembali
```

#### 4. Test Audio
```bash
# Check devices
wpctl status

# Test sound
paplay /usr/share/sounds/alsa/Front_Center.wav

# Adjust volume
wpctl set-volume @DEFAULT_AUDIO_SINK@ 50%
```

---

## Waybar Tidak Muncul atau Error

### Masalah
Waybar tidak muncul, atau crash saat startup.

### Solusi

#### 1. Check Waybar Version & Dependencies
```bash
waybar --version

# Install dependencies yang mungkin kurang
sudo pacman -S gtkmm3 jsoncpp libsigc++ fmt spdlog libnl libpulse wireplumber playerctl
```

#### 2. Check Config Syntax
```bash
# Test config manually
waybar -c ~/.config/waybar/config -s ~/.config/waybar/style.css

# Check logs
journalctl --user -u waybar -f
```

#### 3. Restart Waybar
```bash
# Kill waybar
killall waybar

# Sway akan auto-restart karena ada `exec waybar` di config
# Atau manual:
waybar &
```

---

## Brightness Control Tidak Berfungsi

### Masalah
Fn keys untuk brightness tidak bekerja, atau brightness-menu.sh error.

### Solusi

#### 1. Install brightnessctl
```bash
# Arch/Manjaro:
sudo pacman -S brightnessctl

# Debian/Ubuntu:
sudo apt install brightnessctl

# Fedora/RHEL:
sudo dnf install brightnessctl
```

#### 2. Add User ke Group Video
```bash
sudo usermod -aG video $USER

# Logout dan login kembali
```

#### 3. Test Manual
```bash
# List devices
brightnessctl -l

# Set brightness
brightnessctl set 50%
brightnessctl set +10%
brightnessctl set 10%-
```

#### 4. Check Sway Keybinds
Pastikan `~/.config/sway/config` memiliki:
```bash
bindsym XF86MonBrightnessUp exec ~/.config/sway/brightness.sh up
bindsym XF86MonBrightnessDown exec ~/.config/sway/brightness.sh down
```

---

## Greetd Crash / Black Screen

### Masalah
Setelah boot, black screen atau crash loop ke TTY.

### Solusi

#### 1. Check Greetd Logs
```bash
# Drop to TTY dengan Ctrl+Alt+F2
sudo journalctl -u greetd -b --no-pager | tail -50

# Check greetd config
cat /etc/greetd/config.toml

# Check sway greeter config
cat /etc/greetd/sway-config
```

#### 2. Common Issues

**Video wallpaper tidak ada:**
```bash
# Check video file
ls -lh /etc/greetd/wallpaper/baal_1080p.mp4

# Copy ulang jika hilang
sudo cp ~/Downloads/sway-rice/wallpaper/baal_1080p.mp4 /etc/greetd/wallpaper/
```

**Permission issues:**
```bash
sudo chown -R greeter:greeter /etc/greetd
sudo chmod -R 755 /etc/greetd

# Check greeter user groups
groups greeter
# harus ada: video, render
sudo usermod -aG video,render greeter
```

**Sway config error:**
```bash
# Test sway config syntax
sway -c /etc/greetd/sway-config --validate
```

#### 3. Temporary Fix - Disable Greetd
```bash
sudo systemctl stop greetd
sudo systemctl disable greetd

# Login via TTY dan debug
# Lalu enable kembali setelah fix
sudo systemctl enable --now greetd
```

---

## Font Tidak Muncul dengan Benar

### Masalah
Waybar, terminal, atau aplikasi lain tidak menampilkan icon atau font dengan benar.

### Solusi

#### 1. Rebuild Font Cache
```bash
# Check font directory
ls ~/.local/share/fonts/

# Rebuild cache
fc-cache -fv ~/.local/share/fonts/

# Verify fonts
fc-list | grep -i "JetBrains"
fc-list | grep -i "Nerd"
```

#### 2. Install Nerd Fonts
```bash
# Jika font belum ada di repo
cd /home/sway
cp fonts/*.ttf ~/.local/share/fonts/
fc-cache -f
```

---

## Network Manager Applet Tidak Muncul

### Masalah
Klik icon network di Waybar tidak membuka network manager.

### Solusi

#### 1. Install nm-applet
```bash
# Arch/Manjaro:
sudo pacman -S network-manager-applet

# Debian/Ubuntu:
sudo apt install network-manager-gnome

# Fedora/RHEL:
sudo dnf install network-manager-applet
```

#### 2. Check Waybar Config
File `~/.config/waybar/config` harus ada:
```json
"network": {
    "format-wifi": "  {essid}",
    "format-ethernet": "  {ifname}",
    "format-disconnected": "睊  Disconnected",
    "tooltip-format": "{ifname}: {ipaddr}/{cidr}",
    "on-click": "nm-applet"
}
```

#### 3. Restart Waybar
```bash
killall waybar
# Sway akan auto-restart waybar
```

---

## Tuned Power Profiles Tidak Berfungsi

### Masalah
Mod+P/O/I keybinds tidak mengubah power profile.

### Solusi

#### 1. Install Tuned
```bash
# Arch/Manjaro:
sudo pacman -S tuned

# Debian/Ubuntu:
sudo apt install tuned

# Fedora/RHEL:
sudo dnf install tuned
```

#### 2. Enable & Start Tuned
```bash
sudo systemctl enable --now tuned
```

#### 3. Test Manual
```bash
# List profiles
tuned-adm list

# Set profile
sudo tuned-adm profile balanced
sudo tuned-adm profile powersave
sudo tuned-adm profile throughput-performance

# Check active profile
tuned-adm active
```

#### 4. Add Sudo Permissions (Optional - untuk passwordless)
```bash
sudo visudo

# Tambahkan di akhir file:
%wheel ALL=(ALL) NOPASSWD: /usr/sbin/tuned-adm
```

---

## Screenshot Tidak Tersimpan

### Masalah
Print Screen tidak save screenshot atau tidak copy ke clipboard.

### Solusi

#### 1. Install Dependencies
```bash
# Arch/Manjaro:
sudo pacman -S grim slurp wl-clipboard

# Debian/Ubuntu:
sudo apt install grim slurp wl-clipboard

# Fedora/RHEL:
sudo dnf install grim slurp wl-clipboard
```

#### 2. Create Screenshot Directory
```bash
mkdir -p ~/Pictures/Screenshots
```

#### 3. Check Sway Keybinds
File `~/.config/sway/config`:
```bash
# Area screenshot
bindsym Print exec grim -g "$(slurp)" - | tee ~/Pictures/Screenshots/$(date +'%Y%m%d_%H%M%S').png | wl-copy

# Fullscreen screenshot
bindsym Shift+Print exec grim ~/Pictures/Screenshots/$(date +'%Y%m%d_%H%M%S').png
```

#### 4. Test Manual
```bash
# Area screenshot
grim -g "$(slurp)" ~/test.png

# Fullscreen
grim ~/test-full.png

# Copy to clipboard
grim -g "$(slurp)" - | wl-copy
```

---

## Launcher (Anyrun/Rofi/Wofi) Tidak Berfungsi

### Masalah
Mod+D tidak membuka launcher atau error.

### Solusi

#### 1. Check Launcher Terinstall
```bash
# Check mana yang terinstall
which anyrun
which rofi
which wofi
```

#### 2. Update Sway Config
Edit `~/.config/sway/config`:
```bash
# Pilih salah satu (sesuai yang terinstall)
set $menu anyrun
# atau
set $menu rofi -show drun
# atau
set $menu wofi --show drun
```

#### 3. Test Manual
```bash
anyrun
# atau
rofi -show drun
# atau
wofi --show drun
```

---

## General Debug Commands

```bash
# Check Sway version
sway --version

# Check running processes
ps aux | grep -E "sway|waybar|mako|kitty"

# Check Sway config syntax
sway -c ~/.config/sway/config --validate

# Sway IPC info
swaymsg -t get_outputs
swaymsg -t get_tree

# System logs
journalctl --user -b --no-pager | tail -100

# Check all installed components
for cmd in sway waybar mako kitty grim slurp anyrun rofi wofi greetd gtkgreet; do
    which $cmd && echo "$cmd: OK" || echo "$cmd: NOT FOUND"
done
```

---

## Jika Semua Gagal - Fresh Install

```bash
# Backup config lama
mv ~/.config ~/.config-old-backup

# Clean install
cd /home/sway
./install.sh --force

# Post-config
./post-install-config.sh

# Reboot
sudo reboot
```

---

## Kontak & Support

Jika masalah masih berlanjut:
1. Check log file: `/tmp/sway-rice-install.log`
2. Run dengan verbose mode: `bash -x ./install.sh 2>&1 | tee debug.log`
3. Buat issue di GitHub repository
4. Share output dari debug commands di atas
