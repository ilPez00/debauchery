#!/bin/bash
# 15 — DMS shell: install dms + quickshell from OBS repos.
# Runs as root. Idempotent. --dry-run prints every mutation.
#
# Usage: sudo ./15-dms-shell.sh [--dry-run]
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DRY_RUN=${DRY_RUN:-0}

# shellcheck source=scripts/lib-installer.sh
. "$REPO/scripts/lib-installer.sh"

usage() {
  cat <<EOF
Usage: $0 [--dry-run]
  --dry-run    Print mutations, change nothing (works unprivileged)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) idie "unknown flag: $1" ;;
  esac
done

ilog "== 15-dms-shell =="
preflight_debian
require_root

# 1. Ensure OBS repos
ensure_obs_repos

# 2. Install dms + quickshell
ilog "Installing dms and quickshell..."
run apt-get install -y dms quickshell

# 3. Log installed versions
if [ "${DRY_RUN:-0}" = 0 ]; then
  DMS_VER=$(dpkg-query -W -f '${Version}' dms 2>/dev/null || echo "not installed")
  QS_VER=$(dpkg-query -W -f '${Version}' quickshell 2>/dev/null || echo "not installed")
  ilog "  dms: $DMS_VER"
  ilog "  quickshell: $QS_VER"
else
  ilog "  [dry-run] would report: dms version, quickshell version"
fi

# 4. Verify package-shipped dms.service
if [ -f /usr/lib/systemd/user/dms.service ]; then
  ilog "  dms.service: present at /usr/lib/systemd/user/dms.service"
else
  iwarn "  WARN  /usr/lib/systemd/user/dms.service not found"
fi

# 5. No config writes (user scope, fallback is ~/.config/dms/settings.json)

ilog "15-dms-shell: done"