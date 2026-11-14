#!/bin/bash
# 08 — Arch↔Debian usage bridge.
#
# Deploys the bridge layer that lets Omarchy's Arch-shaped commands work on a
# Debian base:
#
#   ~/.local/bin/omarchy-arch            container gateway (+ pacman/yay/paru
#                                        shims symlinked to it)
#   ~/.local/bin/omarchy-pkg             package verbs (+ omarchy-pkg-<verb>
#                                        symlinks: add, drop, present, missing,
#                                        install, remove, aur-add, aur-install)
#   ~/.config/omarchy-bridge/arch-debian.map
#                                        Arch name → Debian/container target
#
# User-scoped, no root, idempotent. A file it replaces is kept as
# <file>.pre-bridge. Teardown: ./08-arch-bridge.sh --uninstall
#
# Usage: ./08-arch-bridge.sh [--check|--uninstall]
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(dirname "$HERE")
BIN=$HOME/.local/bin
CONF=$HOME/.config/omarchy-bridge
MAP=$CONF/arch-debian.map
BOX=${OMARCHY_BOX:-arch-omarchy}

GATEWAY_ALIASES=(pacman yay paru)
PKG_VERBS=(add drop present missing install remove aur-add aur-install)

log() { printf '[bridge] %s\n' "$*"; }

deploy() { # <src> <dst> <mode>
  local src=$1 dst=$2 mode=${3:-644}
  mkdir -p "$(dirname "$dst")"
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    return 0
  fi
  if [ -e "$dst" ] && [ ! -L "$dst" ] && [ ! -e "$dst.pre-bridge" ]; then
    cp -a "$dst" "$dst.pre-bridge"
    log "backed up $dst -> $dst.pre-bridge"
  fi
  install -Dm"$mode" "$src" "$dst"
  log "deployed $dst"
}

link() { # <name> <target>
  local name=$1 target=$2
  # `local a=$1 b=$a` would expand b before a exists under `set -u`.
  local dst=$BIN/$name
  mkdir -p "$BIN"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$target" ]; then return 0; fi
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    cp -a "$dst" "$dst.pre-bridge"
    log "backed up $dst -> $dst.pre-bridge"
    rm -f "$dst"
  fi
  ln -sfn "$target" "$dst"
  log "linked $dst -> $target"
}

install_all() {
  deploy "$REPO/configs/bin/omarchy-arch" "$BIN/omarchy-arch" 755
  deploy "$REPO/configs/bin/omarchy-pkg"  "$BIN/omarchy-pkg"  755
  deploy "$REPO/configs/arch-debian.map"  "$MAP"              644

  local a
  for a in "${GATEWAY_ALIASES[@]}"; do link "$a" omarchy-arch; done
  for a in "${PKG_VERBS[@]}"; do link "omarchy-pkg-$a" omarchy-pkg; done
}

uninstall_all() {
  local a
  for a in "${GATEWAY_ALIASES[@]}" "${PKG_VERBS[@]/#/omarchy-pkg-}"; do
    [ -L "$BIN/$a" ] && { rm -f "$BIN/$a"; log "removed $BIN/$a"; }
  done
  rm -f "$BIN/omarchy-arch" "$BIN/omarchy-pkg"
  for f in "$BIN/omarchy-arch" "$BIN/omarchy-pkg" "$MAP"; do
    [ -e "$f.pre-bridge" ] && { mv -f "$f.pre-bridge" "$f"; log "restored $f"; }
  done
  log "uninstalled; the container and anything apt/pacman installed are untouched"
}

check() {
  local rc=0
  log "--- gateway ---"
  "$BIN/omarchy-arch" --status || rc=1

  log "--- container query through the pacman shim ---"
  if "$BIN/pacman" -Q bash; then log "pacman shim ok"; else log "pacman shim FAILED"; rc=1; fi

  log "--- package verbs ---"
  "$BIN/omarchy-pkg" present bash && log "present bash: ok" || { log "present bash: FAILED"; rc=1; }
  "$BIN/omarchy-pkg" missing bash bridge-does-not-exist && log "missing (one absent): ok" || { log "missing: FAILED"; rc=1; }
  if "$BIN/omarchy-pkg" present bash bridge-does-not-exist; then
    log "present with a missing package returned 0: FAILED"; rc=1
  else
    log "present with a missing package returns 1: ok"
  fi

  log "--- dry-run resolution (nothing installed) ---"
  OMARCHY_PKG_DRY_RUN=1 "$BIN/omarchy-pkg" add fd neovim impala || rc=1

  log "--- map ---"
  [ -r "$MAP" ] && log "$MAP: $(grep -cvE '^[[:space:]]*(#|$)' "$MAP") entries" || { log "map missing"; rc=1; }
  return $rc
}

case "${1:-install}" in
  --check|check)   check ;;
  --uninstall|uninstall) uninstall_all ;;
  install|"")      install_all; echo; check ;;
  *) echo "usage: $0 [install|--check|--uninstall]" >&2; exit 1 ;;
esac
