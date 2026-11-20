#!/bin/bash
# 13 — Base system: apt sources, base packages, fonts, subuids, zsh.
# Runs as root. Idempotent. --dry-run prints every mutation.
#
# Usage: sudo ./13-base-system.sh [--user NAME] [--dry-run]
# Env: DEBAUCHERY_TARGET_USER overrides --user.
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DRY_RUN=${DRY_RUN:-0}

# shellcheck source=scripts/lib-installer.sh
. "$REPO/scripts/lib-installer.sh"

TARGET_USER=${DEBAUCHERY_TARGET_USER:-}
AUTO_USER=0

usage() {
  cat <<EOF
Usage: $0 [--user NAME] [--dry-run]
  --user NAME    Target user (default: \$SUDO_USER, else first uid 1000-60000)
  --dry-run      Print mutations, change nothing (works unprivileged)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --user)   TARGET_USER=${2:-}; shift 2 ;;
    --user=*) TARGET_USER=${1#*=}; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) idie "unknown flag: $1" ;;
  esac
done

# Resolve target user
if [ -z "$TARGET_USER" ]; then
  if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then
    TARGET_USER=$SUDO_USER
  else
    TARGET_USER=$(awk -F: '$3 >= 1000 && $3 <= 60000 { print $1; exit }' /etc/passwd)
    AUTO_USER=1
  fi
fi

if [ -z "$TARGET_USER" ]; then
  idie "no target user found (create it in debian-installer or useradd)"
fi

if ! id "$TARGET_USER" >/dev/null 2>&1; then
  idie "user '$TARGET_USER' does not exist (create it in debian-installer or useradd)"
fi

TARGET_HOME=$(eval echo "~$TARGET_USER")

ilog "== 13-base-system: target user = $TARGET_USER =="
preflight_debian
require_root
require_disk "${DEBAUCHERY_BOOTSTRAP_MIN_DISK_G:-10}"

# 2. Base packages (one apt call, recommends wanted)
ilog "Installing base packages..."
run apt-get update
# Ensure resolv.conf exists for DNS in chroot
if [ ! -s /etc/resolv.conf ]; then
  echo "nameserver 10.0.2.3" > /etc/resolv.conf
  echo "nameserver 1.1.1.1" >> /etc/resolv.conf
fi
for _ in 1 2 3; do
  if run apt-get install -y \
    sudo zsh git curl ca-certificates gnupg whiptail network-manager pipewire \
    wireplumber bluez brightnessctl playerctl grim slurp wl-clipboard alacritty \
    chromium wf-recorder tesseract-ocr fonts-noto-color-emoji; then
    break
  fi
  ilog "apt install failed, retrying in 5s..."
  sleep 5
done

# 3. non-free-firmware component
if ! grep -rqs 'non-free-firmware' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
  ilog "Adding non-free-firmware component..."
  run bash -c 'echo "deb http://deb.debian.org/debian trixie non-free-firmware" > /etc/apt/sources.list.d/debian-nonfree.list'
  run apt-get update
else
  ilog "non-free-firmware already present"
fi

# 4. Backports
atomic_install "$REPO/configs/apt/trixie-backports.list" \
  "/etc/apt/sources.list.d/trixie-backports.list" 644

# 5. OBS repos
ensure_obs_repos

# 6. MesloLGS NF fonts system-wide
ilog "Installing MesloLGS NF fonts..."
FONT_DIR="/usr/local/share/fonts/meslolgs"
run mkdir -p "$FONT_DIR"
for style in Regular Bold Italic "Bold Italic"; do
  file="MesloLGS NF ${style}.ttf"
  url="https://github.com/romkatv/powerlevel10k-media/raw/master/${file// /%20}"
  dest="$FONT_DIR/$file"
  if [ -f "$dest" ]; then
    ilog "  = $file (already present)"
  else
    if run curl -fL --retry 3 -o "$dest" "$url"; then
      ilog "  + $file"
    else
      iwarn "  WARN  failed to download $file (fonts are cosmetic)"
    fi
  fi
done
if command -v fc-cache >/dev/null 2>&1; then
  run fc-cache -f
fi

# 7. Target user setup
ilog "Setting up target user $TARGET_USER..."
run mkdir -p "$TARGET_HOME/.local/bin"
run chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.local/bin"

if [ ! -f "$TARGET_HOME/.zshrc" ]; then
  ilog "Creating minimal .zshrc for $TARGET_USER..."
  run bash -c "cat > '$TARGET_HOME/.zshrc' <<'ZSHRC'
# ~/.zshrc — created by debauchery 13-base-system.sh
export PATH=\"\$HOME/.local/bin:\$PATH\"
ZSHRC"
  run chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.zshrc"
else
  ilog "  = .zshrc already exists"
fi

# 8. subuids/subgids
ilog "Configuring subuids/subgids for $TARGET_USER..."
if ! grep -q "^$TARGET_USER:" /etc/subuid 2>/dev/null; then
  # Find next free 65536 range starting from 100000.
  # Continue while the start is INSIDE an existing range: grep matches the
  # start field, or awk finds a covering range (awk exits 1 on overlap, so it
  # must be negated — exit 0 means "no overlap", i.e. stop).
  START=100000
  if [ -f /etc/subuid ]; then
    while grep -q ":$START:" /etc/subuid 2>/dev/null || \
          ! awk -F: -v s="$START" '$2 <= s && ($2+$3) > s { exit 1 }' /etc/subuid 2>/dev/null; do
      START=$((START + 65536))
      if [ "$START" -gt 6563600000 ]; then
        idie "no free 65536 subuid range found below 6563600000"
      fi
    done
  fi
  END=$((START + 65535))
  run usermod --add-subuids "${START}-${END}" --add-subgids "${START}-${END}" "$TARGET_USER"
  ilog "  + subuids/subgids: ${START}-${END}"
else
  ilog "  = subuids already present"
fi

# 9. chsh to zsh
if [ "$(getent passwd "$TARGET_USER" | cut -d: -f7)" != "/usr/bin/zsh" ]; then
  PREV_SHELL=$(getent passwd "$TARGET_USER" | cut -d: -f7)
  run chsh -s /usr/bin/zsh "$TARGET_USER"
  ilog "  chsh: $PREV_SHELL -> /usr/bin/zsh"
else
  ilog "  = shell already zsh"
fi

# 10. Container mode: nothing to skip here (chsh/usermod work)
if ! systemd_available; then
  ilog "Container mode: skipping systemctl (none in this script)"
fi

ilog "13-base-system: done"