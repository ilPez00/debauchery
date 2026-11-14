#!/bin/bash
# 10 — Install the AUR-mapped Omarchy tools.
#
# Source of truth: configs/arch-debian.map — every `aur:<pkg>` and `arch:<pkg>`
# line. These are the Omarchy tools that only exist for Arch (PLAN.md §4.3
# "Arch-bound"), so they live in the arch-omarchy container, never on the
# Debian host.
#
# For each tool:
#   1. skip if already present in the container
#   2. otherwise install through the bridge (`omarchy-pkg add`), which picks
#      pacman or paru from the map
#   3. export the binary to ~/.local/bin with distrobox-export, so it is callable
#      from the DMS/Hyprland session without `distrobox enter`
#
# Idempotent, user-scoped. AUR builds run on this machine's two cores, so expect
# minutes per source-built package; disk is checked before starting.
#
# Usage: ./10-omarchy-tools.sh [--dry-run|--check|--export-only]
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(dirname "$HERE")
MAP_SRC=$REPO/configs/arch-debian.map
MAP=${OMARCHY_PKG_MAP:-$HOME/.config/omarchy-bridge/arch-debian.map}
BOX=${OMARCHY_BOX:-arch-omarchy}
BIN_DIR=$HOME/.local/bin
DRY=0

log()  { printf '[tools] %s\n' "$*"; }
warn() { printf '[tools] %s\n' "$*" >&2; }

read_map() { [ -r "$MAP" ] && cat "$MAP" || cat "$MAP_SRC"; }
container_tools() {
  read_map | awk '!/^[[:space:]]*#/ && NF >= 2 && $2 ~ /^(aur|arch):/ { sub(/^(aur|arch):/, "", $2); print $2 }'
}

gateway() { "$BIN_DIR/omarchy-arch" "$@"; }
pkg()     { "$BIN_DIR/omarchy-pkg" "$@"; }

container_bin() { gateway bash -lc "command -v $1" 2>/dev/null | tr -d '\r'; }

disk_ok() {
  local free
  free=$(df --output=avail -BG / | tail -1 | tr -dc '0-9')
  [ "${free:-0}" -ge 4 ] && return 0
  warn "only ${free}G free on / — need ~4G for AUR builds; freeing nothing, aborting"
  return 1
}

install_tools() {
  local tools t rc=0
  tools=$(container_tools)
  [ -n "$tools" ] || { warn "no aur:/arch: entries in the map"; return 1; }

  log "container tools from the map: $(echo $tools)"
  disk_ok || return 1

  for t in $tools; do
    if pkg present "$t"; then
      log "$t: already installed, skipping"
      continue
    fi
    if [ "$DRY" = "1" ]; then
      log "$t: dry-run — would install with paru"
      continue
    fi
    log "$t: installing (container $BOX) — this can take a while"
    if pkg add "$t"; then
      log "$t: installed"
    else
      warn "$t: FAILED to install (not in the AUR, build error, or network)"
      rc=1
    fi
  done
  return $rc
}

export_tools() {
  local tools t path rc=0
  tools=$(container_tools)
  for t in $tools; do
    if ! pkg present "$t"; then
      continue
    fi
    path=$(container_bin "$t")
    if [ -z "$path" ]; then
      warn "$t: installed but no binary on the container PATH — not exportable"
      rc=1
      continue
    fi
    if [ "$DRY" = "1" ]; then
      log "$t: dry-run — would export $path to $BIN_DIR"
      continue
    fi
    if [ -x "$BIN_DIR/$t" ]; then
      log "$t: already on the host PATH"
      continue
    fi
    if distrobox enter "$BOX" --no-tty -- distrobox-export --bin "$path" --export-path "$BIN_DIR" >/dev/null 2>&1; then
      log "$t: exported $path -> $BIN_DIR/$t"
    else
      warn "$t: distrobox-export failed"
      rc=1
    fi
  done
  return $rc
}

check() {
  local tools t rc=0
  tools=$(container_tools)
  log "--- container presence ---"
  for t in $tools; do
    if pkg present "$t"; then
      printf '  %-14s container: yes' "$t"
      [ -x "$BIN_DIR/$t" ] && printf '  host: %s\n' "$BIN_DIR/$t" || printf '  host: not exported\n'
    else
      printf '  %-14s container: no\n' "$t"
      rc=1
    fi
  done
  log "--- bridge still healthy ---"
  gateway --status | sed 's/^/  /'
  return $rc
}

case "${1:-install}" in
  --dry-run|dry-run) DRY=1; install_tools; export_tools ;;
  --check|check)     check ;;
  --export-only)     export_tools ;;
  install|"")        install_tools; echo; export_tools; echo; check ;;
  *) echo "usage: $0 [install|--dry-run|--check|--export-only]" >&2; exit 1 ;;
esac
