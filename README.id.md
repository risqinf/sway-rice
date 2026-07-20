# Sway Genshin Rice

![Preview](docs/preview.png)

Dotfiles Sway (Wayland) lengkap + installer universal, bertema karakter Genshin Impact. Termasuk login screen video (greetd + mpvpaper), Waybar, Wofi/Anyrun/Rofi, Mako, Kitty, dan warna adaptif Material You via matugen.

**Tanpa binary pre-compiled** — semua dibangun dari source oleh `install.sh`, disesuaikan dengan distro dan arsitektur kamu.

## Distro yang Didukung

| Keluarga | Distro | Package Manager |
|----------|--------|-----------------|
| Arch | Arch, Manjaro, EndeavourOS, CachyOS | pacman |
| Debian | Debian, Ubuntu, Mint, Pop!_OS | apt |
| RHEL | Fedora, Rocky, AlmaLinux, CentOS | dnf |
| SUSE | openSUSE, SLES | zypper |
| Alpine | Alpine | apk + OpenRC |
| Void | Void | xbps |

## Fitur

- **5 tema karakter** — Raiden Shogun (default), Hu Tao, Furina, Xiao, Kazuha
- **Ganti tema live** — Super+T (grid), Super+Y (list), Super+Shift+T (berikutnya)
- **Engine wallpaper** — statis (swww) + video live (mpvpaper), picker Super+W
- **Warna adaptif** — matugen generate palette Material You dari wallpaper
- **Tiling dwindle ala Hyprland** — auto-split kanan→bawah→kanan
- **Wofi singleton** — satu wofi per jenis, pindah workspace ikut
- **Login screen video** — mpvpaper di greetd
- **Screen sharing** — xdg-desktop-portal-wlr auto-build
- **Sistem lengkap** — waybar, mako, kitty, fish, swaylock, grim/slurp, wf-recorder

## Instalasi Cepat

```bash
git clone https://github.com/risqinf/sway-rice.git
cd sway-rice
chmod +x install.sh
./install.sh              # 15-40 menit (build dari source)
./post-install-config.sh  # portal, pipewire, default apps
sudo reboot
```

Gunakan `./install.sh --force` untuk menimpa config tanpa backup.

### Pilih Tema

```bash
THEME=hutao ./install.sh    # Hu Tao
THEME=furina ./install.sh   # Furina
THEME=xiao ./install.sh     # Xiao
THEME=kazuha ./install.sh   # Kazuha
```

## Keybinds

### Dasar
| Tombol | Aksi |
|--------|------|
| Super+Enter | Terminal (kitty) |
| Super+D | App launcher |
| Super+E | File manager |
| Super+Shift+Q | Tutup window |
| Super+F | Fullscreen |
| Super+Shift+E | Menu power |
| Super+L | Lock screen |
| Super+Shift+C | Reload config sway |

### Window & Workspace
| Tombol | Aksi |
|--------|------|
| Super+Panah | Fokus arah |
| Super+Shift+Panah | Pindah window |
| Super+[1-0] | Pindah workspace |
| Super+Shift+[1-0] | Kirim ke workspace |
| Super+H / Super+V | Split manual horizontal/vertikal |
| Super+Shift+Space | Toggle layout split |

### Tema & Wallpaper
| Tombol | Aksi |
|--------|------|
| Super+T | Theme switcher (grid) dengan animasi transisi |
| Super+Y | Theme switcher (list) dengan animasi transisi |
| Super+Shift+T | Tema berikutnya dengan animasi acak |
| Super+W | Wallpaper picker |

### Media & Sistem
| Tombol | Aksi |
|--------|------|
| Print | Screenshot area |
| Shift+Print | Screenshot full |
| Super+Shift+R | Screen recorder |
| Super+P / O / I | Performance / Balanced / Hemat daya |
| Fn+Volume | Kontrol volume |
| Fn+Brightness | Kontrol brightness |

### Scratchpad
| Tombol | Aksi |
|--------|------|
| Super+` | Terminal dropdown |
| Super+M | Music player |
| Super+Shift+- | Kirim ke scratchpad |
| Super+- | Tampilkan scratchpad |

## Struktur Repository

```
sway-rice/
├── install.sh                  # Installer universal (build dari source)
├── post-install-config.sh      # Config pasca-install
├── test-components.sh          # Verifikasi instalasi
├── install-xdg-wlr.sh          # Builder portal-wlr standalone
├── convert_cursors.sh          # Konversi cursor Windows → Xcursor
│
├── common/
│   ├── scripts/                # Script helper → ~/.config/sway/
│   │   ├── wofi-run.sh         # Wofi singleton wrapper
│   │   ├── auto-split.sh       # Tiling dwindle
│   │   ├── wallpaper-apply.sh  # Engine wallpaper
│   │   ├── app-launcher.sh     # Wofi drun
│   │   ├── clipboard-history.sh
│   │   ├── emoji-picker.sh
│   │   ├── quick-settings.sh
│   │   ├── gui-recorder.sh
│   │   ├── lock.sh
│   │   ├── powermenu.sh
│   │   ├── brightness.sh / brightness-menu.sh
│   │   └── theme-lib.sh
│   ├── systemd-user/           # systemd user services
│   │   ├── waybar.service
│   │   ├── mako.service
│   │   ├── swww-daemon.service
│   │   └── sway-graphical-session.service
│   ├── local-bin/
│   │   └── sway-run            # Session wrapper
│   └── wayland-sessions/
│       └── sway-user.desktop
│
├── themes/
│   ├── theme-switch.sh         # Engine ganti tema
│   ├── theme-switcher.sh       # Theme picker UI (Super+T)
│   ├── theme-switch-wofi.sh    # Quick theme list (Super+Y)
│   ├── wallpaper-picker.sh     # Wallpaper picker (Super+W)
│   ├── _gen-preview.sh         # Generator preview
│   ├── matugen/                # Template warna Material You
│   ├── fastfetch/              # Aset fastfetch
│   ├── raiden/                 # Raiden Shogun (default)
│   ├── hutao/                  # Hu Tao
│   ├── furina/                 # Furina
│   ├── xiao/                   # Xiao
│   └── kazuha/                 # Kazuha
│
├── fonts/                      # JetBrainsMono Nerd Font + Rajdhani
├── docs/
│   ├── preview.png
│   └── LIVE-WALLPAPER.md
│
├── README.md                   # English
├── README.id.md                # File ini
├── QUICKSTART.md               # Panduan 3 langkah
├── TROUBLESHOOTING.md          # Troubleshooting detail
└── CHANGELOG.md                # Riwayat versi
```

## Komponen yang Dibangun dari Source

| Komponen | Source | Build |
|----------|--------|-------|
| wlroots | gitlab.freedesktop.org | meson |
| sway | github.com/swaywm/sway | meson |
| greetd + gtkgreet | github.com/kennylevinsen/greetd | cargo + meson |
| waybar | github.com/Alexays/Waybar | meson |
| kitty | sw.kovidgoyal.net | binary installer |
| mako | github.com/emersion/mako | meson |
| grim + slurp | github.com/emersion | meson |
| mpvpaper | github.com/GhostNaN/mpvpaper | meson |
| wofi | hg.sr.ht/~scoopta/wofi | meson |
| wf-recorder | github.com/ammen99/wf-recorder | meson |
| swaylock | github.com/swaywm/swaylock | meson |
| swayidle | github.com/swaywm/swayidle | meson |
| swww | github.com/LGFae/swww | cargo |
| matugen | github.com/InioX/matugen | cargo |
| xdg-desktop-portal-wlr | github.com/emersion | meson |

## Dokumentasi

- **[QUICKSTART.md](QUICKSTART.md)** — Instalasi 3 langkah
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** — Screen sharing, audio, shutdown hang, SELinux, dll
- **[CHANGELOG.md](CHANGELOG.md)** — Riwayat versi
- **[docs/LIVE-WALLPAPER.md](docs/LIVE-WALLPAPER.md)** — Panduan live wallpaper
- **[README.md](README.md)** — English documentation

## Lisensi

Bebas digunakan dan dimodifikasi. Aset Genshin Impact (wallpaper, cursor, video) milik HoYoverse — jangan didistribusikan secara komersial.
