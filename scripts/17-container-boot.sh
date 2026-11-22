#!/bin/bash
# 17 — Boot ordering for the arch-omarchy container (USER scope).
#
# Deploys an idempotent user unit that cleans + starts the container before any
# distrobox-exported service tries to enter it, plus a drop-in for herdr.service
# so a re-export of the shim cannot undo the ordering.
#
# Usage: ./17-container-boot.sh [--check] [--dry-run] [--uninstall]
#   --check     Read-only report (exit 1 if not deployed)
#   --dry-run   Print mutations, change nothing
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DRY_RUN=${DRY_RUN:-0}
CHECK=0
UNINSTALL=0

# shellcheck source=scripts/lib-installer.sh
. "$REPO/scripts/lib-installer.sh"

UNIT=arch-omarchy-container.service
UNIT_SRC="$REPO/configs/systemd/$UNIT"
UNIT_DST="$HOME/.config/systemd/user/$UNIT"
DROPIN_SRC="$REPO/configs/systemd/herdr.service.d/10-container.conf"
DROPIN_DST="$HOME/.config/systemd/user/herdr.service.d/10-container.conf"

usage() {
  cat <<EOF
Usage: $0 [--check] [--dry-run] [--uninstall]
  --check     Read-only report (exit 1 if not deployed)
  --dry-run   Print mutations, change nothing
  --uninstall Remove the unit and drop-in, disable the unit
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --check)    CHECK=1; DRY_RUN=1; shift ;;
    --dry-run)  DRY_RUN=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    -h|--help)  usage; exit 0 ;;
    *) idie "unknown flag: $1" ;;
  esac
done

ilog "== 17-container-boot (user=$(id -un)) =="

USER_BUS=0
if systemd_available && [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -S "$XDG_RUNTIME_DIR/systemd/private" ] 2>/dev/null; then
  USER_BUS=1
fi

if [ "$UNINSTALL" = 1 ]; then
  if [ "$USER_BUS" = 1 ]; then
    run systemctl --user disable "$UNIT" || true
  fi
  run rm -f "$UNIT_DST" "$DROPIN_DST"
  if [ "$USER_BUS" = 1 ]; then
    run systemctl --user daemon-reload || true
  fi
  ilog "17-container-boot: uninstalled"
  exit 0
fi

# 1. Deploy the container unit and the herdr drop-in.
atomic_install "$UNIT_SRC" "$UNIT_DST" 644
atomic_install "$DROPIN_SRC" "$DROPIN_DST" 644

# 2. Reload + enable/start. The unit is a oneshot: starting it when the container
#    is already running is a no-op; otherwise it cleans stale state and starts it.
if [ "$USER_BUS" = 1 ]; then
  run systemctl --user daemon-reload
  run systemctl --user enable --now "$UNIT"
else
  ilog "  Container mode / no user bus: skipping systemctl --user reload/enable"
fi

# 3. Verify.
ilog "Verification:"
rc=0
if [ -f "$UNIT_DST" ]; then
  ilog "  unit: present at $UNIT_DST"
else
  iwarn "  FAIL  missing $UNIT_DST"; rc=1
fi
if [ -f "$DROPIN_DST" ]; then
  ilog "  herdr drop-in: present"
else
  iwarn "  FAIL  missing $DROPIN_DST"; rc=1
fi
if [ "$USER_BUS" = 1 ]; then
  enabled=$(systemctl --user is-enabled "$UNIT" 2>/dev/null || true)
  active=$(systemctl --user is-active "$UNIT" 2>/dev/null || true)
  ilog "  unit state: enabled=$enabled active=$active"
  [ "$enabled" = enabled ] || { iwarn "  WARN  unit not enabled"; rc=1; }
  if [ -f "$HOME/.config/systemd/user/herdr.service" ]; then
    requires=$(systemctl --user show herdr.service -p Requires --value 2>/dev/null || true)
    case "$requires" in
      *"$UNIT"*) ilog "  herdr.service Requires: $UNIT present" ;;
      *) iwarn "  WARN  herdr.service has no Requires=$UNIT (reload/restart needed)"; rc=1 ;;
    esac
  else
    ilog "  herdr.service not installed here — drop-in is inert until it is"
  fi
else
  ilog "  no user bus: systemd state checks skipped"
fi
if command -v podman >/dev/null 2>&1; then
  state=$(podman inspect --format '{{.State.Status}}' arch-omarchy 2>/dev/null || true)
  ilog "  arch-omarchy: ${state:-absent}"
fi

[ "$CHECK" = 1 ] && exit "$rc"
ilog "17-container-boot: done"
exit "$rc"
