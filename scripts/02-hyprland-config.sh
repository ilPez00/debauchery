#!/bin/bash
# 02 — Deploy the Hyprland config set (configs/hypr/*.conf → ~/.config/hypr/).
# Idempotent: backs up any existing file to <file>.pre-hyprland first.
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
    base=$(basename "$f")
    install -Dm644 "$f" "$STAGE/$base"
    if [ -f "$DST/$base" ] && ! cmp -s "$f" "$DST/$base"; then
        cp -a "$DST/$base" "$DST/$base.pre-hyprland"
    fi
done
for f in "$STAGE"/*.conf; do
    install -Dm644 "$f" "$DST/$(basename "$f")"
done

echo
echo "Validating..."
if command -v Hyprland >/dev/null 2>&1; then
    Hyprland --verify-config -c "$DST/hyprland.conf" 2>&1 | tail -3
else
    echo "Hyprland not installed — skipping validation."
fi
