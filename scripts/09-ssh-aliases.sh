#!/bin/bash
# 09 — Fleet SSH aliases for zsh.
#
# Deploys configs/zsh/ssh-aliases.zsh to ~/.config/fleet/ssh-aliases.zsh and
# makes sure ~/.zshrc sources it. Hosts stay in ~/.ssh/config; this only adds
# aliases, so `ssh` itself keeps working exactly as before.
#
# Idempotent. A modified ~/.zshrc is backed up once as ~/.zshrc.pre-aliases.
# Teardown: ./09-ssh-aliases.sh --uninstall
#
# Usage: ./09-ssh-aliases.sh [--check|--uninstall]
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(dirname "$HERE")
SRC=$REPO/configs/zsh/ssh-aliases.zsh
DST=$HOME/.config/fleet/ssh-aliases.zsh
ZSHRC=$HOME/.zshrc
LINE='[ -f ~/.config/fleet/ssh-aliases.zsh ] && source ~/.config/fleet/ssh-aliases.zsh'

log() { printf '[ssh-aliases] %s\n' "$*"; }

deploy() {
  mkdir -p "$(dirname "$DST")"
  if [ -f "$DST" ] && cmp -s "$SRC" "$DST"; then
    log "$DST already current"
  else
    [ -f "$DST" ] && [ ! -f "$DST.pre-aliases" ] && { cp -a "$DST" "$DST.pre-aliases"; log "backed up $DST"; }
    install -Dm644 "$SRC" "$DST"
    log "deployed $DST"
  fi
}

wire_zshrc() {
  if grep -qF "$LINE" "$ZSHRC" 2>/dev/null; then
    log ".zshrc already sources the aliases"
    return 0
  fi
  [ -f "$ZSHRC" ] && [ ! -f "$ZSHRC.pre-aliases" ] && cp -a "$ZSHRC" "$ZSHRC.pre-aliases"
  {
    printf '\n# --- aliases: fleet SSH short hops (managed in ~/.config/fleet/ssh-aliases.zsh) ---\n'
    printf '%s\n' "$LINE"
  } >> "$ZSHRC"
  log "added the source line to $ZSHRC"
}

check() {
  local rc=0
  [ -f "$DST" ] || { log "missing $DST"; return 1; }
  zsh -n "$DST" 2>&1 || { log "syntax error in $DST"; rc=1; }
  zsh -n "$ZSHRC" 2>&1 || { log "syntax error in $ZSHRC"; rc=1; }
  grep -qF "$LINE" "$ZSHRC" || { log ".zshrc does not source the aliases"; rc=1; }
  log "aliases declared: $(grep -c '^alias ' "$DST")"

  log "--- host resolution (from ~/.ssh/config) ---"
  local h resolved user
  for h in omo pansa pi feather k1; do
    resolved=$(ssh -G "$h" 2>/dev/null | awk '/^hostname /{print $2}')
    user=$(ssh -G "$h" 2>/dev/null | awk '/^user /{print $2}')
    if [ -n "$resolved" ]; then
      printf '  %-8s -> %s (user %s)\n' "$h" "$resolved" "$user"
    else
      printf '  %-8s -> NOT IN ~/.ssh/config\n' "$h"; rc=1
    fi
  done
  return $rc
}

uninstall_all() {
  if grep -qF "$LINE" "$ZSHRC" 2>/dev/null; then
    grep -vF "$LINE" "$ZSHRC" | grep -vF 'fleet SSH short hops (managed in' > "$ZSHRC.tmp"
    mv -f "$ZSHRC.tmp" "$ZSHRC"
    log "removed the source line from $ZSHRC"
  fi
  if [ -f "$DST.pre-aliases" ]; then mv -f "$DST.pre-aliases" "$DST"; log "restored $DST"; else rm -f "$DST"; log "removed $DST"; fi
}

case "${1:-install}" in
  --check|check) check ;;
  --uninstall|uninstall) uninstall_all ;;
  install|"") deploy; wire_zshrc; echo; check ;;
  *) echo "usage: $0 [install|--check|--uninstall]" >&2; exit 1 ;;
esac
