#!/bin/bash
# 02 — Deploy the Hyprland config set (configs/hypr/*.conf → ~/.config/hypr/).
# Idempotent: backs up any existing file to <file>.pre-hyprland first.
#
# Usage: ./02-hyprland-config.sh
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SRC="$REPO_DIR/configs/hypr"
DST="$HOME/.config/hypr"

mkdir -p "$DST"
for f in "$SRC"/*.conf; do
    base=$(basename "$f")
    if [ -f "$DST/$base" ] && ! cmp -s "$f" "$DST/$base"; then
        cp -a "$DST/$base" "$DST/$base.pre-hyprland"
        echo "backed up $DST/$base"
    fi
    install -Dm644 "$f" "$DST/$base"
    echo "deployed $DST/$base"
done

echo
echo "Validating..."
if command -v Hyprland >/dev/null 2>&1; then
    Hyprland --verify-config -c "$DST/hyprland.conf" 2>&1 | tail -3
else
    echo "Hyprland not installed — skipping validation."
fi
