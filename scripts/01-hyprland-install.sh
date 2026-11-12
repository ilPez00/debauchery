#!/bin/bash
# 01 — Hyprland groundwork (Phase A of the niri→Hyprland migration).
# Installs the compositor, session tooling and the Rust toolchain, additively.
# niri is NOT removed; it stays the default session until verified.
#
# Usage: sudo ./01-hyprland-install.sh
set -euo pipefail

echo "== Hyprland groundwork =="
echo "This installs packages from trixie-backports and trixie. niri is untouched."

# Compositor + session stack (backports)
apt-get update
apt-get install -y -t trixie-backports \
    hyprland hyprlock hypridle hyprpaper \
    xdg-desktop-portal-hyprland uwsm \
    cargo rustc

# Container tooling (trixie)
apt-get install -y distrobox podman

echo
echo "Installed:"
for b in Hyprland hyprctl hyprlock hypridle hyprpaper distrobox podman cargo rustc; do
    printf '  %-12s %s\n' "$b" "$(command -v "$b" || echo MISSING)"
done

echo
echo "Sessions now available in ly:"
ls /usr/share/wayland-sessions/

echo
echo "Next: write ~/.config/hypr/*.conf (see configs/hypr/ in this repo),"
echo "then log into Hyprland from ly and verify."
