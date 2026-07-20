# Quick Start — Sway Rice

## Instalasi dalam 3 Langkah

### 1. Clone

```bash
git clone https://github.com/risqinf/sway-rice.git
cd sway-rice
chmod +x install.sh
```

### 2. Install

```bash
./install.sh
```

> Build dari source memakan 15–40 menit tergantung spesifikasi.
> Gunakan `./install.sh --force` untuk menimpa config tanpa backup.
> Pilih tema: `THEME=hutao ./install.sh` (default: raiden)

### 3. Post-Install & Reboot

```bash
./post-install-config.sh
sudo reboot
```

Setelah reboot, greetd akan muncul dengan tema yang dipilih.

---

## Keybind Penting

| Tombol | Aksi |
|--------|------|
| Super+Enter | Terminal |
| Super+D | App launcher |
| Super+Shift+Q | Tutup window |
| Super+T | Ganti tema (grid) |
| Super+W | Ganti wallpaper |
| Super+Shift+C | Reload config |
| Print | Screenshot |

Lengkapnya lihat [README.md](README.md).

---

## Troubleshooting Cepat

**Black screen setelah login**
```
Ctrl+Alt+F2 → login → sudo systemctl restart greetd
```

**Waybar tidak muncul**
```bash
systemctl --user restart waybar
```

**Screen sharing tidak jalan**
```bash
./post-install-config.sh
systemctl --user restart xdg-desktop-portal xdg-desktop-portal-wlr
```

**Build gagal**
```bash
cat /tmp/sway-rice-install-*.log   # cek error
./install.sh                       # re-run (idempotent)
```

Lengkapnya lihat [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

---

## Verifikasi Instalasi

```bash
./test-components.sh
```

Output: `✓ Passed` (hijau), `! Warning` (kuning, opsional), `✗ Failed` (merah, critical).
