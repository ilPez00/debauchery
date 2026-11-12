#!/bin/bash
# 05 — MacBook function-row fix (hid_apple fnmode).
#
# Plain press of F1–F12 currently emits the F1–F12 keysyms (fnmode=2), so the
# Hyprland binds.conf maps them to the special functions. Fn+key emits the XF86
# media keysyms, which are also bound.
#
# macOS-style alternative: set fnmode=1 (media on plain press, Fn+key = real
# F1–F12). That needs root and makes the F-key binds in binds.conf inert.
#
# Usage: ./05-function-row.sh [1|2]
#   1  media keys on plain press (macOS-like; Fn+key = F1–F12)
#   2  F1–F12 on plain press (default; Fn+key = media)  [current]
set -euo pipefail

MODE=${1:-2}

echo "current fnmode: $(cat /sys/module/hid_apple/parameters/fnmode 2>/dev/null || echo '?')"

if [ "$MODE" = "1" ]; then
    echo "setting fnmode=1 (media by default; Fn+key = real F1–F12)"
    echo "This needs root. Run:"
    echo "  sudo sh -c 'echo 1 > /sys/module/hid_apple/parameters/fnmode'"
    echo "  echo 'options hid_apple fnmode=1' | sudo tee /etc/modprobe.d/hid_apple.conf"
    echo
    echo "Then only the XF86* binds in binds.conf are needed."
else
    echo "keeping fnmode=2 (F1–F12 by default; Fn+key = media)"
    echo "Both F1–F12 and XF86* binds in binds.conf are active."
fi

echo
echo "Verify with: cat /sys/module/hid_apple/parameters/fnmode"
echo "See: macbook-function-keys skill / MIGRATION-niri-to-hyprland.md §4.5"
