#!/bin/bash
# Backup air's desktop configs before any Omarchy integration phase.
# Usage: backup-desktop.sh [YYYY-MM-DD]
set -euo pipefail

STAMP=${1:-$(date +%Y-%m-%d)}
DEST=$HOME/debauchery/backups/$STAMP
mkdir -p "$DEST"

for app in niri dms hypr quickshell waybar fuzzel ly; do
    [ -e "$HOME/.config/$app" ] || continue
    if [ -e "$DEST/$app" ]; then
        echo "$app already backed up in $DEST"
        continue
    fi
    cp -a "$HOME/.config/$app" "$DEST/"
    echo "backed up ~/.config/$app"
done

[ -e "$DEST/applications" ] || cp -a "$HOME/.local/share/applications" "$DEST/applications" 2>/dev/null || true
[ -e "$DEST/systemd-user" ] || cp -a "$HOME/.config/systemd/user" "$DEST/systemd-user" 2>/dev/null || true

ls /usr/share/wayland-sessions/ > "$DEST/sessions-before.txt"
dpkg -l 2>/dev/null | grep -Ei 'niri|dms|quickshell|hyprland' > "$DEST/pkgs-before.txt" || true

echo "backed up to $DEST"
