# Changelog

## v4.0 — 2026-07-21

### New Features
- **Wofi singleton system** (`wofi-run.sh`) — mencegah wofi yang sama dibuka 2x;
  buka di workspace lain akan memindahkan (kill + reopen) instance lama.
  Nama berbeda (theme, wallpaper, emoji, launcher, dll) tetap bisa buka bersamaan.
- **Theme switcher & wallpaper picker fullscreen center** — ukuran 80%x85% layar,
  di-tengah, dengan responsive image preview yang scale dari resolusi output.
- **Hyprland-style dwindle tiling** (`auto-split.sh`) — window baru otomatis
  split bergantian kanan→bawah→kanan, menggantikan sway default yang selalu horizontal.

### Bug Fixes
- **Border window menyentuh waybar** — waybar (`layer:top`, height 38, margin 6+4)
  sudah reserve 48px exclusive zone; `gaps top` di-kalibrasi agar border rapat
  tapi tidak pernah overlap.
- **Workspace jump saat reload/ganti theme** — dihapus `focus` dari `for_window`
  rules yang memaksa fokus ke window tertentu; restore workspace sekarang
  konsisten pakai `workspace number` (bukan nama hiragana) di semua script.
- **Image preview tidak muncul** di theme switcher & wallpaper picker —
  `wofi-run.sh` v1 background wofi dengan `&` yang memutus stdin pipe;
  v2 pakai `exec` di foreground sehingga stdin tetap tersambung.

### Config Changes
- `gaps inner 2`, `gaps outer 2`, `gaps top 2` (waybar handles top spacing)
- `smart_gaps off` (konsisten, tidak hilang saat 1 window)
- `for_window` rules tidak lagi pakai `focus` command

---

## v3.0 — 2026-07 (Bugfix Pass)

Ditemukan & diperbaiki lewat debugging langsung di Rocky Linux 10.2:

1. **`install.sh` DEP_RHEL salah nama paket** — satu typo membatalkan seluruh
   batch dnf transaction, menggagalkan wlroots+sway+waybar sekaligus.
   `run_pkg_install()` sekarang fallback install satu-per-satu.
2. **Screen sharing gagal total** — `xdg-desktop-portal` hardcode cari `*.portal`
   di compile-time datadir, tidak ikuti `XDG_DATA_DIRS`. `wlr.portal` sekarang
   disalin ke `/usr/share/xdg-desktop-portal/portals/`.
3. **Sway config race condition** — manual portal spawn dihapus; `exec_always
   pkill mako; mako` parsing bug diperbaiki (`;` adalah separator sway, bukan shell).
4. **Persistent journald** — `/var/log/journal` diaktifkan untuk diagnosis
   shutdown hang.

---

## v2.0 — 2024-12

- xdg-desktop-portal-wlr auto-build dari source (screen sharing support)
- Fish shell support (repo-first, fallback build dari source)
- `post-install-config.sh` — portal, pipewire, default apps, GTK theme, fish
- `test-components.sh` — verifikasi semua komponen pasca-install
- `TROUBLESHOOTING.md`, `QUICKSTART.md`, `CHANGELOG.md`
- Dependency mappings untuk pipewire/inih/systemd/pcre2/gettext
