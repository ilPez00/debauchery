#!/bin/bash
# 16 — Session wiring (USER scope): hyprland-session.service + dms.service symlink.
# Runs as the desktop user. Idempotent. --check for read-only report.
#
# Usage: ./16-session-wiring.sh [--check] [--dry-run]
#   --check    Read-only report (used by modules.conf check + doctor)
#   --dry-run  Print mutations, change nothing
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DRY_RUN=${DRY_RUN:-0}
CHECK=0

# shellcheck source=scripts/lib-installer.sh
. "$REPO/scripts/lib-installer.sh"

usage() {
  cat <<EOF
Usage: $0 [--check] [--dry-run]
  --check    Read-only report (used by modules.conf check + doctor)
  --dry-run  Print mutations, change nothing
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --check)   CHECK=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) idie "unknown flag: $1" ;;
  esac
done

# In check mode, force dry-run
if [ "$CHECK" = 1 ]; then
  DRY_RUN=1
fi

ilog "== 16-session-wiring (user=$(id -un)) =="

# 1. Deploy hyprland-session.service
atomic_install "$REPO/configs/systemd/hyprland-session.service" \
  "$HOME/.config/systemd/user/hyprland-session.service" 644

# 2. Symlink dms.service into graphical-session.target.wants
WANTS_DIR="$HOME/.config/systemd/user/graphical-session.target.wants"
DMS_SERVICE="/usr/lib/systemd/user/dms.service"
run mkdir -p "$WANTS_DIR"
if [ -L "$WANTS_DIR/dms.service" ]; then
  if [ "$(readlink "$WANTS_DIR/dms.service")" = "$DMS_SERVICE" ]; then
    ilog "  = dms.service symlink already correct"
  else
    run ln -sfn "$DMS_SERVICE" "$WANTS_DIR/dms.service"
    ilog "  + dms.service symlink updated"
  fi
elif [ -e "$WANTS_DIR/dms.service" ]; then
  backup_once "$WANTS_DIR/dms.service"
  run ln -sfn "$DMS_SERVICE" "$WANTS_DIR/dms.service"
  ilog "  + dms.service symlink replaced"
else
  if [ -f "$DMS_SERVICE" ]; then
    run ln -sfn "$DMS_SERVICE" "$WANTS_DIR/dms.service"
    ilog "  + dms.service symlink created"
  else
    iwarn "  WARN  $DMS_SERVICE not found — dms package may not be installed"
  fi
fi

# 3. systemctl --user daemon-reload
if systemd_available && [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -S "$XDG_RUNTIME_DIR/systemd/private" ] 2>/dev/null; then
  if [ "$DRY_RUN" = 1 ]; then
    ilog "  [dry-run] would run: systemctl --user daemon-reload"
  else
    run systemctl --user daemon-reload
  fi
else
  ilog "  Container mode / no user bus: skipping systemctl --user daemon-reload"
fi

# 4. Verify
if [ "$CHECK" = 0 ] || [ "$DRY_RUN" = 1 ]; then
  ilog "Verification:"
  # Check autostart line in hyprland config
  HYPR_CONFIG=""
  if [ -f "$HOME/.config/hypr/hyprland.lua" ]; then
    HYPR_CONFIG="$HOME/.config/hypr/hyprland.lua"
  elif [ -f "$HOME/.config/hypr/hyprland.conf" ]; then
    HYPR_CONFIG="$HOME/.config/hypr/hyprland.conf"
  fi

  if [ -n "$HYPR_CONFIG" ]; then
    if grep -q 'systemctl --user start hyprland-session.service' "$HYPR_CONFIG"; then
      ilog "  autostart line: present in $HYPR_CONFIG"
    else
      iwarn "  WARN  autostart line missing in $HYPR_CONFIG"
    fi
  else
    iwarn "  WARN  no hyprland config found"
  fi

  if command -v Hyprland >/dev/null 2>&1; then
    if [ -n "$HYPR_CONFIG" ]; then
      if [ "$DRY_RUN" = 1 ]; then
        ilog "  [dry-run] would run: Hyprland --verify-config -c $HYPR_CONFIG"
      else
        if Hyprland --verify-config -c "$HYPR_CONFIG" 2>&1 | grep -q 'config ok'; then
          ilog "  Hyprland config: ok"
        else
          iwarn "  WARN  Hyprland config verification failed"
        fi
      fi
    fi
  else
    ilog "  Hyprland not installed — config verification skipped"
  fi
fi

ilog "16-session-wiring: done"