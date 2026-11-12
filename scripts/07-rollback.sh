#!/bin/bash
# 07 — Rollback helpers (per-phase undo).
#
# Usage: ./07-rollback.sh [hyprland|distrobox|adapter|all]
set -euo pipefail

ACTION=${1:-hyprland}

case "$ACTION" in
  hyprland)
    echo "Removing Hyprland (niri stays):"
    echo "  sudo apt remove hyprland hyprlock hypridle hyprpaper xdg-desktop-portal-hyprland uwsm"
    echo "  rm -rf ~/.config/hypr"
    echo
    echo "To restore the pre-migration niri config:"
    echo "  cp -a ~/debauchery/backups/2026-11-12/niri ~/.config/niri"
    ;;
  distrobox)
    echo "Removing the Arch Distrobox:"
    echo "  distrobox stop arch-omarchy"
    echo "  distrobox rm arch-omarchy"
    echo "  podman system prune -f"
    echo "  rm -rf ~/.local/share/distrobox/arch-omarchy-home"
    ;;
  adapter)
    echo "Removing the Physis adapter:"
    echo "  cd ~/dev/physis-next/adapters/omarchy && ./uninstall.sh"
    ;;
  all)
    "$0" hyprland
    echo
    "$0" distrobox
    echo
    "$0" adapter
    ;;
  *)
    echo "usage: $0 [hyprland|distrobox|adapter|all]" >&2
    exit 1
    ;;
esac
