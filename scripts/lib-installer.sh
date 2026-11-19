#!/bin/bash
# lib-installer.sh — shared helpers for the system installer tier (scripts 13-16, bootstrap).
# Sourced, not executed. All functions are idempotent and respect DRY_RUN.
set -euo pipefail

# Logging helpers (mirrors install.sh style)
ilog()  { printf '%s\n' "$*"; }
iwarn() { printf '%s\n' "$*" >&2; }
idie()  { printf '%s\n' "$*" >&2; exit 2; }

# Require root unless DRY_RUN=1
require_root() {
  if [ "${DRY_RUN:-0}" = 1 ]; then return 0; fi
  if [ "$(id -u)" -ne 0 ]; then idie "must run as root (or use DRY_RUN=1)"; fi
}

# Preflight: Debian 13 x86_64
preflight_debian() {
  . /etc/os-release 2>/dev/null || true
  if [ "${ID:-}" != debian ] || [ "${VERSION_ID:-}" != 13 ]; then
    idie "expected Debian 13, found ${PRETTY_NAME:-unknown}"
  fi
  if [ "$(uname -m)" != x86_64 ]; then
    idie "expected x86_64, found $(uname -m)"
  fi
}

# Disk free in GiB (integer)
disk_free_g() {
  df --output=avail -BG / | tail -1 | tr -dc '0-9'
}

# Require at least G GiB free
require_disk() {
  local need=$1 have
  have=$(disk_free_g)
  if [ "${have:-0}" -lt "$need" ]; then
    idie "disk: ${have}G free on / — need ${need}G"
  fi
}

# Backup a file once to .pre-debauchery
backup_once() {
  local file=$1
  if [ "${DRY_RUN:-0}" = 1 ]; then return 0; fi
  if [ -e "$file" ] && [ ! -f "$file.pre-debauchery" ]; then
    cp -a "$file" "$file.pre-debauchery"
    ilog "  backed up $file"
  fi
}

# Atomic install: skip-if-identical, backup_once + install to .new + mv
atomic_install() {
  local src=$1 dst=$2 mode=${3:-644}
  if [ "${DRY_RUN:-0}" = 1 ]; then
    ilog "  [dry-run] would install $src -> $dst (mode $mode)"
    return 0
  fi
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    ilog "  = $dst"
    return 0
  fi
  backup_once "$dst"
  mkdir -p "$(dirname "$dst")"
  install -m"$mode" "$src" "$dst.new" && mv -f "$dst.new" "$dst"
  ilog "  + $dst"
}

# Ensure OBS repos (danklinux + dms) are present with vendored keys
ensure_obs_repos() {
  local repo_root
  repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

  # Keyrings
  atomic_install "$repo_root/configs/apt/home-AvengeMedia-danklinux.gpg" \
    "/etc/apt/keyrings/home-AvengeMedia-danklinux.gpg" 644
  atomic_install "$repo_root/configs/apt/home-AvengeMedia-dms.gpg" \
    "/etc/apt/keyrings/home-AvengeMedia-dms.gpg" 644

  # Sources lists
  atomic_install "$repo_root/configs/apt/danklinux.list" \
    "/etc/apt/sources.list.d/home-AvengeMedia-danklinux.list" 644
  atomic_install "$repo_root/configs/apt/dms.list" \
    "/etc/apt/sources.list.d/home-AvengeMedia-dms.list" 644

  if [ "${DRY_RUN:-0}" = 1 ]; then
    ilog "  [dry-run] would run: apt-get update"
    return 0
  fi
  apt-get update
}

# systemd available? (container mode detection)
systemd_available() {
  [ -d /run/systemd/system ]
}

# run() wrapper exactly like install.sh's single gate
run() {
  if [ "${DRY_RUN:-0}" = 1 ]; then
    ilog "[dry-run] $*"
    return 0
  fi
  ilog "  \$ $*"
  "$@"
}

export -f ilog iwarn idie require_root preflight_debian disk_free_g require_disk
export -f backup_once atomic_install ensure_obs_repos systemd_available run