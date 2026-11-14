#!/bin/bash
# 11 — Omarchy compatibility verbs (Tier 1), backed by DMS/Hyprland/Debian.
#
# Deploys configs/bin/omarchy-shim -> ~/.local/bin/omarchy-shim, then one
# symlink per verb (omarchy-menu, omarchy-capture-screenshot, …) so Omarchy's
# command names work on air. The verb list lives in the shim itself; this
# script reads it back with `--list`.
#
# Idempotent, user-scoped, no root. Undo: ./11-omarchy-shims.sh --uninstall
#
# Usage: ./11-omarchy-shims.sh [--check|--uninstall]
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(dirname "$HERE")
SRC=$REPO/configs/bin/omarchy-shim
BIN=$HOME/.local/bin
DST=$BIN/omarchy-shim

log() { printf '[shims] %s\n' "$*"; }

verbs() { "$SRC" --list; }

deploy() {
  mkdir -p "$BIN"
  if [ -f "$DST" ] && cmp -s "$SRC" "$DST"; then
    log "$DST already current"
  else
    [ -f "$DST" ] && [ ! -f "$DST.pre-debauchery" ] && cp -a "$DST" "$DST.pre-debauchery"
    install -Dm755 "$SRC" "$DST" && log "deployed $DST"
  fi

  local v dst
  for v in $(verbs); do
    dst=$BIN/omarchy-$v
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = omarchy-shim ]; then
      continue
    fi
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
      cp -a "$dst" "$dst.pre-debauchery"
      log "backed up $dst"
    fi
    ln -sfn omarchy-shim "$dst"
    log "linked $dst -> omarchy-shim"
  done
}

uninstall_all() {
  local v
  for v in $(verbs); do
    [ -L "$BIN/omarchy-$v" ] && { rm -f "$BIN/omarchy-$v"; log "removed $BIN/omarchy-$v"; }
  done
  if [ -f "$DST.pre-debauchery" ]; then mv -f "$DST.pre-debauchery" "$DST"; log "restored $DST"
  else rm -f "$DST"; log "removed $DST"; fi
}

check() {
  local rc=0 v missing=""
  for v in $(verbs); do
    [ -x "$BIN/omarchy-$v" ] || missing="$missing omarchy-$v"
  done
  if [ -n "$missing" ]; then
    log "FAILED missing verbs:$missing"
    rc=1
  else
    log "$(verbs | wc -l) verbs installed"
  fi
  "$BIN/omarchy-shim" --check || rc=1
  return $rc
}

case "${1:-install}" in
  --check|check)          check ;;
  --uninstall|uninstall)  uninstall_all ;;
  install|"")             deploy; echo; check ;;
  *) echo "usage: $0 [install|--check|--uninstall]" >&2; exit 1 ;;
esac
