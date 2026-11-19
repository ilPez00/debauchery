#!/bin/bash
# test-install-container.sh — G3 gate: prove the root installer tier in a
# disposable Debian 13 container, without touching the host.
#
# Runs scripts 13 → 14 → 15 → 01 as root inside docker.io/library/debian:trixie
# (podman rootless). Container mode is auto-detected by the scripts
# (/run/systemd/system absent → no systemctl calls). The host repo is mounted
# READ-ONLY; the host zig 0.17.0 toolchain is mounted read-only when present so
# the ly build skips the download.
#
# Usage: ./scripts/test-install-container.sh [--quick] [--keep]
#   --quick  skip 01 (Hyprland/rust/podman packages) — iterate on 13/14/15 only
#   --keep   leave the container behind for debugging (no --rm)
#
# Exit: 0 all assertions pass, 2 failure. Log: ~/.local/state/debauchery/container-gate-<ts>.log
set -uo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/debauchery
LOG=$STATE/container-gate-$(date +%Y%m%d-%H%M%S).log
mkdir -p "$STATE"

QUICK=0 KEEP=0
for a in "$@"; do
  case "$a" in
    --quick) QUICK=1 ;;
    --keep)  KEEP=1 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "unknown flag: $a" >&2; exit 2 ;;
  esac
done

command -v podman >/dev/null 2>&1 || { echo "FAIL podman missing" >&2; exit 2; }
podman image exists docker.io/library/debian:trixie || {
  echo "== pulling debian:trixie =="
  podman pull docker.io/library/debian:trixie || exit 2
}

NAME=debauchery-gate-$$
MOUNTS=(-v "$REPO:/repo:ro")
ZIGDIR=/opt/zig-x86_64-linux-0.17.0
[ -x "$ZIGDIR/zig" ] && MOUNTS+=(-v "$ZIGDIR:$ZIGDIR:ro")
RM=(--rm); [ "$KEEP" = 1 ] && RM=()

INNER='
set -e
export DEBIAN_FRONTEND=noninteractive
echo "== G3: 13-base-system =="
bash /repo/scripts/13-base-system.sh --user root
echo "== G3: 14-display-manager =="
bash /repo/scripts/14-display-manager.sh --user root
echo "== G3: 15-dms-shell =="
bash /repo/scripts/15-dms-shell.sh
'
[ "$QUICK" = 0 ] && INNER+='
echo "== G3: 01-hyprland-install =="
bash /repo/scripts/01-hyprland-install.sh
'
INNER+='
echo "== G3: assertions =="
fail=0
chk() { if eval "$1"; then echo "  ok    $2"; else echo "  FAIL  $2"; fail=1; fi; }
chk "test -x /usr/bin/ly"                          "ly binary built+installed"
chk "test -f /etc/ly/config.lua"                   "ly config present"
chk "grep -rqs trixie-backports /etc/apt/sources.list.d/" "backports source"
chk "grep -rqs AvengeMedia /etc/apt/sources.list.d/"      "OBS sources"
chk "dpkg -l dms 2>/dev/null | grep -q \"^ii\""        "dms installed"
chk "dpkg -l quickshell 2>/dev/null | grep -q \"^ii\"" "quickshell installed"
chk "command -v zsh"                               "zsh installed"
chk "test -f /root/.zshrc"                         "root .zshrc created"
chk "grep -q root /etc/subuid"                     "subuids allocated"
if [ -d /usr/local/share/fonts/meslolgs ]; then echo "  ok    meslolgs fonts installed"; else echo "  warn  meslolgs fonts absent (cosmetic, download may have failed)"; fi
'
[ "$QUICK" = 0 ] && INNER+='
chk "command -v Hyprland"                          "Hyprland installed"
chk "command -v cargo"                             "rust installed"
chk "command -v distrobox && command -v podman"    "distrobox+podman installed"
'
INNER+='
[ "$fail" = 0 ] && echo "G3 PASS" || { echo "G3 FAIL"; exit 2; }
'

echo "== G3 container gate: $NAME (quick=$QUICK keep=$KEEP) =="
echo "log: $LOG"
podman run "${RM[@]}" --name "$NAME" "${MOUNTS[@]}" \
  docker.io/library/debian:trixie bash -c "$INNER" 2>&1 | tee "$LOG"
rc=${PIPESTATUS[0]}
if [ "$rc" = 0 ]; then echo "G3 PASS — root tier proven in container (host untouched)"; else echo "G3 FAIL (rc=$rc) — see $LOG"; fi
exit "$rc"
