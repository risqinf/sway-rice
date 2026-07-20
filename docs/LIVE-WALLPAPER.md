# Live Wallpaper Guide

## Overview

Sway-rice mendukung **live wallpaper** (video animasi) sebagai background desktop, di samping wallpaper static biasa. Sistem ini scalable — theme bisa pakai static atau live wallpaper, dan user bisa menambahkan wallpaper sendiri ke registry.

---

## Cara Kerja

| Type | Format | Engine | Use Case |
|------|--------|--------|----------|
| **Static** | PNG, JPG, JPEG, WebP, BMP | `swww` | Wallpaper biasa, ringan |
| **Live** | MP4, WebM, MKV, AVI, MOV, GIF | `mpvpaper` (fallback: `swww` untuk GIF) | Video animasi, loop background |

**Registry**: Semua wallpaper user disimpan di `~/.local/share/sway-rice/wallpapers/`

---

## Menambahkan Live Wallpaper

### Method 1: Via Command Line (Recommended)

```bash
# Register video ke registry
wallpaper-apply.sh register /path/to/video.mp4 "Nama Wallpaper"

# Atau untuk GIF
wallpaper-apply.sh register /path/to/animation.gif "Nama GIF"

# Apply langsung tanpa register
wallpaper-apply.sh apply /path/to/video.mp4
```

### Method 2: Via Wallpaper Picker (GUI)

1. Tekan `Super+W`
2. Wallpaper dari registry muncul dengan badge `[LIVE]`
3. Pilih dan tekan Enter

### Method 3: Manual ke Registry

```bash
# Buat folder di registry
mkdir -p ~/.local/share/sway-rice/wallpapers/my-live-wallpaper

# Buat meta.ini
cat > ~/.local/share/sway-rice/wallpapers/my-live-wallpaper/meta.ini <<EOF
name=My Live Wallpaper
type=live
source=/home/user/Videos/my-video.mp4
registered=$(date -Iseconds)
EOF

# Symlink asset
ln -s /home/user/Videos/my-video.mp4 ~/.local/share/sway-rice/wallpapers/my-live-wallpaper/asset
```

---

## Menambahkan Live Wallpaper ke Theme

Theme bisa memiliki live wallpaper built-in:

```bash
# Struktur theme dengan live wallpaper
themes/mytheme/
├── theme.ini              # Set wallpaper_type=live
├── config/                # sway, waybar, kitty, dll.
└── wallpaper/
    ├── desktop-wallpaper.mp4    # Video wallpaper (bukan .png)
    └── gallery/                 # Optional: static gallery
```

**theme.ini**:
```ini
name=mytheme
display_name=My Theme
wallpaper_type=live          # <-- set ke 'live'
wallpaper_dir=wallpaper/gallery

[features]
live_wallpaper=true          # <-- enable fitur live
```

Preview generator (`_gen-preview.sh`) otomatis extract thumbnail dari video untuk theme switcher.

---

## Upload / Download Live Wallpaper

### Sumber Live Wallpaper

| Sumber | Format | Cara Download |
|--------|--------|---------------|
| [Wallpaper Engine](https://steamcommunity.com/app/431960) (Steam) | MP4, WebM | Extract dari workshop files |
| [Moewalls](https://moewalls.com/) | MP4 | Direct download |
| [WallpaperWaifu](https://wallpaperwaifu.com/) | MP4, WebM | Direct download |
| [Pixiv](https://pixiv.net/) | GIF, MP4 | Via browser/extension |
| YouTube | MP4 | `yt-dlp "URL" -f best[height<=1080]` |
| Reddit r/wallpaperengine | MP4, WebM | Link di comments |

### Convert Video untuk Live Wallpaper

```bash
# Optimize untuk wallpaper (1080p, 30fps, no audio, loop-friendly)
ffmpeg -i input.mp4 \
    -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,fps=30" \
    -c:v libx264 -preset slow -crf 23 \
    -an \
    -movflags +faststart \
    output-wallpaper.mp4
```

### Compress GIF (jika terlalu besar)

```bash
# GIF → MP4 (lebih kecil, lebih smooth)
ffmpeg -i input.gif \
    -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" \
    -c:v libx264 -preset slow -crf 23 \
    -pix_fmt yuv420p \
    -movflags +faststart \
    output.mp4
```

---

## Registry Structure

```
~/.local/share/sway-rice/wallpapers/
├── anime-girl-rain/
│   ├── meta.ini
│   └── asset -> /home/user/Videos/anime-girl-rain.mp4
├── cyberpunk-city/
│   ├── meta.ini
│   └── asset -> /home/user/Videos/cyberpunk-city.mp4
└── static-nature/
    ├── meta.ini
    └── asset -> /home/user/Pictures/nature.png
```

**meta.ini format**:
```ini
name=Anime Girl Rain        # Display name di picker
type=live                   # static | live
source=/path/to/video.mp4   # Absolute path ke file asli
registered=2026-07-21T10:30:00+07:00
```

---

## Commands Reference

```bash
# List semua registered wallpaper
wallpaper-apply.sh list

# Apply wallpaper (auto-detect type)
wallpaper-apply.sh apply /path/to/file

# Restore wallpaper terakhir (dipanggil saat login)
wallpaper-apply.sh restore

# Register wallpaper baru
wallpaper-apply.sh register /path/to/file.mp4 "Nama Wallpaper"
```

---

## Dependencies

| Package | Fungsi | Install |
|---------|--------|---------|
| `swww` | Static wallpaper daemon | `cargo install swww` |
| `mpvpaper` | Live wallpaper (video) | Build dari source / `cargo install mpvpaper` |
| `ffmpeg` | Thumbnail generation | Package manager |
| `matugen` | Adaptive colors | `cargo install matugen` |

**Install mpvpaper** (jika belum ada):
```bash
# Arch
yay -S mpvpaper

# Debian/Ubuntu (build from source)
git clone https://github.com/GhostNaN/mpvpaper.git
cd mpvpaper
meson setup build
ninja -C build
sudo ninja -C build install

# RHEL/Rocky/Fedora (build from source)
# sama seperti di atas
```

---

## Troubleshooting

### Live wallpaper tidak muncul
- Cek `mpvpaper` terinstall: `command -v mpvpaper`
- Cek format video didukung: `ffprobe /path/to/video.mp4`
- Cek log: `journalctl --user -u sway -f`

### Video lag / stutter
- Convert ke 1080p 30fps: lihat section "Convert Video"
- Gunakan codec H.264 (bukan HEVC/AV1 untuk kompatibilitas)
- Matikan audio track: `-an` di ffmpeg

### Theme switcher tidak show preview live
- Pastikan `ffmpeg` terinstall untuk thumbnail generation
- Cek `theme.ini` memiliki `wallpaper_type=live`
- Clear cache: `rm -rf ~/.cache/sway-rice/previews/*`

### Wallpaper tidak persist setelah reboot
- Tambahkan `wallpaper-apply.sh restore` ke autostart sway:
  ```bash
  # ~/.config/sway/config
  exec bash ~/.local/bin/wallpaper-apply.sh restore
  ```

---

## Tips

1. **Battery life**: Live wallpaper lebih boros baterai. Gunakan static untuk laptop on-battery.
2. **Performance**: 1080p 30fps cukup — 4K/60fps tidak perlu untuk background.
3. **Loop**: Pilih video yang loop-friendly (tidak ada cut/jump di akhir).
4. **Dark theme**: Live wallpaper dengan warna gelap cocok untuk theme dark (konsisten dengan aksen).
