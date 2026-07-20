#!/bin/bash
# Konversi kursor Windows (.ani/.cur) ke format Linux Xcursor
# File kursor ada di ./themes/<tema>/cursor/ relatif terhadap script ini
# Pilih tema: THEME=<nama folder themes/> (default: raiden)
# Tema tanpa folder cursor/ akan ditolak dengan pesan jelas.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME="${THEME:-raiden}"
CURSOR_DIR="$SCRIPT_DIR/themes/$THEME/cursor"

# Tolak lebih awal bila tema tidak punya folder kursor — hindari error dari
# blok case yang tidak mengenal tema baru.
if [[ ! -d "$CURSOR_DIR" ]]; then
    echo "[GAGAL] Tema '$THEME' tidak punya folder cursor/ di themes/$THEME/." >&2
    echo "        Taruh file .ani/.cur di sana, atau pilih tema lain." >&2
    exit 1
fi

# Nama tema ikon + mapping nama file kursor per tema.
# Hu Tao punya varian "Animated" (.ani) DAN statis (.cur) — kita utamakan
# yang animated agar konsisten dengan tema lain, dan karena kursor statis
# Hu Tao berwarna gelap sehingga kurang kontras di latar gelap.
case "$THEME" in
    raiden)
        ICON_NAME="RaidenShogun"
        C_NORMAL="Raiden Normal Select"
        C_HELP="Raiden Help Select"
        C_WORKING="Raiden Working in Background"
        C_BUSY="Raiden Busy"
        C_PRECISION="Raiden Precision Select"
        C_TEXT="Raiden Text"
        C_UNAVAILABLE="Raiden Unavailable"
        C_VERTICAL="Raiden Vertical Resize"
        C_HORIZONTAL="Raiden Horizontal Select"
        C_DIAG1="Raiden Diagonal Resize 1"
        C_DIAG2="Raiden Diagonal Resize 2"
        C_MOVE="Raiden Move"
        C_ALT="Raiden Alternate Select"
        C_LINK="Raiden Link Select"
        ;;
    hutao)
        ICON_NAME="HuTao"
        C_NORMAL="Hu Tao Normal Select"
        C_HELP="Hu Tao Help Animated"
        C_WORKING="Hu Tao Working in Background Animated"
        C_BUSY="Hu Tao Busy Animated"
        C_PRECISION="Hu Tao Precision Select"
        C_TEXT="Hu Tao Text Select"
        C_UNAVAILABLE="Hu Tao Unavailable"
        C_VERTICAL="Hu Tao Vertical Resize Animated"
        C_HORIZONTAL="Hu Tao Horizontal Resize Animated"
        C_DIAG1="Hu Tao Diagonal Resize 1 Animated"
        C_DIAG2="Hu Tao Diagonal Resize 2 Animated"
        C_MOVE="Hu Tao Move Animated"
        C_ALT="Hu Tao Alternate Select"
        C_LINK="Hu Tao Link Select Animated"
        ;;
    furina)
        ICON_NAME="Furina"
        C_NORMAL="Furina (Normal) Cursor"
        C_HELP="Furina (Help) Cursor"
        C_WORKING="Furina (Working In Background) Cursor"
        C_BUSY="Furina (Busy) Cursor"
        C_PRECISION="Furina (Precision) Cursor"
        C_TEXT="Furina (Text) Cursor"
        C_UNAVAILABLE="Furina (Unavailable) Cursor"
        C_VERTICAL="Furina (Vertical) Cursor"
        C_HORIZONTAL="Furina (Horizontal) Cursor"
        C_DIAG1="Furina (Diagonal1) Cursor"
        C_DIAG2="Furina (Diagonal2) Cursor"
        C_MOVE="Furina (Move) Cursor"
        C_ALT="Furina (Alternative) Cursor"
        C_LINK="Furina (Link) Cursor"
        ;;
    xiao)
        ICON_NAME="Xiao"
        C_NORMAL="Xiao Normal Select"
        C_HELP="Xiao Help Animated"
        C_WORKING="Xiao Working in Background Animated"
        C_BUSY="Xiao Busy Animated"
        C_PRECISION="Xiao Precision Select"
        C_TEXT="Xiao Text Select"
        C_UNAVAILABLE="Xiao Unavailable"
        C_VERTICAL="Xiao Vertical Resize Animated"
        C_HORIZONTAL="Xiao Horizontal Resize Animated"
        C_DIAG1="Xiao Diagonal Resize 1 Animated"
        C_DIAG2="Xiao Diagonal Resize 2 Animated"
        C_MOVE="Xiao Move Animated"
        C_ALT="Xiao Alternate Select"
        C_LINK="Xiao Link Select Animated"
        ;;
    kazuha)
        ICON_NAME="Kazuha"
        C_NORMAL="Normal Select"
        C_HELP="Help Select"
        C_WORKING="working in background"
        C_BUSY="Busy"
        C_PRECISION="Precision Select "
        C_TEXT="Text Select"
        C_UNAVAILABLE="Unavailable "
        C_VERTICAL="Vertical Resize"
        C_HORIZONTAL="Horizontal Resize"
        C_DIAG1="Diagonal Rezise 1"
        C_DIAG2="Diagonal Rezise 2"
        C_MOVE="Move"
        C_ALT="Alternate Select"
        C_LINK="Link Select 5"
        ;;
    *)
        echo "[GAGAL] Tema tidak dikenal: '$THEME'." >&2
        echo "        Tema dengan mapping kursor: raiden|hutao|furina|xiao|kazuha" >&2
        exit 1
        ;;
esac

ICON_DIR="$HOME/.local/share/icons/$ICON_NAME/cursors"

# Cek apakah ada file kursor
if [[ ! -d "$CURSOR_DIR" ]] || [[ -z "$(ls -A "$CURSOR_DIR"/*.cur "$CURSOR_DIR"/*.ani 2>/dev/null)" ]]; then
    echo "[GAGAL] Tidak ditemukan file .cur/.ani di $CURSOR_DIR/" >&2
    exit 1
fi

echo "[+] Tema: $THEME -> nama ikon: $ICON_NAME"
# Dependensi ImageMagick hanya dipasang bila belum ada — dan jangan gagalkan
# seluruh konversi bila sudo butuh password interaktif (mis. dipanggil dari
# theme-switcher di dalam sesi grafis tanpa TTY).
if ! command -v magick >/dev/null 2>&1 && ! command -v convert >/dev/null 2>&1; then
    echo "[+] Memasang dependensi ImageMagick..."
    if command -v dnf >/dev/null; then
        sudo -n dnf install -y ImageMagick ImageMagick-devel 2>/dev/null || \
            echo "  [LEWATI] sudo butuh password — lanjut tanpa install IM" >&2
    elif command -v apt >/dev/null; then
        sudo -n apt install -y imagemagick 2>/dev/null || true
    elif command -v pacman >/dev/null; then
        sudo -n pacman -S --needed --noconfirm imagemagick 2>/dev/null || true
    fi
fi

echo "[+] Menyiapkan Python Virtual Environment..."
BUILD_DIR="$(mktemp -d /tmp/cursor-build.XXXXXX)"
trap 'rm -rf "$BUILD_DIR"' EXIT

cd "$BUILD_DIR"
python3 -m venv venv
source venv/bin/activate

echo "[+] Memasang win2xcur..."
pip install win2xcur

echo "[+] Mengkonversi kursor Windows ke Linux..."
mkdir -p "$ICON_DIR"
# Kumpulkan hanya file yang benar-benar ada — beberapa tema (mis. Furina)
# hanya punya .ani tanpa .cur, sehingga glob kosong harus dihindari.
CURSOR_FILES=()
shopt -s nullglob
for f in "$CURSOR_DIR"/*.ani "$CURSOR_DIR"/*.cur; do
    CURSOR_FILES+=("$f")
done
shopt -u nullglob
[[ ${#CURSOR_FILES[@]} -eq 0 ]] && { echo "[GAGAL] Tidak ada .ani/.cur di $CURSOR_DIR" >&2; exit 1; }
win2xcur "${CURSOR_FILES[@]}" -o "$ICON_DIR"/

echo "[+] Memetakan nama kursor ke standar Linux X11..."
cd "$ICON_DIR"

# win2xcur menghasilkan nama file persis dari nama sumber Windows
# (spasi dipertahankan). Petakan ke nama X11 standar.
declare -A CURSOR_MAP=(
    ["$C_NORMAL"]="left_ptr arrow default"
    ["$C_HELP"]="help question_arrow"
    ["$C_WORKING"]="left_ptr_watch half-busy"
    ["$C_BUSY"]="wait watch"
    ["$C_PRECISION"]="crosshair cross"
    ["$C_TEXT"]="text xterm ibeam"
    ["$C_UNAVAILABLE"]="not-allowed crossed_circle"
    ["$C_VERTICAL"]="size_ver ns-resize row-resize"
    ["$C_HORIZONTAL"]="size_hor ew-resize col-resize"
    ["$C_DIAG1"]="nwse-resize size_fdiag"
    ["$C_DIAG2"]="nesw-resize size_bdiag"
    ["$C_MOVE"]="move fleur all-scroll"
    ["$C_ALT"]="up_arrow"
    ["$C_LINK"]="pointer hand1 hand2"
)

for src in "${!CURSOR_MAP[@]}"; do
    if [[ ! -e "$src" ]]; then
        echo "  [LEWATI] '$src' tidak ada hasil konversinya" >&2
        continue
    fi
    for target in ${CURSOR_MAP[$src]}; do
        ln -sf "$src" "$target"
    done
done

# index.theme wajib ada agar tema ikon dikenali sistem
cat > "$ICON_DIR/../index.theme" << EOF
[Icon Theme]
Name=$ICON_NAME
Comment=Genshin $THEME cursor theme (converted by sway-rice)
Inherits=default
EOF

echo "[+] Berhasil! Kursor $ICON_NAME telah diinstal ke $ICON_DIR"
