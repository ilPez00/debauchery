#!/bin/bash
# 14 — Display manager: ly (source build, pinned), config, ly@tty1.
# Runs as root. Idempotent. --dry-run prints every mutation.
#
# Usage: sudo ./14-display-manager.sh [--user NAME] [--session SESSION] [--autologin] [--dry-run]
#   --user NAME      Target user (default: \$SUDO_USER, else first uid 1000-60000)
#   --session NAME   Wayland session to launch (default: hyprland)
#   --autologin      Enable autologin (opt-in: writes ly-autologin PAM + config)
#   --dry-run        Print mutations, change nothing (works unprivileged)
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DRY_RUN=${DRY_RUN:-0}

# shellcheck source=scripts/lib-installer.sh
. "$REPO/scripts/lib-installer.sh"

TARGET_USER=${DEBAUCHERY_TARGET_USER:-}
SESSION="hyprland"
AUTOLOGIN=0

usage() {
  cat <<EOF
Usage: $0 [--user NAME] [--session SESSION] [--autologin] [--dry-run]
  --user NAME      Target user (default: \$SUDO_USER, else first uid 1000-60000)
  --session NAME   Wayland session (default: hyprland)
  --autologin      Enable autologin (writes PAM + config, opt-in only)
  --dry-run        Print mutations, change nothing (works unprivileged)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --user)      TARGET_USER=${2:-}; shift 2 ;;
    --user=*)    TARGET_USER=${1#*=}; shift ;;
    --session)   SESSION=${2:-}; shift 2 ;;
    --session=*) SESSION=${1#*=}; shift ;;
    --autologin) AUTOLOGIN=1; shift ;;
    --dry-run)   DRY_RUN=1; shift ;;
    -h|--help)   usage; exit 0 ;;
    *) idie "unknown flag: $1" ;;
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
  idie "no target user found"
fi

if ! id "$TARGET_USER" >/dev/null 2>&1; then
  idie "user '$TARGET_USER' does not exist"
fi

ilog "== 14-display-manager: target user = $TARGET_USER, session = $SESSION, autologin = $AUTOLOGIN =="
preflight_debian
require_root

# 1. If ly present and config exists, skip build
if command -v ly >/dev/null 2>&1 && [ -f /etc/ly/config.lua ]; then
  ilog "ly present with config — skipping build"
  SKIP_BUILD=1
else
  SKIP_BUILD=0
fi

if [ "$SKIP_BUILD" = 0 ]; then
  # 2. Build dependencies
  ilog "Installing build dependencies..."
  run apt-get update
  run apt-get install -y build-essential libpam0g-dev libxcb-xkb-dev xauth brightnessctl git

  # 3. Zig 0.17.0
  ZIG=""
  for cand in "/opt/zig-x86_64-linux-0.17.0/zig" "/opt/zig/zig" "$(command -v zig 2>/dev/null || true)"; do
    if [ -x "$cand" ] && "$cand" version 2>/dev/null | grep -q "0.17.0"; then
      ZIG=$cand
      break
    fi
  done

  if [ -z "$ZIG" ]; then
    ilog "Zig 0.17.0 not found — downloading..."
    ZIG_TAR="zig-x86_64-linux-0.17.0.tar.xz"
    ZIG_URL="https://ziglang.org/download/0.17.0/$ZIG_TAR"
    ZIG_DIR="/opt/zig-x86_64-linux-0.17.0"
    run mkdir -p "$ZIG_DIR"
    run curl -fL --retry 3 -o "/tmp/$ZIG_TAR" "$ZIG_URL"
    # TODO: verify sha256 after first successful fetch (record in docs/INSTALLER.md)
    run tar -xf "/tmp/$ZIG_TAR" -C "$ZIG_DIR" --strip-components=1
    ZIG="$ZIG_DIR/zig"
    iwarn "  WARN  zig sha256 not yet pinned (first fetch); record in docs/INSTALLER.md after verification"
  fi
  ilog "Using zig: $ZIG ($("$ZIG" version))"

  # 4. Clone and build ly
  LY_SRC="/usr/local/src/ly"
  LY_COMMIT="747955ce3b654039c2aab9c2dbc089c26b07953c"
  if [ ! -d "$LY_SRC/.git" ]; then
    run git clone https://codeberg.org/fairyglade/ly "$LY_SRC"
  fi
  run git -C "$LY_SRC" fetch origin
  run git -C "$LY_SRC" checkout "$LY_COMMIT"

  ilog "Building ly..."
  run bash -c "cd '$LY_SRC' && '$ZIG' build"

  if [ -f /etc/ly/config.lua ]; then
    ilog "Existing /etc/ly/config.lua found — using installnoconf"
    run bash -c "cd '$LY_SRC' && '$ZIG' build installnoconf -Dinit_system=systemd"
  else
    ilog "No existing config — using installexe"
    run bash -c "cd '$LY_SRC' && '$ZIG' build installexe -Dinit_system=systemd"
  fi
  ilog "ly installed (upstream manages /etc/pam.d/ly and systemd units)"
fi

# 5. Config
if [ ! -f /etc/ly/config.lua ]; then
  ilog "Rendering ly config..."
  if [ "$DRY_RUN" = 1 ]; then
    ilog "  [dry-run] would render configs/ly/config.lua -> /etc/ly/config.lua (user=$TARGET_USER, session=$SESSION)"
  else
    sed -e "s/__USER__/$TARGET_USER/g" -e "s/__SESSION__/$SESSION/g" \
      "$REPO/configs/ly/config.lua" > /etc/ly/config.lua.new
    mv -f /etc/ly/config.lua.new /etc/ly/config.lua
    ilog "  + /etc/ly/config.lua (user=$TARGET_USER, session=$SESSION)"
  fi
else
  backup_once /etc/ly/config.lua
  ilog "  = /etc/ly/config.lua exists — left untouched"
fi

# 6. Autologin (opt-in only)
if [ "$AUTOLOGIN" = 1 ]; then
  ilog "Enabling autologin (opt-in)..."
  backup_once /etc/ly/config.lua
  # Update config with autologin settings
  if [ "$DRY_RUN" = 1 ]; then
    ilog "  [dry-run] would set auto_login_user=$TARGET_USER auto_login_session=$SESSION in /etc/ly/config.lua"
  else
    sed -i -e "s/auto_login_user = nil/auto_login_user = \"$TARGET_USER\"/" \
           -e "s/auto_login_session = nil/auto_login_session = \"$SESSION\"/" \
      /etc/ly/config.lua
  fi
  atomic_install "$REPO/configs/ly/pam-autologin" "/etc/pam.d/ly-autologin" 644
else
  ilog "Autologin not requested (--autologin flag required)"
fi

# 7. Systemd wiring
if systemd_available; then
  run systemctl enable ly@tty1.service
  run systemctl disable getty@tty1.service
  for dm in gdm3 lightdm sddm; do
    if systemctl is-enabled "$dm" >/dev/null 2>&1; then
      run systemctl disable "$dm"
      iwarn "  WARN  disabled $dm (only one display manager)"
    fi
  done
else
  ilog "Container mode: skipping systemctl enable/disable"
fi

# 8. Verify
ilog "Verification:"
if command -v ly >/dev/null 2>&1; then
  ilog "  ly binary: $(command -v ly)"
else
  iwarn "  WARN  ly binary not found"
fi
if [ -f /etc/ly/config.lua ] && command -v luac >/dev/null 2>&1; then
  if luac -p /etc/ly/config.lua >/dev/null 2>&1; then
    ilog "  config.lua: parses OK"
  else
    iwarn "  WARN  config.lua has syntax errors"
  fi
elif [ -f /etc/ly/config.lua ] && command -v lua >/dev/null 2>&1; then
  if lua -e "dofile('/etc/ly/config.lua')" >/dev/null 2>&1; then
    ilog "  config.lua: parses OK"
  else
    iwarn "  WARN  config.lua has syntax errors"
  fi
else
  ilog "  config.lua: present (no lua/luac to validate)"
fi
if systemd_available; then
  systemctl is-active ly@tty1.service >/dev/null 2>&1 && ilog "  ly@tty1: active" || ilog "  ly@tty1: inactive"
  systemctl is-enabled ly@tty1.service >/dev/null 2>&1 && ilog "  ly@tty1: enabled" || ilog "  ly@tty1: not enabled"
  systemctl is-active getty@tty1.service >/dev/null 2>&1 && iwarn "  WARN  getty@tty1 still active" || ilog "  getty@tty1: inactive"
fi

ilog "14-display-manager: done"