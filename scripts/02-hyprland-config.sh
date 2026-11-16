#!/bin/bash
# 02 — Deploy the Hyprland config set (configs/hypr/*.conf + hyprland.lua → ~/.config/hypr/).
# Idempotent: backs up any existing file to <file>.pre-hyprland first.
#
# hyprland.lua is the active config (Hyprland prefers Lua at startup); the
# .conf set is kept as a fallback and for `install.sh binds` profile switching.
#
# NOTE: this also (re)deploys configs/hypr/binds.conf, i.e. the niri profile.
# Run `./install.sh binds <profile>` afterwards to restore the selected keymap.
#
# Write-order hardening: stage every source file into a temp dir first, then
# move into place. A reload racing the deploy no longer sees a half-written
# target (the transient `source` glob error seen on 2026-11-15).
#
# Usage: ./02-hyprland-config.sh
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SRC="$REPO_DIR/configs/hypr"
DST="$HOME/.config/hypr"

mkdir -p "$DST"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

for f in "$SRC"/*.conf; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    install -Dm644 "$f" "$STAGE/$base"
    if [ -f "$DST/$base" ] && ! cmp -s "$f" "$DST/$base"; then
        cp -a "$DST/$base" "$DST/$base.pre-hyprland"
    fi
done

if [ -f "$SRC/hyprland.lua" ]; then
    install -Dm644 "$SRC/hyprland.lua" "$STAGE/hyprland.lua"
    if [ -f "$DST/hyprland.lua" ] && ! cmp -s "$SRC/hyprland.lua" "$DST/hyprland.lua"; then
        cp -a "$DST/hyprland.lua" "$DST/hyprland.lua.pre-hyprland"
    fi
fi

for f in "$STAGE"/*.conf "$STAGE"/*.lua; do
    [ -f "$f" ] || continue
    install -Dm644 "$f" "$DST/$(basename "$f")"
done

echo
echo "Validating..."
if command -v Hyprland >/dev/null 2>&1; then
    if [ -f "$DST/hyprland.lua" ]; then
        Hyprland --verify-config -c "$DST/hyprland.lua" 2>&1 | tail -3
    else
        Hyprland --verify-config -c "$DST/hyprland.conf" 2>&1 | tail -3
    fi
else
    echo "Hyprland not installed — skipping validation."
fi
