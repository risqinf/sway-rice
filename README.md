# Sway Genshin Rice

[![Preview](https://drive.google.com/thumbnail?id=1vXAIFSZxN91Q9chNWCYA51dj5wXzVXmG&sz=w1000)](https://drive.google.com/file/d/1vXAIFSZxN91Q9chNWCYA51dj5wXzVXmG/view)

Complete Sway (Wayland) dotfiles + universal auto-installer, themed around Genshin Impact characters. Includes video login screen (greetd + mpvpaper), Waybar, Wofi/Anyrun/Rofi, Mako, Kitty, and adaptive Material You colors via matugen.

**No pre-compiled binaries** — everything is built from source by `install.sh`, tailored to your distro and architecture.

## Supported Distributions

| Family | Distros | Package Manager |
|--------|---------|-----------------|
| Arch | Arch, Manjaro, EndeavourOS, CachyOS | pacman |
| Debian | Debian, Ubuntu, Mint, Pop!_OS | apt |
| RHEL | Fedora, Rocky, AlmaLinux, CentOS | dnf |
| SUSE | openSUSE, SLES | zypper |
| Alpine | Alpine | apk + OpenRC |
| Void | Void | xbps |

## Features

- **5 character themes** — Raiden Shogun (default), Hu Tao, Furina, Xiao, Kazuha
- **Live theme switching** — Super+T (grid), Super+Y (list), Super+Shift+T (next)
- **Wallpaper engine** — static (swww) + live video (mpvpaper), Super+W picker
- **Adaptive colors** — matugen generates Material You palette from wallpaper
- **Hyprland-style dwindle tiling** — auto-split kanan→bawah→kanan
- **Wofi singleton** — satu wofi per jenis, pindah workspace ikut
- **Video login screen** — mpvpaper di greetd
- **Screen sharing** — xdg-desktop-portal-wlr auto-built
- **Full system** — waybar, mako, kitty, fish, swaylock, grim/slurp, wf-recorder

## Quick Install

```bash
git clone https://github.com/risqinf/sway-rice.git
cd sway-rice
chmod +x install.sh
./install.sh              # 15-40 min (builds from source)
./post-install-config.sh  # portal, pipewire, defaults
sudo reboot
```

Use `./install.sh --force` to overwrite existing configs without backup.

### Select Theme

```bash
THEME=hutao ./install.sh    # Hu Tao
THEME=furina ./install.sh   # Furina
THEME=xiao ./install.sh     # Xiao
THEME=kazuha ./install.sh   # Kazuha
```

## Keybinds

### Essentials
| Key | Action |
|-----|--------|
| Super+Enter | Terminal (kitty) |
| Super+D | App launcher |
| Super+E | File manager |
| Super+Shift+Q | Close window |
| Super+F | Fullscreen |
| Super+Shift+E | Power menu |
| Super+L | Lock screen |
| Super+Shift+C | Reload sway config |

### Window & Workspace
| Key | Action |
|-----|--------|
| Super+Arrow | Focus direction |
| Super+Shift+Arrow | Move window |
| Super+[1-0] | Switch workspace |
| Super+Shift+[1-0] | Move to workspace |
| Super+H / Super+V | Manual split horizontal/vertical |
| Super+Shift+Space | Toggle split layout |

### Themes & Wallpaper
| Key | Action |
|-----|--------|
| Super+T | Theme switcher (grid) with transition animation |
| Super+Y | Theme switcher (list) with transition animation |
| Super+Shift+T | Next theme with random animation |
| Super+W | Wallpaper picker |

### Media & System
| Key | Action |
|-----|--------|
| Print | Screenshot area |
| Shift+Print | Screenshot full |
| Super+Shift+R | Screen recorder |
| Super+P / O / I | Performance / Balanced / Power saver |
| Fn+Volume | Volume control |
| Fn+Brightness | Brightness control |

### Scratchpad
| Key | Action |
|-----|--------|
| Super+` | Dropdown terminal |
| Super+M | Music player |
| Super+Shift+- | Send to scratchpad |
| Super+- | Show scratchpad |

## Repository Structure

```
sway-rice/
├── install.sh                  # Universal installer (builds from source)
├── post-install-config.sh      # Post-install user config
├── test-components.sh          # Verify installation
├── install-xdg-wlr.sh          # Standalone portal-wlr builder
├── convert_cursors.sh          # Windows .ani/.cur → Xcursor
│
├── common/
│   ├── scripts/                # Helper scripts → ~/.config/sway/
│   │   ├── wofi-run.sh         # Wofi singleton wrapper
│   │   ├── auto-split.sh       # Dwindle tiling
│   │   ├── wallpaper-apply.sh  # Wallpaper engine
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
│   ├── theme-switch.sh         # Theme switch engine
│   ├── theme-switcher.sh       # Theme picker UI (Super+T)
│   ├── theme-switch-wofi.sh    # Quick theme list (Super+Y)
│   ├── wallpaper-picker.sh     # Wallpaper picker (Super+W)
│   ├── _gen-preview.sh         # Preview generator
│   ├── matugen/                # Material You color templates
│   ├── fastfetch/              # Fastfetch art assets
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
├── README.md                   # This file (English)
├── README.id.md                # Indonesian
├── QUICKSTART.md               # 3-step install guide
├── TROUBLESHOOTING.md          # Detailed troubleshooting
└── CHANGELOG.md                # Version history
```

## Components Built from Source

| Component | Source | Build |
|-----------|--------|-------|
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

## System Utilities (installed via package manager)

These are usually pre-installed on full desktop images (e.g. Rocky Linux + GNOME)
but missing on minimal/server installs. `install.sh` now installs them explicitly
via the distro package manager, since the config and helper scripts depend on them:

| Utility | Used for |
|---------|----------|
| python3 | dwindle auto-split tiling, theme switcher, config reload |
| ImageMagick | lock screen blur (Super+L), theme preview generation |
| pipewire + pipewire-pulse + wireplumber | audio, volume control, `pw-record` capture |
| xdg-utils | default app associations (`xdg-mime`, `xdg-settings`) |
| dbus | portal activation environment |
| fontconfig | font cache (`fc-cache`) |
| dconf + gsettings-desktop-schemas | GTK dark theme + cursor (`gsettings`) |
| NetworkManager | `nmtui` / `nm-connection-editor` from Waybar |
| cliphist *(optional)* | clipboard history (Super+Shift+V) |
| wtype / wlsunset *(optional)* | auto-paste, night light |

## Documentation

- **[QUICKSTART.md](QUICKSTART.md)** — 3-step installation
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** — Screen sharing, audio, shutdown hang, SELinux, etc
- **[CHANGELOG.md](CHANGELOG.md)** — Version history
- **[docs/LIVE-WALLPAPER.md](docs/LIVE-WALLPAPER.md)** — Live wallpaper guide
- **[README.id.md](README.id.md)** — Dokumentasi Bahasa Indonesia

## License

Free to use and modify. Genshin Impact assets (wallpapers, cursors, video) are property of HoYoverse — do not redistribute commercially.
