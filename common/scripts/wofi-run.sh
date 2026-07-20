#!/usr/bin/env bash
# =============================================================================
# WOFI RUN — singleton wrapper untuk semua wofi launcher
# =============================================================================
# Mencegah wofi yang sama dibuka 2x. Jika wofi dengan nama yang sama sudah
# berjalan, kill yang lama lalu buka yang baru di workspace aktif.
#
# Usage: wofi-run.sh <name> <wofi-args...>
#   name = identifier unik per launcher (misal: "theme", "wallpaper", "emoji")
# =============================================================================
set -euo pipefail

[[ $# -lt 1 ]] && { echo "Usage: $0 <name> <wofi-args...>" >&2; exit 1; }

NAME="$1"
shift

LOCKFILE="/tmp/wofi-${NAME}.lock"
PIDFILE="/tmp/wofi-${NAME}.pid"

# Kill existing wofi with same name
if [[ -f "$PIDFILE" ]]; then
    old_pid=$(cat "$PIDFILE" 2>/dev/null || echo "")
    if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
        kill "$old_pid" 2>/dev/null || true
        # Tunggu proses benar-benar mati (max 1s)
        for _ in $(seq 1 10); do
            kill -0 "$old_pid" 2>/dev/null || break
            sleep 0.1
        done
        kill -9 "$old_pid" 2>/dev/null || true
    fi
    rm -f "$PIDFILE"
fi

# Acquire lock (non-blocking, auto-release on exit)
exec 200>"$LOCKFILE"
flock -n 200 || { echo "wofi-$NAME already running" >&2; exit 1; }

# Run wofi in FOREGROUND (stdin tetap tersambung ke pipe)
# Simpan PID sebelum exec agar bisa di-track
echo $$ > "$PIDFILE"

# Cleanup PID file on exit (normal or killed)
trap 'rm -f "$PIDFILE"' EXIT

# exec replaces shell — wofi inherits stdin/stdout/stderr
exec wofi "$@"
