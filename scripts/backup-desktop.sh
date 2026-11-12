#!/bin/bash
# Backup air's desktop configs before any Omarchy integration phase.
# Usage: backup-desktop.sh [YYYY-MM-DD]
set -euo pipefail

STAMP=${1:-$(date +%Y-%m-%d)}
DEST=$HOME/debauchery/backups/$STAMP
mkdir -p "$DEST"

for app in niri dms hypr quickshell waybar fuzzel ly; do
    if [ -e "$HOME/.config/$app" ]; then
        cp -a "$HOME/.config/$app" "$DEST/"
        echo "backed up ~/.config/$app"
    fi
done

cp -a "$HOME/.local/share/applications" "$DEST/applications" 2>/dev/null || true
cp -a "$HOME/.config/systemd/user" "$DEST/systemd-user" 2>/dev/null || true

ls /usr/share/wayland-sessions/ > "$DEST/sessions-before.txt"
dpkg -l 2>/dev/null | grep -Ei 'niri|dms|quickshell|hyprland' > "$DEST/pkgs-before.txt" || true

echo "backed up to $DEST"
