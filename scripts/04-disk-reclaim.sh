#!/bin/bash
# 04 — Disk reclaim (what was actually removed on 2026-11-12).
# Removes rebuildable caches and re-downloadable firmware tars only.
# Does NOT touch: physis-backups, ollama models, npm-global CLIs, repo .git, flatpak.
#
# Usage: ./04-disk-reclaim.sh [--with-root]
#   --with-root  also runs the root tier (apt clean, journal vacuum, unused flatpaks)
set -euo pipefail

echo "== before =="; df -h / | tail -1

echo
echo "== user caches (rebuildable) =="
rm -rf "$HOME/.cache/uv" "$HOME/.cache/copilot" "$HOME/.cache/mozilla" \
       "$HOME/.cache/opencode" "$HOME/.cache/chromium" "$HOME/.cache/pip" \
       "$HOME/.cache/flatpak" "$HOME/.cache/kilo" "$HOME/.cache/kimi-code" \
       "$HOME/.cache/gitstatus" 2>/dev/null || true
rm -rf "$HOME/.npm/_cacache" "$HOME/.bun/install/cache" 2>/dev/null || true
rm -rf "$HOME/.local/share/Trash/"* 2>/dev/null || true
echo "done"

echo
echo "== re-downloadable firmware tars =="
FW="$HOME/firmware/OMN"
if [ -d "$FW" ]; then
    for f in "$FW"/*.tar.md5; do
        [ -e "$f" ] || continue
        rm -f "$f"
        echo "removed $(basename "$f")"
    done
    echo "kept: $(ls "$FW" | tr '\n' ' ')"
    echo "re-download URLs are in $FW/README.txt"
fi

echo
echo "== after user tier =="; df -h / | tail -1

if [ "${1:-}" = "--with-root" ]; then
    echo
    echo "== root tier =="
    apt-get clean
    journalctl --vacuum-size=50M
    flatpak uninstall --unused -y || true
    echo "== after root tier =="; df -h / | tail -1
else
    echo
    echo "Root tier skipped (needs sudo). To run it:"
    echo "  sudo apt-get clean && sudo journalctl --vacuum-size=50M && sudo flatpak uninstall --unused -y"
fi
