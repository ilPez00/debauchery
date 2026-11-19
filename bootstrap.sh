#!/bin/bash
# bootstrap.sh — full system installer entrypoint (Debian 13 netinst → Omarchy layer).
# Runs as root. Idempotent. --dry-run prints the full ordered plan.
#
# Usage: sudo ./bootstrap.sh [--user NAME] [--with-arch] [--autologin]
#                    [--omarchy-binds] [--skip-handoff] [--dry-run] [--yes]
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DRY_RUN=${DRY_RUN:-0}
YES=0
TARGET_USER=${DEBAUCHERY_TARGET_USER:-}
WITH_ARCH=0
AUTOLOGIN=0
OMARCHY_BINDS=0
SKIP_HANDOFF=0

usage() {
  cat <<EOF
Usage: $0 [--user NAME] [--with-arch] [--autologin] [--omarchy-binds] [--skip-handoff] [--dry-run] [--yes]
  --user NAME         Target user (default: \$SUDO_USER, else first uid 1000-60000)
  --with-arch         Include Arch distrobox (scripts/03-arch-distrobox.sh)
  --autologin         Enable ly autologin (opt-in: writes PAM + config)
  --omarchy-binds     Apply omarchy keybind profile after handoff
  --skip-handoff      Stop after root tier (no user-scope install.sh run)
  --dry-run           Print full ordered plan, change nothing (works as any user)
  --yes               Never prompt; if sudo needs password, root modules skipped
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --user)         TARGET_USER=${2:-}; shift 2 ;;
    --user=*)       TARGET_USER=${1#*=}; shift ;;
    --with-arch)    WITH_ARCH=1; shift ;;
    --autologin)    AUTOLOGIN=1; shift ;;
    --omarchy-binds) OMARCHY_BINDS=1; shift ;;
    --skip-handoff) SKIP_HANDOFF=1; shift ;;
    --dry-run)      DRY_RUN=1; shift ;;
    --yes|-y)       YES=1; shift ;;
    -h|--help)      usage; exit 0 ;;
    *)              echo "unknown flag: $1" >&2; usage; exit 2 ;;
  esac
done

# Resolve target user
if [ -z "$TARGET_USER" ]; then
  if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then
    TARGET_USER=$SUDO_USER
  else
    TARGET_USER=$(awk -F: '$3 >= 1000 && $3 <= 60000 { print $1; exit }' /etc/passwd)
  fi
fi

if [ -z "$TARGET_USER" ]; then
  echo "no target user found" >&2; exit 2
fi

if ! id "$TARGET_USER" >/dev/null 2>&1; then
  echo "user '$TARGET_USER' does not exist" >&2; exit 2
fi

TARGET_HOME=$(eval echo "~$TARGET_USER")

# Log file (only for mutating runs)
LOG_FILE=""
if [ "$DRY_RUN" = 0 ]; then
  LOG_FILE="/var/log/debauchery-bootstrap-$(date +%Y%m%d-%H%M%S).log"
  mkdir -p "$(dirname "$LOG_FILE")"
  exec > >(tee -a "$LOG_FILE") 2>&1
fi

# Dry-run: print plan and exit
if [ "$DRY_RUN" = 1 ]; then
  echo "== debauchery bootstrap --dry-run =="
  echo "Target user: $TARGET_USER"
  echo "With Arch: $WITH_ARCH"
  echo "Autologin: $AUTOLOGIN"
  echo "Omarchy binds: $OMARCHY_BINDS"
  echo "Skip handoff: $SKIP_HANDOFF"
  echo ""
  echo "Plan (in order):"
  echo "  1. scripts/13-base-system.sh --user $TARGET_USER"
  echo "  2. scripts/14-display-manager.sh --user $TARGET_USER --session hyprland$([ "$AUTOLOGIN" = 1 ] && echo " --autologin")"
  echo "  3. scripts/15-dms-shell.sh"
  echo "  4. scripts/01-hyprland-install.sh"
  if [ "$WITH_ARCH" = 1 ]; then
    echo "  5. scripts/03-arch-distrobox.sh"
  fi
  if [ "$SKIP_HANDOFF" = 0 ]; then
    echo "  6. Handoff to user $TARGET_USER:"
    echo "     runuser -u $TARGET_USER -- env HOME=$TARGET_HOME PATH=$TARGET_HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
    echo "       bash $TARGET_HOME/debauchery/install.sh install --only backup,bridge,zsh,hyprcfg,binds,shims,session$([ "$WITH_ARCH" = 1 ] && echo ",tools") --yes"
    if [ "$OMARCHY_BINDS" = 1 ]; then
      echo "     runuser -u $TARGET_USER -- bash $TARGET_HOME/debauchery/install.sh binds omarchy"
    fi
    echo "  7. Gate: runuser -u $TARGET_USER -- bash $TARGET_HOME/debauchery/install.sh doctor"
  fi
  echo ""
  echo "Firstboot checklist (after reboot):"
  echo "  - ly picker (or autologin if --autologin)"
  echo "  - SUPER+Space menu"
  echo "  - ~/debauchery/install.sh selftest"
  echo "  - niri fallback session still listed"
  exit 0
fi

# Mutating run: require root
if [ "$(id -u)" -ne 0 ]; then
  echo "bootstrap.sh must run as root (or use --dry-run)" >&2; exit 2
fi

# Preflight
. /etc/os-release 2>/dev/null || true
if [ "${ID:-}" != debian ] || [ "${VERSION_ID:-}" != 13 ]; then
  echo "expected Debian 13, found ${PRETTY_NAME:-unknown}" >&2; exit 2
fi
if [ "$(uname -m)" != x86_64 ]; then
  echo "expected x86_64, found $(uname -m)" >&2; exit 2
fi
FREE_G=$(df --output=avail -BG / | tail -1 | tr -dc '0-9')
if [ "${FREE_G:-0}" -lt 10 ]; then
  echo "disk: ${FREE_G}G free on / — need 10G" >&2; exit 2
fi
# Network check
if ! apt-get update -qq >/dev/null 2>&1; then
  echo "network: apt-get update failed" >&2; exit 2
fi

echo "== debauchery bootstrap =="
echo "Target user: $TARGET_USER"
echo "Log: $LOG_FILE"

export DEBAUCHERY_TARGET_USER="$TARGET_USER"
export DRY_RUN=0

# Root tier scripts
run_root() {
  local script=$1
  shift
  echo ""
  echo "▸ $script $*"
  if ! bash "$REPO/$script" "$@"; then
    echo "FAIL: $script" >&2
    exit 2
  fi
}

run_root scripts/13-base-system.sh --user "$TARGET_USER"
DM_ARGS=(--user "$TARGET_USER" --session hyprland)
if [ "$AUTOLOGIN" = 1 ]; then DM_ARGS+=(--autologin); fi
run_root scripts/14-display-manager.sh "${DM_ARGS[@]}"
run_root scripts/15-dms-shell.sh
run_root scripts/01-hyprland-install.sh
if [ "$WITH_ARCH" = 1 ]; then
  run_root scripts/03-arch-distrobox.sh
fi

# Handoff
if [ "$SKIP_HANDOFF" = 0 ]; then
  # Ensure repo is accessible by target user
  HANDOFF_REPO="$REPO"
  if [ "$(stat -c %U "$REPO")" != "$TARGET_USER" ]; then
    HANDOFF_REPO="$TARGET_HOME/debauchery"
    echo ""
    echo "▸ Copying repo to $HANDOFF_REPO for handoff..."
    if [ -d "$HANDOFF_REPO" ]; then
      cp -a "$REPO/." "$HANDOFF_REPO/"
    else
      cp -a "$REPO" "$HANDOFF_REPO"
    fi
    chown -R "$TARGET_USER:$TARGET_USER" "$HANDOFF_REPO"
  fi

  ONLY_LIST="backup,bridge,zsh,hyprcfg,binds,shims,session"
  if [ "$WITH_ARCH" = 1 ]; then
    ONLY_LIST="$ONLY_LIST,tools"
  fi

  echo ""
  echo "▸ Handoff: user-scope install.sh --only $ONLY_LIST"
  runuser -u "$TARGET_USER" -- env HOME="$TARGET_HOME" PATH="$TARGET_HOME/.local/bin:/usr/local/bin:/usr/bin:/bin" \
    bash "$HANDOFF_REPO/install.sh" install --only "$ONLY_LIST" --yes

  if [ "$OMARCHY_BINDS" = 1 ]; then
    echo ""
    echo "▸ Applying omarchy binds profile..."
    runuser -u "$TARGET_USER" -- bash "$HANDOFF_REPO/install.sh" binds omarchy
  fi

  # Gate: doctor
  echo ""
  echo "▸ Gate: install.sh doctor (as $TARGET_USER)"
  if runuser -u "$TARGET_USER" -- bash "$HANDOFF_REPO/install.sh" doctor; then
    echo "doctor: exit 0 (healthy)"
  else
    RC=$?
    case $RC in
      1) echo "doctor: exit 1 (warnings only)" ;;
      2) echo "doctor: exit 2 (failures)" ;;
      *) echo "doctor: exit $RC" ;;
    esac
  fi
  echo "Note: dms/binds-live checks need the first graphical login (reboot) to pass."
fi

# Firstboot checklist
echo ""
echo "=== Firstboot checklist ==="
echo "1. Reboot"
echo "2. ly session picker (or autologin into hyprland if --autologin)"
echo "3. SUPER+Space → menu opens"
echo "4. ~/debauchery/install.sh selftest"
echo "5. niri fallback session still listed in ly"

echo ""
echo "bootstrap: done"