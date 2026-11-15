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

# Extra standalone omarchy commands in configs/bin: dispatcher (omarchy),
# install/remove/tui/webapp helpers, and any omarchy-* command not owned by the
# omarchy-shim verb list (those are symlinks to omarchy-shim, managed below).
is_shim_verb() {
  local name=$1 v
  for v in $(verbs); do [ "$name" = "omarchy-$v" ] && return 0; done
  return 1
}

extras() {
  local f b
  for f in "$REPO"/configs/bin/omarchy "$REPO"/configs/bin/omarchy-*; do
    [ -e "$f" ] || continue
    b=$(basename "$f")
    [ "$b" = "omarchy-shim" ] && continue
    is_shim_verb "$b" && continue
    printf '%s\n' "$b"
  done | sort -u
}

deploy_extras() {
  local name src dst target
  for name in $(extras); do
    src=$REPO/configs/bin/$name
    dst=$BIN/$name
    [ -e "$src" ] || continue
    if [ -L "$src" ]; then
      target=$(readlink "$src")
      # keep relative symlink target valid from $BIN
      if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$target" ]; then continue; fi
      [ -e "$dst" ] && [ ! -L "$dst" ] && [ ! -f "$dst.pre-debauchery" ] && cp -a "$dst" "$dst.pre-debauchery"
      ln -sfn "$target" "$dst"
      log "linked $dst -> $target"
    else
      if [ -f "$dst" ] && cmp -s "$src" "$dst"; then continue; fi
      [ -f "$dst" ] && [ ! -f "$dst.pre-debauchery" ] && cp -a "$dst" "$dst.pre-debauchery"
      install -Dm755 "$src" "$dst" && log "deployed $dst"
    fi
  done
}

uninstall_extras() {
  local name dst
  for name in $(extras); do
    dst=$BIN/$name
    if [ -L "$dst" ] || [ -f "$dst" ]; then
      if [ -f "$dst.pre-debauchery" ]; then mv -f "$dst.pre-debauchery" "$dst"; log "restored $dst"
      else rm -f "$dst"; log "removed $dst"; fi
    fi
  done
}

check_extras() {
  local rc=0 name
  for name in omarchy omarchy-install omarchy-remove omarchy-tui-install omarchy-tui-remove omarchy-webapp-remove-all omarchy-version omarchy-update; do
    [ -x "$BIN/$name" ] || { log "FAILED missing $name"; rc=1; }
  done
  for name in omarchy-install-dev-env omarchy-remove-dev-env omarchy-plugin-add omarchy-theme-current; do
    [ -x "$BIN/$name" ] || { log "FAILED missing $name"; rc=1; }
  done
  [ $rc -eq 0 ] && log "extra omarchy commands deployed"
  return $rc
}

deploy() {
  mkdir -p "$BIN"
  if [ -f "$DST" ] && cmp -s "$SRC" "$DST"; then
    log "$DST already current"
  else
    [ -f "$DST" ] && [ ! -f "$DST.pre-debauchery" ] && cp -a "$DST" "$DST.pre-debauchery"
    install -Dm755 "$SRC" "$DST" && log "deployed $DST"
  fi

  local v dst
  deploy_extras

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
  uninstall_extras
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
  check_extras || rc=1
  return $rc
}

case "${1:-install}" in
  --check|check)          check ;;
  --uninstall|uninstall)  uninstall_all ;;
  install|"")             deploy; echo; check ;;
  *) echo "usage: $0 [install|--check|--uninstall]" >&2; exit 1 ;;
esac
