#!/usr/bin/env bash
# =============================================================================
# AUTO SPLIT — Hyprland dwindle-style tiling untuk Sway
# =============================================================================
# Dipanggil via for_window rule saat window baru muncul.
# Logic: lihat parent container dari window yang baru di-focus,
# lalu set split direction yang BERBALIK dari parent (dwindle).
#
# dwindle pattern:
#   ws (horizontal) → window 1
#   window 1 → splitv → window 2 muncul di bawah
#   window 2 → splith → window 3 muncul di kanan
#   dst.
# =============================================================================
set -euo pipefail

# Tunggu sway selesai arrange (window sudah di-place di tree)
sleep 0.08

# Dapatkan info parent dari focused window
read -r parent_layout num_siblings <<< "$(
    swaymsg -t get_tree 2>/dev/null | python3 -c "
import json, sys

def find_focused(node):
    if node.get('focused'):
        return node
    for child in node.get('nodes', []) + node.get('floating_nodes', []):
        r = find_focused(child)
        if r:
            return r
    return None

def find_parent(node, target_id):
    for child in node.get('nodes', []) + node.get('floating_nodes', []):
        if child.get('id') == target_id:
            return node
        r = find_parent(child, target_id)
        if r:
            return r
    return None

tree = json.load(sys.stdin)
focused = find_focused(tree)
if not focused or focused.get('type') not in ('con', 'floating_con'):
    sys.exit(1)

parent = find_parent(tree, focused['id'])
if not parent:
    sys.exit(1)

layout = parent.get('layout', 'unknown')
siblings = len(parent.get('nodes', []))
print(f'{layout} {siblings}')
" 2>/dev/null
)" || exit 0

# Dwindle: set split direction BERBALIK dari parent layout
# agar window BERIKUTNYA muncul di arah yang bergantian.
case "$parent_layout" in
    splith)
        # Parent horizontal → next window vertical (bawah)
        swaymsg split v 2>/dev/null || true
        ;;
    splitv)
        # Parent vertical → next window horizontal (kanan)
        swaymsg split h 2>/dev/null || true
        ;;
    tabbed|stacking)
        # Tabbed/stacking → convert ke split horizontal
        swaymsg split h 2>/dev/null || true
        ;;
    *)
        # Workspace root atau unknown → default horizontal
        # (sway default_orientation auto sudah handle ini)
        ;;
esac
