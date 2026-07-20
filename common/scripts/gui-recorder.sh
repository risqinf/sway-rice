#!/usr/bin/env bash
# =============================================================================
# SCREEN & AUDIO RECORDER — wf-recorder + PipeWire
# =============================================================================
# Cara kerja audio:
#   - "System Audio"  → suara speaker (YouTube, Discord, game, dll.) direkam
#     lewat <default-sink>.monitor — mirror persis dari yang Anda dengar.
#   - "Mic"           → mikrofon fisik via @DEFAULT_AUDIO_SOURCE@.
#   - "System + Mic"  → sebuah virtual mic (pw-loopback) dibuat sesaat yang
#     menggabungkan monitor speaker + mic fisik, lalu wf-recorder merekam dari
#     situ. Node virtual dihapus otomatis saat Stop.
#
# Audio direkam lewat backend PulseAudio (pipewire-pulse). Nama node monitor
# PipeWire dipakai langsung (mis. <sink>.monitor).
# =============================================================================
set -euo pipefail

DIR="$HOME/Videos"
AUDIO_DIR="$HOME/Music/Recordings"
mkdir -p "$DIR" "$AUDIO_DIR"

LOOPBACK_NAME="rec_mix_sink"
LOOPBACK_DESC="Recorder Mix (System+Mic)"

# --- Helper: nama node PipeWire dari wpctl inspect ---
_pw_node_name() {
    wpctl inspect "$1" 2>/dev/null | grep -oP 'node\.name = "\K[^"]+' | head -1
}

# Monitor source dari sink default = suara yang keluar ke speaker.
get_system_monitor() {
    local sink_name
    sink_name=$(_pw_node_name @DEFAULT_AUDIO_SINK@)
    echo "${sink_name:+$sink_name.monitor}"
}

# Source mic default.
get_mic_source() {
    _pw_node_name @DEFAULT_AUDIO_SOURCE@
}

# Buat virtual sink gabungan system+mic, kembalikan nama .monitor-nya.
# Dipakai mode "System + Mic" agar wf-recorder bisa rekam keduanya sekaligus.
make_mix_source() {
    local sys_mon mic
    sys_mon="$(get_system_monitor)"
    mic="$(get_mic_source)"
    [[ -n "$sys_mon" && -n "$mic" ]] || { echo ""; return 1; }

    # Hapus sisa loopback lama bila ada
    destroy_mix_source >/dev/null 2>&1 || true

    # Sink virtual; output speaker & mic diarahkan ke sini lewat pw-link.
    pw-loopback \
        --name "$LOOPBACK_NAME" \
        --description "$LOOPBACK_DESC" \
        --capture-props "node.name=$LOOPBACK_NAME media.class=Audio/Sink" \
        >/dev/null 2>&1 &
    echo $! > /tmp/waybar-loopback.pid
    # Tunggu node terdaftar
    local i
    for i in $(seq 1 20); do
        wpctl status 2>/dev/null | grep -q "$LOOPBACK_NAME" && break
        sleep 0.2
    done
    # Sambungkan monitor speaker & mic ke input sink virtual
    pw-link "${sys_mon%.*}.monitor" "$LOOPBACK_NAME" >/dev/null 2>&1 || true
    pw-link "$mic" "$LOOPBACK_NAME" >/dev/null 2>&1 || true
    echo "${LOOPBACK_NAME}.monitor"
}

destroy_mix_source() {
    if [[ -f /tmp/waybar-loopback.pid ]]; then
        kill "$(cat /tmp/waybar-loopback.pid)" >/dev/null 2>&1 || true
        rm -f /tmp/waybar-loopback.pid
    fi
}

MENU_ITEMS="\uf03d  Video + System Audio (Fullscreen)
\uf125  Video + System Audio (Region)
\uf03d \uf130  Video + System + Mic (Fullscreen)
\uf125 \uf130  Video + System + Mic (Region)
\uf03d \uf6a9  Video Only, No Audio (Fullscreen)
\uf125 \uf6a9  Video Only, No Audio (Region)
\uf028  Audio Only (System)
\uf028 \uf130  Audio (System + Mic)
\uf130  Audio Only (Mic)
\uf28d  Stop Recording"

if command -v wofi >/dev/null; then
    CHOICE=$(echo -e "$MENU_ITEMS" | wofi --show dmenu --prompt "Recorder Control" 2>/dev/null)
elif command -v rofi >/dev/null; then
    CHOICE=$(echo -e "$MENU_ITEMS" | rofi -dmenu -i -p "Recorder Control" 2>/dev/null)
else
    exit 1
fi

[[ -z "${CHOICE:-}" ]] && exit 0

start_rec() {
    wf-recorder "$@" &
    echo $! > /tmp/waybar-recorder.pid
}

# Rekam audio-murni pakai pw-record (PipeWire native), fallback ke ffmpeg pulse.
record_audio() {
    # $1 = source node, $2 = file output
    local src="$1" out="$2"
    if command -v pw-record >/dev/null; then
        pw-record --target "$src" "$out" &
    else
        ffmpeg -f pulse -i "$src" -acodec libmp3lame -ab 192k "${out%.wav}.mp3" &
    fi
    echo $! > /tmp/waybar-audio-system.pid
}

case "$CHOICE" in
    *"Video + System Audio (Fullscreen)"*)
        FILE="$DIR/Video_SysAudio_Full_$(date +%Y%m%d_%H%M%S).mp4"
        echo "$FILE" > /tmp/last_record
        start_rec -c libx264 -p crf=15 \
            --audio="$(get_system_monitor)" -f "$FILE"
        notify-send "Recording" "Video + System Audio (Fullscreen)"
        ;;
    *"Video + System Audio (Region)"*)
        AREA=$(slurp) || exit 0
        [[ -n "$AREA" ]] || exit 0
        FILE="$DIR/Video_SysAudio_Area_$(date +%Y%m%d_%H%M%S).mp4"
        echo "$FILE" > /tmp/last_record
        start_rec -g "$AREA" -c libx264 -p crf=15 \
            --audio="$(get_system_monitor)" -f "$FILE"
        notify-send "Recording" "Video + System Audio (Region)"
        ;;
    *"Video + System + Mic (Fullscreen)"*)
        MIX="$(make_mix_source)"
        if [[ -z "$MIX" ]]; then
            notify-send "Recorder" "Gagal membuat mix source — fallback ke system audio saja"
            MIX="$(get_system_monitor)"
        fi
        FILE="$DIR/Video_SysMic_Full_$(date +%Y%m%d_%H%M%S).mp4"
        echo "$FILE" > /tmp/last_record
        start_rec -c libx264 -p crf=15 --audio="$MIX" -f "$FILE"
        notify-send "Recording" "Video + System + Mic (Fullscreen)"
        ;;
    *"Video + System + Mic (Region)"*)
        AREA=$(slurp) || exit 0
        [[ -n "$AREA" ]] || exit 0
        MIX="$(make_mix_source)"
        if [[ -z "$MIX" ]]; then
            notify-send "Recorder" "Gagal membuat mix source — fallback ke system audio saja"
            MIX="$(get_system_monitor)"
        fi
        FILE="$DIR/Video_SysMic_Area_$(date +%Y%m%d_%H%M%S).mp4"
        echo "$FILE" > /tmp/last_record
        start_rec -g "$AREA" -c libx264 -p crf=15 --audio="$MIX" -f "$FILE"
        notify-send "Recording" "Video + System + Mic (Region)"
        ;;
    *"Video Only, No Audio (Fullscreen)"*)
        FILE="$DIR/Video_NoAudio_Full_$(date +%Y%m%d_%H%M%S).mp4"
        echo "$FILE" > /tmp/last_record
        start_rec -c libx264 -p crf=15 -f "$FILE"
        notify-send "Recording" "Video Only (Fullscreen)"
        ;;
    *"Video Only, No Audio (Region)"*)
        AREA=$(slurp) || exit 0
        [[ -n "$AREA" ]] || exit 0
        FILE="$DIR/Video_NoAudio_Area_$(date +%Y%m%d_%H%M%S).mp4"
        echo "$FILE" > /tmp/last_record
        start_rec -g "$AREA" -c libx264 -p crf=15 -f "$FILE"
        notify-send "Recording" "Video Only (Region)"
        ;;
    *"Audio Only (System)"*)
        FILE="$AUDIO_DIR/Audio_System_$(date +%Y%m%d_%H%M%S).wav"
        echo "$FILE" > /tmp/last_record
        record_audio "$(get_system_monitor)" "$FILE"
        notify-send "Recording" "Audio System"
        ;;
    *"Audio (System + Mic)"*)
        FILE="$AUDIO_DIR/Audio_SysMic_$(date +%Y%m%d_%H%M%S).wav"
        echo "$FILE" > /tmp/last_record
        MIX="$(make_mix_source)"
        [[ -z "$MIX" ]] && MIX="$(get_system_monitor)"
        record_audio "$MIX" "$FILE"
        notify-send "Recording" "Audio System + Mic"
        ;;
    *"Audio Only (Mic)"*)
        FILE="$AUDIO_DIR/Audio_Mic_$(date +%Y%m%d_%H%M%S).wav"
        echo "$FILE" > /tmp/last_record
        record_audio "$(get_mic_source)" "$FILE"
        notify-send "Recording" "Audio Mic"
        ;;
    *"Stop Recording"*)
        pgrep -x wf-recorder >/dev/null && killall -s SIGINT wf-recorder 2>/dev/null || true
        pgrep -x pw-record >/dev/null && killall -s SIGINT pw-record 2>/dev/null || true
        pgrep -x ffmpeg >/dev/null && killall -s SIGINT ffmpeg 2>/dev/null || true
        destroy_mix_source
        sleep 1
        rm -f /tmp/waybar-recorder.pid /tmp/waybar-audio-system.pid 2>/dev/null || true
        LAST_FILE=$(cat /tmp/last_record 2>/dev/null || echo "unknown")
        notify-send "Saved" "File: $LAST_FILE"
        ;;
esac
