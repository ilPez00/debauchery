#!/bin/bash
# 18-arch-shell.sh — deploy the Debian host zsh config inside arch-omarchy.
#
# Usage: ./scripts/18-arch-shell.sh [--check|--dry-run|--uninstall]
#   --check     compare the deployed container .zshrc with the repo copy (read-only)
#   --dry-run   print the target path without changing anything
#   --uninstall restore the newest .zshrc.bak-* in the container home
#   (no flag)   back up the current file and deploy the repo copy
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
SRC="$REPO/configs/zsh/arch-host.zshrc"
BOX=${OMARCHY_BOX:-arch-omarchy}
ACTION=${1:-install}

usage() { sed -n '2,9p' "$0"; }

box_home() { podman exec "$BOX" sh -c 'printf %s "$HOME"'; }
remote_hash() { podman exec "$BOX" sha256sum "$1" 2>/dev/null | awk '{print $1}'; }
local_hash() { sha256sum "$SRC" | awk '{print $1}'; }

case "$ACTION" in
  --help|-h) usage; exit 0 ;;
esac

command -v podman >/dev/null 2>&1 || { echo "podman missing" >&2; exit 1; }
[ "$(podman inspect -f '{{.State.Running}}' "$BOX" 2>/dev/null)" = true ] || {
  echo "container $BOX is not running" >&2; exit 1;
}

HOME_IN_BOX=$(box_home)
DST="$HOME_IN_BOX/.zshrc"

case "$ACTION" in
  --dry-run)
    printf 'would copy %s -> %s:%s\n' "$SRC" "$BOX" "$DST"
    exit 0 ;;
  --check)
    if [ "$(local_hash)" = "$(remote_hash "$DST")" ]; then
      echo "arch shell config OK ($DST)"
    else
      echo "arch shell config DRIFT ($DST)" >&2; exit 1
    fi
    exit 0 ;;
  --uninstall)
    BAK=$(podman exec "$BOX" sh -c "ls -t $HOME_IN_BOX/.zshrc.bak-* 2>/dev/null | head -1")
    [ -n "$BAK" ] || { echo "no backup in $BOX" >&2; exit 1; }
    podman exec "$BOX" cp "$BAK" "$DST"
    echo "restored $BAK -> $DST"
    exit 0 ;;
  install)
    podman exec "$BOX" cp "$DST" "$DST.bak-$(date +%s)"
    podman cp "$SRC" "$BOX:$DST"
    "$0" --check
    exit 0 ;;
  *)
    usage >&2; exit 2 ;;
esac
